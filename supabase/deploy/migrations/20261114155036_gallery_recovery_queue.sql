-- TIFFANI gallery recovery queue.
-- Schema and service-role functions only. This file does not insert
-- images, does not update products or variants, and does not install cron.
--
-- State machine (gallery_recovery_items.status):
--   pending           discovered or due for recheck, not yet classified
--   no_extra          page has only the known primary; recheck after next_check_at
--   ready_for_review  one edition, primary excluded, extras validated; waits for admin live
--   ambiguous         edition/variant mismatch or ownership failure; not auto-live
--   access_denied     HTTP 403; backoff via next_check_at, never a tight retry
--   error             extract, validation, dedup, or partial insert failure
--   completed         reconciled to actual tilda_gallery rows, not to status alone
--
-- no_extra and ambiguous are deferrals, not a permanent blacklist.
-- Live is not a status transition this migration can perform.

BEGIN;

CREATE TABLE public.gallery_recovery_items (
  product_id uuid PRIMARY KEY REFERENCES public.products (id),
  tilda_uid text NOT NULL,
  status text NOT NULL,
  db_variant_count integer NOT NULL DEFAULT 0,
  website_edition_count integer,
  website_image_count integer,
  existing_primary_count integer NOT NULL DEFAULT 0,
  confirmed_supplementary_count integer NOT NULL DEFAULT 0,
  expected_new_image_count integer NOT NULL DEFAULT 0,
  importable_urls text[] NOT NULL DEFAULT '{}',
  content_fingerprint text,
  last_checked_at timestamptz,
  next_check_at timestamptz,
  last_success_at timestamptz,
  error_classification text,
  retry_count integer NOT NULL DEFAULT 0,
  last_error text,
  claimed_at timestamptz,
  claim_token text,
  created_at timestamptz NOT NULL DEFAULT now(),
  updated_at timestamptz NOT NULL DEFAULT now(),
  CONSTRAINT gallery_recovery_items_uid_unique UNIQUE (tilda_uid),
  CONSTRAINT gallery_recovery_items_uid_numeric CHECK (tilda_uid ~ '^[0-9]{6,20}$'),
  CONSTRAINT gallery_recovery_items_status_check CHECK (
    status IN (
      'pending',
      'no_extra',
      'ready_for_review',
      'ambiguous',
      'access_denied',
      'error',
      'completed'
    )
  ),
  CONSTRAINT gallery_recovery_items_retry_nonnegative CHECK (retry_count >= 0),
  CONSTRAINT gallery_recovery_items_expected_nonnegative CHECK (expected_new_image_count >= 0)
);

CREATE TABLE public.gallery_recovery_runs (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  mode text NOT NULL,
  selected_uids text[] NOT NULL DEFAULT '{}',
  status text NOT NULL,
  result jsonb NOT NULL DEFAULT '{}'::jsonb,
  error_count integer NOT NULL DEFAULT 0,
  writes integer NOT NULL DEFAULT 0,
  started_at timestamptz NOT NULL DEFAULT now(),
  finished_at timestamptz,
  CONSTRAINT gallery_recovery_runs_mode_check CHECK (
    mode IN ('bootstrap', 'prepare', 'inspect', 'propose', 'recheck', 'live')
  ),
  CONSTRAINT gallery_recovery_runs_status_check CHECK (
    status IN ('running', 'completed', 'aborted', 'failed', 'abandoned')
  ),
  CONSTRAINT gallery_recovery_runs_writes_nonnegative CHECK (writes >= 0),
  CONSTRAINT gallery_recovery_runs_errors_nonnegative CHECK (error_count >= 0)
);

CREATE INDEX gallery_recovery_items_status_idx
  ON public.gallery_recovery_items (status, next_check_at);

CREATE INDEX gallery_recovery_items_uid_num_idx
  ON public.gallery_recovery_items ((tilda_uid::numeric), tilda_uid);

COMMENT ON TABLE public.gallery_recovery_items IS
  'Resumable gallery inspection queue. Writes here are not catalog writes. no_extra is rechecked after next_check_at.';

COMMENT ON TABLE public.gallery_recovery_runs IS
  'One row per operator batch. writes counts inserted tilda_gallery images, not queue bookkeeping. running is written before inspect work; abandoned is a dead running row, not a schedule.';

