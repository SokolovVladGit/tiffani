-- ============================================================================
-- Discount engine — Phase 1 (additive, read-only quoter).
--
-- Scope (intentionally bounded):
--   1. New tables:
--        public.discount_campaigns
--        public.discount_campaign_targets
--        public.discount_redemptions
--   2. Additive snapshot columns on:
--        public.order_requests        (subtotal, discount, grand total, etc.)
--        public.order_request_items   (per-line price/discount/total)
--   3. RLS: direct table access for admins only (via public.is_admin()).
--   4. New SECURITY DEFINER RPC:
--        public.quote_order_v1(p_customer JSONB, p_items JSONB)
--      Read-only quoting (no writes, no used_count increment).
--
-- What this migration explicitly does NOT do:
--   - It does NOT modify public.submit_order_v2.
--   - It does NOT modify public.catalog_items (view/contract).
--   - It does NOT change semantics of order_requests.total_price or
--     order_request_items.line_total (existing columns kept untouched).
--   - It does NOT touch Flutter, Edge Functions, cron, or sync code.
--   - It does NOT write any rows.
--
-- Compatibility:
--   - All ALTERs are ADD COLUMN IF NOT EXISTS.
--   - All policies/constraints use DROP IF EXISTS + CREATE pattern.
--   - All indexes use IF NOT EXISTS.
--   - The migration is safe to re-apply.
--
-- Pricing version returned by quote_order_v1: 'discount_v1'.
-- ============================================================================

BEGIN;

-- ============================================================================
-- 1. discount_campaigns
-- ============================================================================
CREATE TABLE IF NOT EXISTS public.discount_campaigns (
  id                          uuid          PRIMARY KEY DEFAULT gen_random_uuid(),
  kind                        text          NOT NULL,
  name                        text          NOT NULL,
  code                        text          NULL,
  description                 text          NULL,
  percent_off                 numeric(5,2)  NOT NULL,
  min_order_amount            numeric(12,2) NOT NULL DEFAULT 0,
  starts_at                   timestamptz   NULL,
  ends_at                     timestamptz   NULL,
  max_redemptions             integer       NULL,
  used_count                  integer       NOT NULL DEFAULT 0,
  is_active                   boolean       NOT NULL DEFAULT true,
  stackable_with_promocode    boolean       NOT NULL DEFAULT false,
  priority                    integer       NOT NULL DEFAULT 100,
  source                      text          NOT NULL DEFAULT 'manual',
  external_ref                text          NULL,
  metadata                    jsonb         NOT NULL DEFAULT '{}'::jsonb,
  created_at                  timestamptz   NOT NULL DEFAULT now(),
  updated_at                  timestamptz   NOT NULL DEFAULT now()
);

ALTER TABLE public.discount_campaigns
  DROP CONSTRAINT IF EXISTS chk_discount_campaigns_kind;
ALTER TABLE public.discount_campaigns
  ADD CONSTRAINT chk_discount_campaigns_kind
  CHECK (kind IN ('automatic', 'promocode'));

ALTER TABLE public.discount_campaigns
  DROP CONSTRAINT IF EXISTS chk_discount_campaigns_percent_off;
ALTER TABLE public.discount_campaigns
  ADD CONSTRAINT chk_discount_campaigns_percent_off
  CHECK (percent_off > 0 AND percent_off <= 100);

ALTER TABLE public.discount_campaigns
  DROP CONSTRAINT IF EXISTS chk_discount_campaigns_min_order_amount;
ALTER TABLE public.discount_campaigns
  ADD CONSTRAINT chk_discount_campaigns_min_order_amount
  CHECK (min_order_amount >= 0);

ALTER TABLE public.discount_campaigns
  DROP CONSTRAINT IF EXISTS chk_discount_campaigns_max_redemptions;
ALTER TABLE public.discount_campaigns
  ADD CONSTRAINT chk_discount_campaigns_max_redemptions
  CHECK (max_redemptions IS NULL OR max_redemptions > 0);

ALTER TABLE public.discount_campaigns
  DROP CONSTRAINT IF EXISTS chk_discount_campaigns_used_count;
ALTER TABLE public.discount_campaigns
  ADD CONSTRAINT chk_discount_campaigns_used_count
  CHECK (used_count >= 0);

-- Promocodes must carry a non-empty code; automatic campaigns must NOT.
ALTER TABLE public.discount_campaigns
  DROP CONSTRAINT IF EXISTS chk_discount_campaigns_code_kind;
ALTER TABLE public.discount_campaigns
  ADD CONSTRAINT chk_discount_campaigns_code_kind
  CHECK (
    (kind = 'promocode' AND code IS NOT NULL AND TRIM(code) <> '')
    OR (kind = 'automatic' AND code IS NULL)
  );

-- Case-insensitive uniqueness for promocode codes only.
CREATE UNIQUE INDEX IF NOT EXISTS uq_discount_campaigns_promocode_upper
  ON public.discount_campaigns (UPPER(code))
  WHERE kind = 'promocode' AND code IS NOT NULL;

