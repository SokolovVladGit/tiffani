-- TIFFANI order notification outbox.
-- Applied manually. Do not backfill existing orders.
--
-- submit_order_v3 inserts order_requests, then order_request_items, in one
-- transaction. This AFTER INSERT trigger writes the job in that same
-- transaction. A worker on another connection cannot see the job until
-- commit, so the line items are already stored when the job becomes visible.
--
-- The queue lives outside the API schema. Claim and completion functions
-- are executable only by service_role.

CREATE SCHEMA IF NOT EXISTS private;

REVOKE ALL ON SCHEMA private FROM PUBLIC, anon, authenticated;
GRANT USAGE ON SCHEMA private TO service_role;

CREATE TABLE private.order_notification_jobs (
  id                    uuid        PRIMARY KEY DEFAULT gen_random_uuid(),
  order_id              uuid        NOT NULL UNIQUE
                                    REFERENCES public.order_requests (id) ON DELETE CASCADE,
  status                text        NOT NULL DEFAULT 'pending',
  attempts              integer     NOT NULL DEFAULT 0,
  max_attempts          integer     NOT NULL DEFAULT 5,
  last_error            text        NULL,
  telegram_message_id   bigint      NULL,
  next_attempt_at       timestamptz NOT NULL DEFAULT now(),
  locked_until          timestamptz NULL,
  created_at            timestamptz NOT NULL DEFAULT now(),
  updated_at            timestamptz NOT NULL DEFAULT now(),
  sent_at               timestamptz NULL,
  CONSTRAINT chk_order_notification_status CHECK (
    status IN ('pending', 'processing', 'sent', 'dead')
  ),
  CONSTRAINT chk_order_notification_attempts CHECK (
    attempts >= 0 AND attempts <= max_attempts
  ),
  CONSTRAINT chk_order_notification_max_attempts CHECK (
    max_attempts BETWEEN 1 AND 10
  )
);

COMMENT ON TABLE private.order_notification_jobs IS
  'Backend-only outbox. One row per order_requests insert. Not exposed to anon or authenticated.';

CREATE INDEX idx_order_notification_jobs_due
  ON private.order_notification_jobs (created_at)
  WHERE status IN ('pending', 'processing');

ALTER TABLE private.order_notification_jobs ENABLE ROW LEVEL SECURITY;

REVOKE ALL ON TABLE private.order_notification_jobs FROM PUBLIC, anon, authenticated;
GRANT SELECT, INSERT, UPDATE, DELETE ON TABLE private.order_notification_jobs TO service_role;

CREATE FUNCTION private.enqueue_order_notification()
RETURNS trigger
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = private, pg_catalog
AS $$
BEGIN
  INSERT INTO private.order_notification_jobs (order_id)
  VALUES (NEW.id)
  ON CONFLICT (order_id) DO NOTHING;
  RETURN NEW;
END;
$$;

REVOKE ALL ON FUNCTION private.enqueue_order_notification() FROM PUBLIC, anon, authenticated, service_role;

CREATE TRIGGER order_requests_enqueue_notification
  AFTER INSERT ON public.order_requests
  FOR EACH ROW
  EXECUTE FUNCTION private.enqueue_order_notification();

CREATE FUNCTION public.claim_order_notification_jobs(p_limit integer DEFAULT 5)
RETURNS TABLE (job_id uuid, order_id uuid, attempts integer)
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = private, pg_catalog
AS $$
DECLARE
  v_limit integer;
BEGIN
  v_limit := LEAST(GREATEST(COALESCE(p_limit, 5), 1), 10);

  -- A final attempt whose worker died stays dead. Do not send it again.
  -- Columns are qualified because RETURNS TABLE creates an `attempts` variable.
  UPDATE private.order_notification_jobs AS j
  SET status = 'dead',
      last_error = 'lease_expired',
      locked_until = NULL,
      updated_at = now()
  WHERE j.status = 'processing'
    AND j.locked_until IS NOT NULL
    AND j.locked_until <= now()
    AND j.attempts >= j.max_attempts;

  RETURN QUERY
  WITH picked AS (
    SELECT j.id
    FROM private.order_notification_jobs j
    WHERE j.attempts < j.max_attempts
      AND (
        (j.status = 'pending' AND j.next_attempt_at <= now())
        OR (
          j.status = 'processing'
          AND j.locked_until IS NOT NULL
          AND j.locked_until <= now()
        )
      )
    ORDER BY j.created_at
    FOR UPDATE SKIP LOCKED
    LIMIT v_limit
  )
  UPDATE private.order_notification_jobs j
  SET status = 'processing',
      attempts = j.attempts + 1,
      locked_until = now() + interval '2 minutes',
      updated_at = now()
  FROM picked
  WHERE j.id = picked.id
  RETURNING j.id, j.order_id, j.attempts;
END;
$$;

CREATE FUNCTION public.complete_order_notification_job(
  p_job_id uuid,
  p_message_id bigint
)
RETURNS boolean
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = private, pg_catalog
AS $$
DECLARE
  v_updated integer;
BEGIN
  UPDATE private.order_notification_jobs
  SET status = 'sent',
      sent_at = now(),
      telegram_message_id = p_message_id,
      last_error = NULL,
      locked_until = NULL,
      updated_at = now()
  WHERE id = p_job_id
    AND status = 'processing';
  GET DIAGNOSTICS v_updated = ROW_COUNT;
  RETURN v_updated = 1;
END;
$$;

CREATE FUNCTION public.fail_order_notification_job(
  p_job_id uuid,
  p_error text,
  p_retryable boolean
)
RETURNS boolean
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = private, pg_catalog
AS $$
DECLARE
  v_updated integer;
BEGIN
  UPDATE private.order_notification_jobs j
  SET status = CASE
        WHEN NOT COALESCE(p_retryable, false) OR j.attempts >= j.max_attempts
          THEN 'dead'
        ELSE 'pending'
      END,
      last_error = left(COALESCE(p_error, 'unknown'), 80),
      locked_until = NULL,
      updated_at = now(),
      next_attempt_at = CASE
        WHEN NOT COALESCE(p_retryable, false) OR j.attempts >= j.max_attempts
          THEN j.next_attempt_at
        ELSE now() + make_interval(mins => least(power(2, j.attempts)::int, 60))
      END
  WHERE j.id = p_job_id
    AND j.status = 'processing';
  GET DIAGNOSTICS v_updated = ROW_COUNT;
  RETURN v_updated = 1;
END;
$$;

REVOKE ALL ON FUNCTION public.claim_order_notification_jobs(integer) FROM PUBLIC, anon, authenticated;
REVOKE ALL ON FUNCTION public.complete_order_notification_job(uuid, bigint) FROM PUBLIC, anon, authenticated;
REVOKE ALL ON FUNCTION public.fail_order_notification_job(uuid, text, boolean) FROM PUBLIC, anon, authenticated;

GRANT EXECUTE ON FUNCTION public.claim_order_notification_jobs(integer) TO service_role;
GRANT EXECUTE ON FUNCTION public.complete_order_notification_job(uuid, bigint) TO service_role;
GRANT EXECUTE ON FUNCTION public.fail_order_notification_job(uuid, text, boolean) TO service_role;