ALTER TABLE public.gallery_recovery_items ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.gallery_recovery_runs ENABLE ROW LEVEL SECURITY;

CREATE POLICY gallery_recovery_items_admin_select
  ON public.gallery_recovery_items
  FOR SELECT TO authenticated
  USING (public.is_admin());

CREATE POLICY gallery_recovery_runs_admin_select
  ON public.gallery_recovery_runs
  FOR SELECT TO authenticated
  USING (public.is_admin());

REVOKE ALL ON TABLE public.gallery_recovery_items FROM PUBLIC, anon, authenticated;
REVOKE ALL ON TABLE public.gallery_recovery_runs FROM PUBLIC, anon, authenticated;
GRANT SELECT ON TABLE public.gallery_recovery_items TO authenticated;
GRANT SELECT ON TABLE public.gallery_recovery_runs TO authenticated;
GRANT ALL ON TABLE public.gallery_recovery_items TO service_role;
GRANT ALL ON TABLE public.gallery_recovery_runs TO service_role;

-- Read-only snapshot of Tilda products. Eligibility is decided in the queue
-- function from these counts. Hidden products stay in the snapshot.
CREATE FUNCTION public.gallery_recovery_catalog_snapshot()
RETURNS TABLE (
  product_id uuid,
  tilda_uid text,
  variant_count integer,
  yml_count integer,
  gallery_count integer,
  gallery_urls text[],
  primary_url text,
  primary_matches boolean,
  hidden boolean
)
LANGUAGE sql
STABLE
SECURITY INVOKER
SET search_path = pg_catalog, public
AS $$
  SELECT
    p.id,
    p.tilda_uid,
    (SELECT count(*)::integer FROM public.product_variants v WHERE v.product_id = p.id),
    (SELECT count(*)::integer FROM public.product_images i WHERE i.product_id = p.id AND i.source = 'yml_variant'),
    (SELECT count(*)::integer FROM public.product_images i WHERE i.product_id = p.id AND i.source = 'tilda_gallery'),
    COALESCE((
      SELECT array_agg(i.url ORDER BY i.position)
      FROM public.product_images i
      WHERE i.product_id = p.id AND i.source = 'tilda_gallery'
    ), '{}'::text[]),
    (
      SELECT i.url
      FROM public.product_images i
      WHERE i.product_id = p.id AND i.source = 'yml_variant'
      ORDER BY i.position
      LIMIT 1
    ),
    EXISTS (
      SELECT 1
      FROM public.product_variants v
      JOIN public.product_images i
        ON i.product_id = p.id
       AND i.source = 'yml_variant'
       AND i.url = v.photo
      WHERE v.product_id = p.id
        AND p.photo IS NOT DISTINCT FROM v.photo
    ),
    NOT p.app_is_visible
  FROM public.products p
  WHERE p.tilda_uid IS NOT NULL;
$$;

-- Promote due deferrals, then lock the next numeric UID batch.
-- SKIP LOCKED lets two operators claim different products.
-- A claim older than 15 minutes is stale and can be taken again.
CREATE FUNCTION public.gallery_recovery_claim_batch(p_limit integer, p_token text)
RETURNS SETOF public.gallery_recovery_items
LANGUAGE plpgsql
SECURITY INVOKER
SET search_path = pg_catalog, public
AS $$
DECLARE
  v_limit integer := LEAST(GREATEST(COALESCE(p_limit, 0), 0), 20);
BEGIN
  IF v_limit = 0 OR p_token IS NULL OR length(p_token) < 8 THEN
    RETURN;
  END IF;

  UPDATE public.gallery_recovery_items
  SET status = 'pending',
      claimed_at = NULL,
      claim_token = NULL,
      updated_at = now()
  WHERE status IN ('no_extra', 'ambiguous', 'access_denied', 'error')
    AND next_check_at IS NOT NULL
    AND next_check_at <= now();

  RETURN QUERY
  WITH picked AS (
    SELECT q.product_id
    FROM public.gallery_recovery_items q
    WHERE q.status = 'pending'
      AND (q.next_check_at IS NULL OR q.next_check_at <= now())
      AND (q.claimed_at IS NULL OR q.claimed_at < now() - interval '15 minutes')
    ORDER BY q.tilda_uid::numeric, q.tilda_uid
    LIMIT v_limit
    FOR UPDATE SKIP LOCKED
  ),
  updated AS (
    UPDATE public.gallery_recovery_items q
    SET claimed_at = now(),
        claim_token = p_token,
        updated_at = now()
    FROM picked
    WHERE q.product_id = picked.product_id
    RETURNING q.*
  )
  SELECT updated.*
  FROM updated
  ORDER BY updated.tilda_uid::numeric, updated.tilda_uid;