CREATE INDEX IF NOT EXISTS idx_discount_campaigns_active_window
  ON public.discount_campaigns (is_active, starts_at, ends_at);

CREATE INDEX IF NOT EXISTS idx_discount_campaigns_kind_active
  ON public.discount_campaigns (kind, is_active);

-- ============================================================================
-- 2. discount_campaign_targets
-- ============================================================================
CREATE TABLE IF NOT EXISTS public.discount_campaign_targets (
  id           uuid        PRIMARY KEY DEFAULT gen_random_uuid(),
  campaign_id  uuid        NOT NULL REFERENCES public.discount_campaigns(id) ON DELETE CASCADE,
  target_type  text        NOT NULL,
  target_value text        NULL,
  match_mode   text        NOT NULL DEFAULT 'exact',
  created_at   timestamptz NOT NULL DEFAULT now()
);

ALTER TABLE public.discount_campaign_targets
  DROP CONSTRAINT IF EXISTS chk_discount_targets_type;
ALTER TABLE public.discount_campaign_targets
  ADD CONSTRAINT chk_discount_targets_type
  CHECK (target_type IN (
    'all', 'category', 'brand', 'mark',
    'product_tilda_uid', 'product_id', 'variant_id'
  ));

ALTER TABLE public.discount_campaign_targets
  DROP CONSTRAINT IF EXISTS chk_discount_targets_match_mode;
ALTER TABLE public.discount_campaign_targets
  ADD CONSTRAINT chk_discount_targets_match_mode
  CHECK (match_mode IN ('exact', 'prefix', 'contains'));

ALTER TABLE public.discount_campaign_targets
  DROP CONSTRAINT IF EXISTS chk_discount_targets_value_presence;
ALTER TABLE public.discount_campaign_targets
  ADD CONSTRAINT chk_discount_targets_value_presence
  CHECK (
    (target_type = 'all'  AND target_value IS NULL)
    OR (target_type <> 'all' AND target_value IS NOT NULL)
  );

-- Combined uniqueness; COALESCE handles the 'all' (NULL value) row.
CREATE UNIQUE INDEX IF NOT EXISTS uq_discount_targets_combo
  ON public.discount_campaign_targets (
    campaign_id, target_type, COALESCE(target_value, ''), match_mode
  );

CREATE INDEX IF NOT EXISTS idx_discount_targets_campaign_id
  ON public.discount_campaign_targets (campaign_id);

CREATE INDEX IF NOT EXISTS idx_discount_targets_type_value_lower
  ON public.discount_campaign_targets (target_type, LOWER(target_value));

-- ============================================================================
-- 3. discount_redemptions (written by future submit_order_v3, not by quoter)
-- ============================================================================
CREATE TABLE IF NOT EXISTS public.discount_redemptions (
  id                uuid          PRIMARY KEY DEFAULT gen_random_uuid(),
  campaign_id       uuid          NOT NULL REFERENCES public.discount_campaigns(id),
  order_request_id  uuid          NULL REFERENCES public.order_requests(id) ON DELETE SET NULL,
  user_id           uuid          NULL REFERENCES auth.users(id) ON DELETE SET NULL,
  customer_phone    text          NULL,
  code              text          NULL,
  subtotal_amount   numeric(12,2) NOT NULL DEFAULT 0,
  discount_amount   numeric(12,2) NOT NULL DEFAULT 0,
  metadata          jsonb         NOT NULL DEFAULT '{}'::jsonb,
  created_at        timestamptz   NOT NULL DEFAULT now()
);

ALTER TABLE public.discount_redemptions
  DROP CONSTRAINT IF EXISTS chk_discount_redemptions_amounts_non_negative;
ALTER TABLE public.discount_redemptions
  ADD CONSTRAINT chk_discount_redemptions_amounts_non_negative
  CHECK (subtotal_amount >= 0 AND discount_amount >= 0);

CREATE INDEX IF NOT EXISTS idx_discount_redemptions_campaign_id
  ON public.discount_redemptions (campaign_id);

CREATE INDEX IF NOT EXISTS idx_discount_redemptions_order_request_id
  ON public.discount_redemptions (order_request_id);

CREATE INDEX IF NOT EXISTS idx_discount_redemptions_user_id
  ON public.discount_redemptions (user_id);

CREATE INDEX IF NOT EXISTS idx_discount_redemptions_created_at
  ON public.discount_redemptions (created_at);

-- ============================================================================
-- 4. order_requests — additive discount snapshot columns.
--    NOTE: existing total_price (DOUBLE PRECISION) and fulfillment_fee
--          (DOUBLE PRECISION) keep their current meaning byte-identical.
--          New columns are NUMERIC(12,2) for monetary precision; the
--          future submit_order_v3 will populate both old and new fields.
-- ============================================================================
ALTER TABLE public.order_requests
  ADD COLUMN IF NOT EXISTS subtotal_amount             numeric(12,2);
ALTER TABLE public.order_requests
  ADD COLUMN IF NOT EXISTS discount_amount             numeric(12,2) NOT NULL DEFAULT 0;
ALTER TABLE public.order_requests
  ADD COLUMN IF NOT EXISTS grand_total_amount          numeric(12,2);
ALTER TABLE public.order_requests
  ADD COLUMN IF NOT EXISTS applied_promocode_code      text;
ALTER TABLE public.order_requests
  ADD COLUMN IF NOT EXISTS applied_discount_snapshot   jsonb         NOT NULL DEFAULT '[]'::jsonb;
ALTER TABLE public.order_requests
  ADD COLUMN IF NOT EXISTS pricing_version             text;
ALTER TABLE public.order_requests
  ADD COLUMN IF NOT EXISTS pricing_metadata            jsonb         NOT NULL DEFAULT '{}'::jsonb;

ALTER TABLE public.order_requests
  DROP CONSTRAINT IF EXISTS chk_order_requests_discount_amount_non_negative;
ALTER TABLE public.order_requests
  ADD CONSTRAINT chk_order_requests_discount_amount_non_negative
  CHECK (discount_amount >= 0);

-- ============================================================================
-- 5. order_request_items — additive per-line columns.
--    NOTE: existing price (DOUBLE PRECISION) and line_total (DOUBLE PRECISION)
--          keep their current meaning. New numeric columns are populated by
--          a future submit_order_v3 only.
-- ============================================================================
ALTER TABLE public.order_request_items
  ADD COLUMN IF NOT EXISTS unit_price_amount         numeric(12,2);
ALTER TABLE public.order_request_items
  ADD COLUMN IF NOT EXISTS line_subtotal_amount      numeric(12,2);
ALTER TABLE public.order_request_items
  ADD COLUMN IF NOT EXISTS line_discount_amount      numeric(12,2) NOT NULL DEFAULT 0;
ALTER TABLE public.order_request_items
  ADD COLUMN IF NOT EXISTS line_total_amount         numeric(12,2);
ALTER TABLE public.order_request_items
  ADD COLUMN IF NOT EXISTS applied_discount_snapshot jsonb         NOT NULL DEFAULT '[]'::jsonb;

ALTER TABLE public.order_request_items
  DROP CONSTRAINT IF EXISTS chk_order_request_items_line_discount_non_negative;
ALTER TABLE public.order_request_items
  ADD CONSTRAINT chk_order_request_items_line_discount_non_negative
  CHECK (line_discount_amount >= 0);

-- ============================================================================
-- 6. updated_at trigger (scoped to discount_campaigns only).
--    No reusable trigger function exists in this repo; create a small one
--    namespaced to this domain to avoid colliding with future generic helpers.
-- ============================================================================
CREATE OR REPLACE FUNCTION public.set_discount_campaigns_updated_at()
RETURNS trigger
LANGUAGE plpgsql
AS $$
BEGIN
  NEW.updated_at := now();
  RETURN NEW;
END;
$$;

DROP TRIGGER IF EXISTS trg_discount_campaigns_updated_at
  ON public.discount_campaigns;
CREATE TRIGGER trg_discount_campaigns_updated_at
  BEFORE UPDATE ON public.discount_campaigns
  FOR EACH ROW
  EXECUTE FUNCTION public.set_discount_campaigns_updated_at();

-- ============================================================================
-- 7. RLS — direct table access restricted to admins (via public.is_admin()).
--    Quoting/redemption flows must go through SECURITY DEFINER RPCs.
-- ============================================================================
ALTER TABLE public.discount_campaigns         ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.discount_campaign_targets  ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.discount_redemptions       ENABLE ROW LEVEL SECURITY;

-- discount_campaigns ---------------------------------------------------------
DROP POLICY IF EXISTS discount_campaigns_admin_select ON public.discount_campaigns;
CREATE POLICY discount_campaigns_admin_select
  ON public.discount_campaigns
  FOR SELECT TO authenticated
  USING (public.is_admin());

DROP POLICY IF EXISTS discount_campaigns_admin_insert ON public.discount_campaigns;
CREATE POLICY discount_campaigns_admin_insert
  ON public.discount_campaigns
  FOR INSERT TO authenticated
  WITH CHECK (public.is_admin());

DROP POLICY IF EXISTS discount_campaigns_admin_update ON public.discount_campaigns;
CREATE POLICY discount_campaigns_admin_update
  ON public.discount_campaigns
  FOR UPDATE TO authenticated
  USING (public.is_admin())
  WITH CHECK (public.is_admin());

DROP POLICY IF EXISTS discount_campaigns_admin_delete ON public.discount_campaigns;
CREATE POLICY discount_campaigns_admin_delete
  ON public.discount_campaigns
  FOR DELETE TO authenticated
  USING (public.is_admin());

-- discount_campaign_targets --------------------------------------------------
DROP POLICY IF EXISTS discount_targets_admin_select ON public.discount_campaign_targets;
CREATE POLICY discount_targets_admin_select
  ON public.discount_campaign_targets
  FOR SELECT TO authenticated
  USING (public.is_admin());