END;
$$;

-- All-or-nothing lock for one approved live allowlist.
-- A row held by another fresh claim is skipped, and then nothing is claimed.
CREATE FUNCTION public.gallery_recovery_claim_live(p_uids text[], p_token text)
RETURNS SETOF public.gallery_recovery_items
LANGUAGE plpgsql
SECURITY INVOKER
SET search_path = pg_catalog, public
AS $$
DECLARE
  v_count integer := COALESCE(cardinality(p_uids), 0);
BEGIN
  IF v_count = 0 OR v_count > 20 OR p_token IS NULL OR length(p_token) < 8 THEN
    RETURN;
  END IF;
  IF (SELECT count(DISTINCT uid) FROM unnest(p_uids) AS uid) <> v_count THEN
    RETURN;
  END IF;

  RETURN QUERY
  WITH locked AS (
    SELECT q.product_id
    FROM public.gallery_recovery_items q
    WHERE q.tilda_uid = ANY (p_uids)
      AND q.status = 'ready_for_review'
      AND (q.claimed_at IS NULL OR q.claimed_at < now() - interval '15 minutes')
    FOR UPDATE SKIP LOCKED
  )
  UPDATE public.gallery_recovery_items q
  SET claimed_at = now(),
      claim_token = p_token,
      updated_at = now()
  FROM locked
  WHERE q.product_id = locked.product_id
    AND (SELECT count(*) FROM locked) = v_count
  RETURNING q.*;
END;
$$;

-- Explicit recheck. Does not take a row another worker still holds.
CREATE FUNCTION public.gallery_recovery_claim_recheck(p_uid text, p_token text)
RETURNS SETOF public.gallery_recovery_items
LANGUAGE plpgsql
SECURITY INVOKER
SET search_path = pg_catalog, public
AS $$
BEGIN
  IF p_uid IS NULL OR p_token IS NULL OR length(p_token) < 8 THEN
    RETURN;
  END IF;

  RETURN QUERY
  UPDATE public.gallery_recovery_items q
  SET status = 'pending',
      next_check_at = NULL,
      claimed_at = now(),
      claim_token = p_token,
      updated_at = now()
  WHERE q.tilda_uid = p_uid
    AND (q.claimed_at IS NULL OR q.claimed_at < now() - interval '15 minutes')
  RETURNING q.*;
END;
$$;

REVOKE ALL ON FUNCTION public.gallery_recovery_catalog_snapshot() FROM PUBLIC, anon, authenticated;
REVOKE ALL ON FUNCTION public.gallery_recovery_claim_batch(integer, text) FROM PUBLIC, anon, authenticated;
REVOKE ALL ON FUNCTION public.gallery_recovery_claim_live(text[], text) FROM PUBLIC, anon, authenticated;
REVOKE ALL ON FUNCTION public.gallery_recovery_claim_recheck(text, text) FROM PUBLIC, anon, authenticated;
GRANT EXECUTE ON FUNCTION public.gallery_recovery_catalog_snapshot() TO service_role;
GRANT EXECUTE ON FUNCTION public.gallery_recovery_claim_batch(integer, text) TO service_role;
GRANT EXECUTE ON FUNCTION public.gallery_recovery_claim_live(text[], text) TO service_role;
GRANT EXECUTE ON FUNCTION public.gallery_recovery_claim_recheck(text, text) TO service_role;

COMMENT ON FUNCTION public.gallery_recovery_claim_batch(integer, text) IS
  'Claims at most 20 pending gallery queue rows. Does not insert product_images and does not schedule cron.';

COMMIT;