DROP POLICY IF EXISTS discount_targets_admin_insert ON public.discount_campaign_targets;
CREATE POLICY discount_targets_admin_insert
  ON public.discount_campaign_targets
  FOR INSERT TO authenticated
  WITH CHECK (public.is_admin());

DROP POLICY IF EXISTS discount_targets_admin_update ON public.discount_campaign_targets;
CREATE POLICY discount_targets_admin_update
  ON public.discount_campaign_targets
  FOR UPDATE TO authenticated
  USING (public.is_admin())
  WITH CHECK (public.is_admin());

DROP POLICY IF EXISTS discount_targets_admin_delete ON public.discount_campaign_targets;
CREATE POLICY discount_targets_admin_delete
  ON public.discount_campaign_targets
  FOR DELETE TO authenticated
  USING (public.is_admin());

-- discount_redemptions -------------------------------------------------------
DROP POLICY IF EXISTS discount_redemptions_admin_select ON public.discount_redemptions;
CREATE POLICY discount_redemptions_admin_select
  ON public.discount_redemptions
  FOR SELECT TO authenticated
  USING (public.is_admin());

DROP POLICY IF EXISTS discount_redemptions_admin_insert ON public.discount_redemptions;
CREATE POLICY discount_redemptions_admin_insert
  ON public.discount_redemptions
  FOR INSERT TO authenticated
  WITH CHECK (public.is_admin());

DROP POLICY IF EXISTS discount_redemptions_admin_update ON public.discount_redemptions;
CREATE POLICY discount_redemptions_admin_update
  ON public.discount_redemptions
  FOR UPDATE TO authenticated
  USING (public.is_admin())
  WITH CHECK (public.is_admin());

DROP POLICY IF EXISTS discount_redemptions_admin_delete ON public.discount_redemptions;
CREATE POLICY discount_redemptions_admin_delete
  ON public.discount_redemptions
  FOR DELETE TO authenticated
  USING (public.is_admin());

-- ============================================================================
-- 8. Helper: text match by mode.
--    Used internally by quote_order_v1; case-insensitive throughout.
-- ============================================================================
CREATE OR REPLACE FUNCTION public._discount_text_match(
  p_field text,
  p_value text,
  p_mode  text
)
RETURNS boolean
LANGUAGE sql
IMMUTABLE
AS $$
  SELECT CASE
    WHEN p_field IS NULL OR p_value IS NULL THEN false
    WHEN p_mode  = 'exact'    THEN lower(p_field) = lower(p_value)
    WHEN p_mode  = 'prefix'   THEN lower(p_field) LIKE lower(p_value) || '%'
    WHEN p_mode  = 'contains' THEN lower(p_field) LIKE '%' || lower(p_value) || '%'
    ELSE false
  END;
$$;

-- ============================================================================
-- 9. quote_order_v1 — read-only quoter.
--    SECURITY DEFINER + restricted search_path so anon/authenticated callers
--    can preview totals without seeing the raw discount tables.
--    NEVER writes; never increments used_count.
-- ============================================================================
DROP FUNCTION IF EXISTS public.quote_order_v1(JSONB, JSONB);

CREATE OR REPLACE FUNCTION public.quote_order_v1(
  p_customer JSONB,
  p_items    JSONB
)
RETURNS JSONB
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public, pg_temp
AS $$
DECLARE
  v_pricing_version  CONSTANT text := 'discount_v1';

  v_promo_raw        text;
  v_promo_norm       text;
  v_fee              numeric(12,2) := 0;
  v_subtotal         numeric(12,2) := 0;
  v_discount         numeric(12,2) := 0;
  v_grand_total      numeric(12,2) := 0;

  v_input_errors     jsonb := '[]'::jsonb;
  v_resolution_errs  jsonb := '[]'::jsonb;
  v_lines            jsonb := '[]'::jsonb;
  v_lines_out        jsonb := '[]'::jsonb;
  v_applied_summary  jsonb := '[]'::jsonb;

  v_promo_status     text := 'not_provided';
  v_promo_message    text := NULL;
  v_promo_campaign   record;
  v_promo_id         uuid := NULL;
  v_promo_eligible   boolean := false;
  v_promo_matched_a_line boolean := false;
  v_now              timestamptz := now();
BEGIN
  -- --------------------------------------------------------------------------
  -- (a) Normalize promo code.
  -- --------------------------------------------------------------------------
  v_promo_raw  := NULLIF(TRIM(COALESCE(p_customer->>'promo_code', '')), '');
  IF v_promo_raw IS NOT NULL THEN
    v_promo_norm   := UPPER(v_promo_raw);
    v_promo_status := 'not_found';
  END IF;

  -- --------------------------------------------------------------------------
  -- (b) Parse fulfillment_fee (NULL/missing/invalid → 0; clamp to >= 0).
  -- --------------------------------------------------------------------------
  IF p_customer ? 'fulfillment_fee'
     AND p_customer->>'fulfillment_fee' IS NOT NULL
     AND TRIM(p_customer->>'fulfillment_fee') <> '' THEN
    BEGIN
      v_fee := (p_customer->>'fulfillment_fee')::numeric(12,2);
    EXCEPTION WHEN others THEN
      v_fee := 0;
    END;
  END IF;
  IF v_fee < 0 THEN
    v_fee := 0;
  END IF;

  -- --------------------------------------------------------------------------
  -- (c) Validate items array shape.
  -- --------------------------------------------------------------------------
  IF p_items IS NULL
     OR jsonb_typeof(p_items) <> 'array'
     OR jsonb_array_length(p_items) = 0 THEN
    RETURN jsonb_build_object(
      'ok',               false,
      'pricing_version',  v_pricing_version,
      'errors',           jsonb_build_array(jsonb_build_object(
        'code',    'empty_items',
        'message', 'Корзина пуста'
      ))
    );
  END IF;

  -- --------------------------------------------------------------------------
  -- (d) Per-item input validation (variant_id presence, quantity > 0).
  --     quantity must be an integer literal; non-integer / negative / zero
  --     values are rejected. We accept it as text first to avoid raising
  --     a numeric cast exception inside the function.
  -- --------------------------------------------------------------------------
  WITH raw AS (
    SELECT
      ord                                    AS ord,
      item->>'variant_id'                    AS vid,
      item->>'quantity'                      AS qty_raw
    FROM jsonb_array_elements(p_items) WITH ORDINALITY t(item, ord)
  ),
  parsed AS (
    SELECT
      ord,
      vid,
      CASE
        WHEN qty_raw IS NULL OR TRIM(qty_raw) = '' THEN NULL
        ELSE (
          CASE
            WHEN qty_raw ~ '^-?[0-9]+$' THEN qty_raw::int
            ELSE NULL
          END
        )
      END AS qty
    FROM raw
  )
  SELECT COALESCE(jsonb_agg(jsonb_build_object(
    'code', CASE
      WHEN vid IS NULL OR TRIM(vid) = '' THEN 'missing_variant_id'
      ELSE 'invalid_quantity'
    END,
    'message', CASE
      WHEN vid IS NULL OR TRIM(vid) = '' THEN 'variant_id is required'
      ELSE 'quantity must be a positive integer'
    END,
    'variant_id', vid,
    'ordinal', ord
  ) ORDER BY ord), '[]'::jsonb)
  INTO v_input_errors
  FROM parsed
  WHERE vid IS NULL OR TRIM(vid) = '' OR qty IS NULL OR qty < 1;

  IF jsonb_array_length(v_input_errors) > 0 THEN
    RETURN jsonb_build_object(
      'ok',              false,
      'pricing_version', v_pricing_version,
      'errors',          v_input_errors
    );
  END IF;

  -- --------------------------------------------------------------------------
  -- (e) Resolve lines via catalog_items, supporting both canonical
  --     variant_id and legacy_variant_uuid. Normalize to canonical.
  --     Also collect resolution errors in the same pass.
  -- --------------------------------------------------------------------------
  WITH input AS (
    SELECT
      ord                              AS ord,
      item->>'variant_id'              AS vid_in,
      (item->>'quantity')::int         AS qty
    FROM jsonb_array_elements(p_items) WITH ORDINALITY t(item, ord)
  ),
  resolved AS (
    SELECT
      i.ord,
      i.vid_in,
      i.qty,
      c.variant_id                                              AS canonical_variant_id,
      c.legacy_variant_uuid                                     AS legacy_variant_uuid,
      c.product_id                                              AS product_id,
      c.tilda_uid                                               AS tilda_uid,
      c.title                                                   AS title,
      c.brand                                                   AS brand,
      c.category                                                AS category,
      c.mark                                                    AS mark,
      c.is_active                                               AS is_active,
      (c.price)::numeric(12,2)                                  AS unit_price
    FROM input i
    LEFT JOIN public.catalog_items c
      ON c.variant_id          = i.vid_in
      OR c.legacy_variant_uuid = i.vid_in
  )
  SELECT
    COALESCE(jsonb_agg(
      jsonb_build_object(
        'code', CASE
          WHEN canonical_variant_id IS NULL THEN 'unknown_variant'
          WHEN is_active = false            THEN 'inactive_variant'
          WHEN unit_price IS NULL           THEN 'no_price'
          ELSE NULL
        END,
        'message', CASE
          WHEN canonical_variant_id IS NULL THEN 'Variant not found'
          WHEN is_active = false            THEN 'Variant is inactive'
          WHEN unit_price IS NULL           THEN 'Variant has no price'
          ELSE NULL
        END,
        'variant_id', vid_in,
        'ordinal',    ord
      )
    ) FILTER (
      WHERE canonical_variant_id IS NULL
         OR is_active = false
         OR unit_price IS NULL
    ), '[]'::jsonb)
  INTO v_resolution_errs
  FROM resolved;

  IF jsonb_array_length(v_resolution_errs) > 0 THEN
    RETURN jsonb_build_object(
      'ok',              false,
      'pricing_version', v_pricing_version,
      'errors',          v_resolution_errs
    );
  END IF;

  -- Build canonical line list (jsonb array, one element per input line,
  -- preserving input ordinal). All numeric values are NUMERIC(12,2).
  WITH input AS (
    SELECT
      ord                              AS ord,
      item->>'variant_id'              AS vid_in,
      (item->>'quantity')::int         AS qty
    FROM jsonb_array_elements(p_items) WITH ORDINALITY t(item, ord)
  ),
  resolved AS (
    SELECT
      i.ord,
      i.qty,
      c.variant_id                              AS canonical_variant_id,
      c.legacy_variant_uuid                     AS legacy_variant_uuid,
      c.product_id                              AS product_id,
      c.tilda_uid                               AS tilda_uid,
      c.title, c.brand, c.category, c.mark,
      (c.price)::numeric(12,2)                  AS unit_price,
      ROUND((c.price)::numeric(12,2) * i.qty, 2) AS line_subtotal
    FROM input i
    JOIN public.catalog_items c
      ON c.variant_id          = i.vid_in
      OR c.legacy_variant_uuid = i.vid_in
  )
  SELECT COALESCE(jsonb_agg(
    jsonb_build_object(
      'ord',                  ord,
      'variant_id',           canonical_variant_id,
      'legacy_variant_uuid',  legacy_variant_uuid,
      'product_id',           product_id,
      'tilda_uid',            tilda_uid,
      'title',                title,
      'brand',                brand,
      'category',             category,
      'mark',                 mark,
      'quantity',             qty,
      'unit_price',           unit_price,
      'line_subtotal',        line_subtotal
    ) ORDER BY ord
  ), '[]'::jsonb)
  INTO v_lines
  FROM resolved;

  -- --------------------------------------------------------------------------
  -- (f) Compute order subtotal.
  -- --------------------------------------------------------------------------
  SELECT COALESCE(SUM((l->>'line_subtotal')::numeric(12,2)), 0)
  INTO v_subtotal
  FROM jsonb_array_elements(v_lines) l;

  -- --------------------------------------------------------------------------
  -- (g) Look up promo campaign (raw, before eligibility checks) and
  --     classify ineligibility statuses.
  -- --------------------------------------------------------------------------
  IF v_promo_norm IS NOT NULL THEN
    SELECT *
    INTO v_promo_campaign
    FROM public.discount_campaigns
    WHERE kind = 'promocode'
      AND code IS NOT NULL
      AND UPPER(code) = v_promo_norm
    LIMIT 1;

    IF NOT FOUND THEN
      v_promo_status  := 'not_found';
      v_promo_message := 'Промокод не найден';
    ELSIF v_promo_campaign.is_active = false THEN
      v_promo_status  := 'inactive';
      v_promo_message := 'Промокод отключён';
    ELSIF v_promo_campaign.starts_at IS NOT NULL AND v_promo_campaign.starts_at > v_now THEN
      v_promo_status  := 'not_started';
      v_promo_message := 'Промокод ещё не действует';
    ELSIF v_promo_campaign.ends_at   IS NOT NULL AND v_promo_campaign.ends_at  <= v_now THEN
      v_promo_status  := 'expired';
      v_promo_message := 'Срок действия промокода истёк';
    ELSIF v_promo_campaign.max_redemptions IS NOT NULL
          AND v_promo_campaign.used_count >= v_promo_campaign.max_redemptions THEN
      v_promo_status  := 'limit_reached';
      v_promo_message := 'Лимит использований промокода исчерпан';
    ELSIF v_subtotal < v_promo_campaign.min_order_amount THEN
      v_promo_status  := 'min_order_not_met';
      v_promo_message := 'Сумма заказа меньше минимальной для этого промокода';
    ELSE
      v_promo_eligible := true;
      v_promo_id       := v_promo_campaign.id;
    END IF;
  END IF;

  -- --------------------------------------------------------------------------
  -- (h) Build per-line × campaign candidates and pick the best discount
  --     per line (no stacking in v1).
  --
  --     Eligible campaigns are:
  --       - active
  --       - within optional time window
  --       - subtotal >= min_order_amount
  --       - max_redemptions IS NULL OR used_count < max_redemptions
  --       - kind = 'automatic'
  --         OR (kind = 'promocode' AND id = v_promo_id  -- only the eligible promo)
  --
  --     Targeting:
  --       - A campaign with NO target rows applies to all lines.
  --       - A campaign with a target_type='all' row applies to all lines.
  --       - Otherwise, the campaign applies to a line iff at least one
  --         non-'all' target row matches the line's relevant field via
  --         the configured match_mode (exact/prefix/contains, lowercased).
  -- --------------------------------------------------------------------------
  WITH line_rows AS (
    SELECT
      (l->>'ord')::int                              AS ord,
      l->>'variant_id'                              AS variant_id,
      l->>'legacy_variant_uuid'                     AS legacy_variant_uuid,
      l->>'product_id'                              AS product_id,
      l->>'tilda_uid'                               AS tilda_uid,
      l->>'title'                                   AS title,
      l->>'brand'                                   AS brand,
      l->>'category'                                AS category,
      l->>'mark'                                    AS mark,
      (l->>'quantity')::int                         AS quantity,
      (l->>'unit_price')::numeric(12,2)             AS unit_price,
      (l->>'line_subtotal')::numeric(12,2)          AS line_subtotal
    FROM jsonb_array_elements(v_lines) l
  ),
  eligible_campaigns AS (
    SELECT
      dc.*
    FROM public.discount_campaigns dc
    WHERE dc.is_active = true
      AND (dc.starts_at IS NULL OR dc.starts_at <= v_now)
      AND (dc.ends_at   IS NULL OR dc.ends_at   >  v_now)
      AND (dc.max_redemptions IS NULL OR dc.used_count < dc.max_redemptions)
      AND v_subtotal >= dc.min_order_amount
      AND (
        dc.kind = 'automatic'
        OR (dc.kind = 'promocode' AND v_promo_id IS NOT NULL AND dc.id = v_promo_id)
      )
  ),
  campaign_target_counts AS (
    SELECT campaign_id, COUNT(*) AS n
    FROM public.discount_campaign_targets
    GROUP BY campaign_id
  ),
  candidates AS (
    SELECT
      lr.ord,
      lr.variant_id,
      lr.line_subtotal,
      ec.id            AS campaign_id,
      ec.kind          AS campaign_kind,
      ec.name          AS campaign_name,
      ec.code          AS campaign_code,
      ec.percent_off   AS percent_off,
      ec.priority      AS priority,
      ec.created_at    AS created_at,
      ROUND(lr.line_subtotal * ec.percent_off / 100.0, 2) AS line_discount_amount
    FROM line_rows lr
    CROSS JOIN eligible_campaigns ec
    LEFT JOIN campaign_target_counts ctc ON ctc.campaign_id = ec.id
    WHERE
      ctc.n IS NULL
      OR EXISTS (
        SELECT 1
        FROM public.discount_campaign_targets t
        WHERE t.campaign_id = ec.id
          AND (
            t.target_type = 'all'
            OR (t.target_type = 'category'
                AND public._discount_text_match(lr.category, t.target_value, t.match_mode))
            OR (t.target_type = 'brand'
                AND public._discount_text_match(lr.brand, t.target_value, t.match_mode))
            OR (t.target_type = 'mark'
                AND public._discount_text_match(lr.mark, t.target_value, t.match_mode))
            OR (t.target_type = 'product_tilda_uid'
                AND public._discount_text_match(lr.tilda_uid, t.target_value, t.match_mode))
            OR (t.target_type = 'product_id'
                AND public._discount_text_match(lr.product_id, t.target_value, t.match_mode))
            OR (t.target_type = 'variant_id'
                AND public._discount_text_match(lr.variant_id, t.target_value, t.match_mode))
          )
      )
  ),
  best_per_line AS (
    SELECT DISTINCT ON (ord)
      ord,
      variant_id,
      line_subtotal,
      campaign_id,
      campaign_kind,
      campaign_name,
      campaign_code,
      percent_off,
      line_discount_amount
    FROM candidates
    ORDER BY ord,
             line_discount_amount DESC,
             percent_off          DESC,
             priority             DESC,
             created_at           ASC,
             campaign_id::text    ASC
  )
  SELECT
    COALESCE(jsonb_agg(
      jsonb_build_object(
        'ord',                   lr.ord,
        'variant_id',            lr.variant_id,
        'legacy_variant_uuid',   lr.legacy_variant_uuid,
        'product_id',            lr.product_id,
        'tilda_uid',             lr.tilda_uid,
        'title',                 lr.title,
        'brand',                 lr.brand,
        'category',              lr.category,
        'mark',                  lr.mark,
        'quantity',              lr.quantity,
        'unit_price',            lr.unit_price,
        'line_subtotal_amount',  lr.line_subtotal,
        'line_discount_amount',  COALESCE(bp.line_discount_amount, 0),
        'line_total_amount',     ROUND(lr.line_subtotal - COALESCE(bp.line_discount_amount, 0), 2),
        'applied_discount',      CASE
          WHEN bp.campaign_id IS NULL THEN NULL::jsonb
          ELSE jsonb_build_object(
            'campaign_id', bp.campaign_id,
            'kind',        bp.campaign_kind,
            'name',        bp.campaign_name,
            'code',        bp.campaign_code,
            'percent_off', bp.percent_off
          )
        END
      ) ORDER BY lr.ord
    ), '[]'::jsonb)
  INTO v_lines_out
  FROM line_rows lr
  LEFT JOIN best_per_line bp ON bp.ord = lr.ord;

  -- --------------------------------------------------------------------------
  -- (i) Aggregate totals and applied-discount summary.
  -- --------------------------------------------------------------------------
  SELECT COALESCE(SUM((l->>'line_discount_amount')::numeric(12,2)), 0)
  INTO v_discount
  FROM jsonb_array_elements(v_lines_out) l;

  v_grand_total := ROUND(v_subtotal - v_discount + v_fee, 2);

  -- Applied-discount summary: one entry per distinct campaign actually picked.
  SELECT COALESCE(jsonb_agg(
    jsonb_build_object(
      'campaign_id',     ad.campaign_id,
      'kind',            ad.kind,
      'name',            ad.name,
      'code',            ad.code,
      'percent_off',     ad.percent_off,
      'discount_amount', ad.total_amount
    ) ORDER BY ad.total_amount DESC, ad.campaign_id
  ), '[]'::jsonb)
  INTO v_applied_summary
  FROM (
    SELECT
      (l->'applied_discount'->>'campaign_id')                AS campaign_id,
      (l->'applied_discount'->>'kind')                       AS kind,
      (l->'applied_discount'->>'name')                       AS name,
      (l->'applied_discount'->>'code')                       AS code,
      (l->'applied_discount'->>'percent_off')::numeric(5,2)  AS percent_off,
      SUM((l->>'line_discount_amount')::numeric(12,2))       AS total_amount
    FROM jsonb_array_elements(v_lines_out) l
    WHERE l->'applied_discount' IS NOT NULL
      AND jsonb_typeof(l->'applied_discount') = 'object'
    GROUP BY 1, 2, 3, 4, 5
  ) ad;

  -- --------------------------------------------------------------------------
  -- (j) Promo final status:
  --     - applied: the eligible promo campaign won on at least one line.
  --     - no_matching_items: eligible promo never matched any line targets.
  --     - not_best_discount: eligible promo matched but lost on every line.
  --     - other (not_provided/not_found/inactive/...): set in step (g).
  -- --------------------------------------------------------------------------
  IF v_promo_id IS NOT NULL THEN
    -- Was the promo selected on any line?
    IF EXISTS (
      SELECT 1
      FROM jsonb_array_elements(v_lines_out) l
      WHERE (l->'applied_discount'->>'campaign_id')::uuid = v_promo_id
    ) THEN
      v_promo_status  := 'applied';
      v_promo_message := 'Промокод применён';
    ELSE
      -- Promo was eligible: did it match any line targets at all?
      WITH line_rows AS (
        SELECT
          (l->>'variant_id')                AS variant_id,
          (l->>'product_id')                AS product_id,
          (l->>'tilda_uid')                 AS tilda_uid,
          (l->>'brand')                     AS brand,
          (l->>'category')                  AS category,
          (l->>'mark')                      AS mark
        FROM jsonb_array_elements(v_lines) l
      ),
      target_count AS (
        SELECT COUNT(*) AS n
        FROM public.discount_campaign_targets
        WHERE campaign_id = v_promo_id
      )
      SELECT
        EXISTS (
          SELECT 1 FROM line_rows lr
          WHERE
            (SELECT n FROM target_count) = 0
            OR EXISTS (
              SELECT 1 FROM public.discount_campaign_targets t
              WHERE t.campaign_id = v_promo_id
                AND (
                  t.target_type = 'all'
                  OR (t.target_type = 'category'
                      AND public._discount_text_match(lr.category, t.target_value, t.match_mode))
                  OR (t.target_type = 'brand'
                      AND public._discount_text_match(lr.brand, t.target_value, t.match_mode))
                  OR (t.target_type = 'mark'
                      AND public._discount_text_match(lr.mark, t.target_value, t.match_mode))
                  OR (t.target_type = 'product_tilda_uid'
                      AND public._discount_text_match(lr.tilda_uid, t.target_value, t.match_mode))
                  OR (t.target_type = 'product_id'
                      AND public._discount_text_match(lr.product_id, t.target_value, t.match_mode))
                  OR (t.target_type = 'variant_id'
                      AND public._discount_text_match(lr.variant_id, t.target_value, t.match_mode))
                )
            )
        )
      INTO v_promo_matched_a_line;

      IF v_promo_matched_a_line THEN
        v_promo_status  := 'not_best_discount';
        v_promo_message := 'Автоматическая скидка выгоднее промокода';
      ELSE
        v_promo_status  := 'no_matching_items';
        v_promo_message := 'Промокод не действует ни для одного товара в корзине';
      END IF;
    END IF;
  END IF;

  -- --------------------------------------------------------------------------
  -- (k) Build response.
  -- --------------------------------------------------------------------------
  RETURN jsonb_build_object(
    'ok',                  true,
    'pricing_version',     v_pricing_version,
    'subtotal_amount',     v_subtotal,
    'discount_amount',     v_discount,
    'fulfillment_fee',     v_fee,
    'grand_total_amount',  v_grand_total,
    'promo', jsonb_build_object(
      'code',    v_promo_raw,
      'status',  v_promo_status,
      'message', v_promo_message
    ),
    'applied_discounts',   v_applied_summary,
    'lines',               v_lines_out,
    'errors',              '[]'::jsonb
  );
END;
$$;

GRANT EXECUTE ON FUNCTION public.quote_order_v1(JSONB, JSONB)
  TO anon, authenticated;

COMMIT;
