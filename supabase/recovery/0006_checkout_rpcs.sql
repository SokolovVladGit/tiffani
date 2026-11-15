-- TIFFANI recovery baseline 0006
-- Final function bodies, copied from the last historical definitions.
-- Grants are applied in 0008, not here.
--
-- Sources:
--   _discount_text_match, quote_order_v1
--     20260502120000_discount_engine_phase1.sql
--   submit_order_v3
--     20260502130000_submit_order_v3_discount_snapshot.sql
--   submit_order_v2
--     20260430190000_fix_submit_order_v2_product_id_cast.sql
--   submit_consultation_v1
--     20260421130000_submit_consultation_v1.sql
--
-- product_id writes stay uuid casts. variant_id resolution stays text,
-- with legacy_variant_uuid accepted by submit_order_v2.

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
  v_method           text;
  v_type             text;
  v_expected_fee     numeric(12,2);
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
  -- (b) Fulfillment fee. Method and type are required. The server fee is
  --     the CASE below. A client fee may only repeat it. Omitted fee is
  --     filled from the method. There is no fallback fee.
  --     The same CASE is in submit_order_v3 and submit_order_v2.
  --     Store id and address are submit-only: Flutter quotes before those
  --     fields are filled, with a method already selected.
  -- --------------------------------------------------------------------------
  v_method := NULLIF(btrim(COALESCE(p_customer->>'fulfillment_method_code', '')), '');
  v_type := NULLIF(btrim(COALESCE(p_customer->>'fulfillment_type', '')), '');
  IF v_method IS NULL THEN
    RETURN jsonb_build_object(
      'ok', false,
      'pricing_version', v_pricing_version,
      'errors', jsonb_build_array(jsonb_build_object(
        'code', 'invalid_fulfillment_method_code',
        'message', 'Неверный способ получения'
      ))
    );
  END IF;
  v_expected_fee := CASE v_method
    WHEN 'pickup_store'     THEN 0
    WHEN 'courier_tiraspol' THEN 50
    WHEN 'courier_bender'   THEN 40
    WHEN 'express_post'     THEN 40
    WHEN 'moldova_post'     THEN 30
    ELSE NULL
  END;
  IF v_expected_fee IS NULL THEN
    RETURN jsonb_build_object(
      'ok', false,
      'pricing_version', v_pricing_version,
      'errors', jsonb_build_array(jsonb_build_object(
        'code', 'invalid_fulfillment_method_code',
        'message', 'Неверный способ получения'
      ))
    );
  END IF;
  IF v_type IS NULL OR v_type NOT IN ('pickup', 'delivery') THEN
    RETURN jsonb_build_object(
      'ok', false,
      'pricing_version', v_pricing_version,
      'errors', jsonb_build_array(jsonb_build_object(
        'code', 'invalid_fulfillment_type',
        'message', 'Неверный тип получения заказа'
      ))
    );
  END IF;
  IF v_type = 'pickup' AND v_method <> 'pickup_store' THEN
    RETURN jsonb_build_object(
      'ok', false,
      'pricing_version', v_pricing_version,
      'errors', jsonb_build_array(jsonb_build_object(
        'code', 'invalid_fulfillment_method_code',
        'message', 'Неверный способ получения'
      ))
    );
  END IF;
  IF v_type = 'delivery' AND v_method NOT IN (
      'courier_tiraspol', 'courier_bender', 'express_post', 'moldova_post'
     ) THEN
    RETURN jsonb_build_object(
      'ok', false,
      'pricing_version', v_pricing_version,
      'errors', jsonb_build_array(jsonb_build_object(
        'code', 'invalid_fulfillment_method_code',
        'message', 'Неверный способ получения'
      ))
    );
  END IF;

  IF p_customer ? 'fulfillment_fee'
     AND p_customer->>'fulfillment_fee' IS NOT NULL
     AND btrim(p_customer->>'fulfillment_fee') <> '' THEN
    BEGIN
      v_fee := btrim(p_customer->>'fulfillment_fee')::numeric(12,2);
    EXCEPTION WHEN others THEN
      RETURN jsonb_build_object(
        'ok', false,
        'pricing_version', v_pricing_version,
        'errors', jsonb_build_array(jsonb_build_object(
          'code', 'invalid_fulfillment_fee',
          'message', 'Стоимость доставки указана некорректно'
        ))
      );
    END;
    IF v_fee < 0 THEN
      RETURN jsonb_build_object(
        'ok', false,
        'pricing_version', v_pricing_version,
        'errors', jsonb_build_array(jsonb_build_object(
          'code', 'invalid_fulfillment_fee',
          'message', 'Стоимость доставки указана некорректно'
        ))
      );
    END IF;
    IF v_fee IS DISTINCT FROM v_expected_fee THEN
      RETURN jsonb_build_object(
        'ok', false,
        'pricing_version', v_pricing_version,
        'errors', jsonb_build_array(jsonb_build_object(
          'code', 'fulfillment_fee_mismatch',
          'message', 'Стоимость доставки не совпадает с выбранным способом'
        ))
      );
    END IF;
  END IF;
  v_fee := v_expected_fee;

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
      ROUND(lr.line_subtotal * ec.percent_off / 100, 2) AS line_discount_amount
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

DROP FUNCTION IF EXISTS public.submit_order_v3(JSONB, JSONB);

CREATE OR REPLACE FUNCTION public.submit_order_v3(
  p_customer JSONB,
  p_items    JSONB
)
RETURNS JSONB
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public, pg_temp
AS $$
DECLARE
  -- ---- customer / fulfillment ---------------------------------------------
  v_name                    TEXT;
  v_phone                   TEXT;
  v_consent                 BOOLEAN;
  v_email                   TEXT;
  v_promo_code_in           TEXT;
  v_loyalty_card            TEXT;
  v_comment                 TEXT;
  v_user_id                 UUID;
  v_source                  TEXT;

  v_fulfillment_type        TEXT;
  v_pickup_store_id         TEXT;
  v_delivery_zone           TEXT;
  v_delivery_address        TEXT;
  v_fulfillment_method_code TEXT;
  v_fulfillment_fee_in      DOUBLE PRECISION;
  v_expected_fee            NUMERIC(12,2);
  v_payment_method_code     TEXT;
  v_legacy_delivery_method  TEXT;
  v_legacy_payment_method   TEXT;

  -- ---- quote-derived state ------------------------------------------------
  v_quote                   JSONB;
  v_promo                   JSONB;
  v_promo_status            TEXT;
  v_subtotal                NUMERIC(12,2);
  v_discount                NUMERIC(12,2);
  v_fee                     NUMERIC(12,2);
  v_grand_total             NUMERIC(12,2);
  v_applied_discounts       JSONB;
  v_lines                   JSONB;
  v_total_items             INTEGER;
  v_total_quantity          INTEGER;
  v_applied_promo_code      TEXT;

  -- ---- campaign locking ---------------------------------------------------
  v_applied_ids             UUID[];
  v_invalid_campaign_id     UUID;

  -- ---- output -------------------------------------------------------------
  v_request_id              UUID;
BEGIN
  -- ==========================================================================
  -- 1. Validate core customer fields (mirror submit_order_v2 behavior, but
  --    return ok=false instead of RAISE so the caller can render messages).
  -- ==========================================================================
  v_name    := NULLIF(TRIM(COALESCE(p_customer->>'name',  '')), '');
  v_phone   := NULLIF(TRIM(COALESCE(p_customer->>'phone', '')), '');
  v_consent := COALESCE((p_customer->>'consent_given')::BOOLEAN, false);

  IF v_name IS NULL THEN
    RETURN jsonb_build_object('ok', false, 'errors', jsonb_build_array(
      jsonb_build_object('code', 'missing_name',    'message', 'Укажите имя')));
  END IF;
  IF v_phone IS NULL THEN
    RETURN jsonb_build_object('ok', false, 'errors', jsonb_build_array(
      jsonb_build_object('code', 'missing_phone',   'message', 'Укажите телефон')));
  END IF;
  IF NOT v_consent THEN
    RETURN jsonb_build_object('ok', false, 'errors', jsonb_build_array(
      jsonb_build_object('code', 'missing_consent', 'message', 'Необходимо согласие на обработку данных')));
  END IF;

  -- ==========================================================================
  -- 2. Fulfillment. Type and method are required. Fee comes from the method.
  -- ==========================================================================
  v_fulfillment_type := NULLIF(TRIM(COALESCE(p_customer->>'fulfillment_type',     '')), '');
  v_pickup_store_id  := NULLIF(TRIM(COALESCE(p_customer->>'pickup_store_id',      '')), '');
  v_delivery_zone    := NULLIF(TRIM(COALESCE(p_customer->>'delivery_zone_code',   '')), '');
  v_delivery_address := NULLIF(TRIM(COALESCE(p_customer->>'delivery_address',     '')), '');

  IF v_fulfillment_type IS NULL OR v_fulfillment_type NOT IN ('pickup', 'delivery') THEN
    RETURN jsonb_build_object('ok', false, 'errors', jsonb_build_array(
      jsonb_build_object('code', 'invalid_fulfillment_type',
                         'message', 'Тип доставки должен быть pickup или delivery')));
  END IF;

  IF v_fulfillment_type = 'pickup' THEN
      IF v_pickup_store_id IS NULL THEN
        RETURN jsonb_build_object('ok', false, 'errors', jsonb_build_array(
          jsonb_build_object('code', 'missing_pickup_store_id',
                             'message', 'Выберите магазин для самовывоза')));
      END IF;
      IF v_delivery_zone IS NOT NULL THEN
        RETURN jsonb_build_object('ok', false, 'errors', jsonb_build_array(
          jsonb_build_object('code', 'invalid_pickup_zone',
                             'message', 'Зона доставки не задаётся при самовывозе')));
      END IF;
      IF v_delivery_address IS NOT NULL THEN
        RETURN jsonb_build_object('ok', false, 'errors', jsonb_build_array(
          jsonb_build_object('code', 'invalid_pickup_address',
                             'message', 'Адрес доставки не задаётся при самовывозе')));
      END IF;
    END IF;

    IF v_fulfillment_type = 'delivery' THEN
      IF v_delivery_zone IS NULL THEN
        RETURN jsonb_build_object('ok', false, 'errors', jsonb_build_array(
          jsonb_build_object('code', 'missing_delivery_zone',
                             'message', 'Укажите зону доставки')));
      END IF;
      IF v_delivery_zone NOT IN ('tiraspol', 'bender', 'express', 'moldova') THEN
        RETURN jsonb_build_object('ok', false, 'errors', jsonb_build_array(
          jsonb_build_object('code', 'invalid_delivery_zone',
                             'message', 'Неверная зона доставки')));
      END IF;
      IF v_delivery_address IS NULL THEN
        RETURN jsonb_build_object('ok', false, 'errors', jsonb_build_array(
          jsonb_build_object('code', 'missing_delivery_address',
                             'message', 'Укажите адрес доставки')));
      END IF;
      IF v_pickup_store_id IS NOT NULL THEN
        RETURN jsonb_build_object('ok', false, 'errors', jsonb_build_array(
          jsonb_build_object('code', 'invalid_delivery_store',
                             'message', 'Магазин самовывоза не задаётся при доставке')));
        END IF;
    END IF;

  -- ==========================================================================
  -- 3. Method code, fee, payment code (same rules as submit_order_v2).
  -- ==========================================================================
  v_fulfillment_method_code := NULLIF(TRIM(COALESCE(p_customer->>'fulfillment_method_code', '')), '');
  v_payment_method_code     := NULLIF(TRIM(COALESCE(p_customer->>'payment_method_code',     '')), '');

  IF p_customer ? 'fulfillment_fee'
     AND p_customer->>'fulfillment_fee' IS NOT NULL
     AND TRIM(p_customer->>'fulfillment_fee') <> '' THEN
    BEGIN
      v_fulfillment_fee_in := (p_customer->>'fulfillment_fee')::DOUBLE PRECISION;
    EXCEPTION WHEN others THEN
      RETURN jsonb_build_object('ok', false, 'errors', jsonb_build_array(
        jsonb_build_object('code', 'invalid_fulfillment_fee',
                           'message', 'fulfillment_fee должен быть числом')));
    END;
  END IF;

  IF v_fulfillment_method_code IS NULL
     OR v_fulfillment_method_code NOT IN (
       'pickup_store', 'courier_tiraspol', 'courier_bender',
       'express_post', 'moldova_post'
     ) THEN
    RETURN jsonb_build_object('ok', false, 'errors', jsonb_build_array(
      jsonb_build_object('code', 'invalid_fulfillment_method_code',
                         'message', 'Неверный fulfillment_method_code')));
  END IF;

  IF v_payment_method_code IS NOT NULL
     AND v_payment_method_code NOT IN (
       'cash', 'mobile_payment', 'bank_transfer', 'clever_installment'
     ) THEN
    RETURN jsonb_build_object('ok', false, 'errors', jsonb_build_array(
      jsonb_build_object('code', 'invalid_payment_method_code',
                         'message', 'Неверный payment_method_code')));
  END IF;

  IF v_fulfillment_fee_in IS NOT NULL AND v_fulfillment_fee_in < 0 THEN
    RETURN jsonb_build_object('ok', false, 'errors', jsonb_build_array(
      jsonb_build_object('code', 'invalid_fulfillment_fee',
                         'message', 'fulfillment_fee должен быть >= 0')));
  END IF;

  IF v_fulfillment_type IS NOT NULL AND v_fulfillment_method_code IS NOT NULL THEN
    IF v_fulfillment_type = 'pickup' AND v_fulfillment_method_code <> 'pickup_store' THEN
      RETURN jsonb_build_object('ok', false, 'errors', jsonb_build_array(
        jsonb_build_object('code', 'invalid_fulfillment_method_code',
                           'message', 'fulfillment_method_code должен быть pickup_store при самовывозе')));
    END IF;
    IF v_fulfillment_type = 'delivery' AND v_fulfillment_method_code NOT IN (
        'courier_tiraspol', 'courier_bender', 'express_post', 'moldova_post'
       ) THEN
      RETURN jsonb_build_object('ok', false, 'errors', jsonb_build_array(
        jsonb_build_object('code', 'invalid_fulfillment_method_code',
                           'message', 'fulfillment_method_code не подходит для доставки')));
    END IF;
  END IF;

  -- Known methods use the same CASE as quote_order_v1 / submit_order_v2.
  -- A supplied fee may only repeat that amount. Omitted fee is filled in.
  IF v_fulfillment_method_code IS NOT NULL THEN
    v_expected_fee := CASE v_fulfillment_method_code
      WHEN 'pickup_store'     THEN 0
      WHEN 'courier_tiraspol' THEN 50
      WHEN 'courier_bender'   THEN 40
      WHEN 'express_post'     THEN 40
      WHEN 'moldova_post'     THEN 30
      ELSE NULL
    END;
    IF v_expected_fee IS NOT NULL THEN
      IF v_fulfillment_fee_in IS NOT NULL
         AND round(v_fulfillment_fee_in::numeric, 2) IS DISTINCT FROM v_expected_fee THEN
        RETURN jsonb_build_object('ok', false, 'errors', jsonb_build_array(
          jsonb_build_object(
            'code', 'fulfillment_fee_mismatch',
            'message', 'Стоимость доставки не совпадает с выбранным способом'
          )));
      END IF;
      v_fulfillment_fee_in := v_expected_fee::double precision;
    END IF;
  END IF;

  -- ==========================================================================
  -- 4. Price the order through quote_order_v1 (single source of truth).
  --    Pass through promo + method so the quoter applies the same fee.
  -- ==========================================================================
  v_promo_code_in := NULLIF(TRIM(COALESCE(p_customer->>'promo_code', '')), '');

  v_quote := public.quote_order_v1(
    p_customer,
    p_items
  );

  IF (v_quote->>'ok')::BOOLEAN IS NOT TRUE THEN
    -- Forward the quoter's structured errors verbatim.
    RETURN jsonb_build_object(
      'ok',     false,
      'errors', COALESCE(v_quote->'errors', '[]'::jsonb)
    );
  END IF;

  -- ==========================================================================
  -- 5. Promo hard-fail gate.
  --    If the caller supplied a code and the quoter classified it as a
  --    user-actionable failure, reject the order so the caller can re-quote.
  --    'applied' and 'not_best_discount' both pass (the latter means the
  --    user gets a better automatic deal than their code).
  -- ==========================================================================
  v_promo        := v_quote->'promo';
  v_promo_status := v_promo->>'status';

  IF v_promo_code_in IS NOT NULL AND v_promo_status NOT IN ('applied', 'not_best_discount') THEN
    RETURN jsonb_build_object(
      'ok',     false,
      'promo',  v_promo,
      'errors', jsonb_build_array(jsonb_build_object(
        'code',    'promo_' || v_promo_status,
        'message', COALESCE(v_promo->>'message', 'Промокод не применён')
      ))
    );
  END IF;

  -- ==========================================================================
  -- 6. Extract pricing scalars + collections from the quote.
  -- ==========================================================================
  v_subtotal          := (v_quote->>'subtotal_amount')::NUMERIC(12,2);
  v_discount          := (v_quote->>'discount_amount')::NUMERIC(12,2);
  v_fee               := (v_quote->>'fulfillment_fee')::NUMERIC(12,2);
  v_grand_total       := (v_quote->>'grand_total_amount')::NUMERIC(12,2);
  v_applied_discounts := COALESCE(v_quote->'applied_discounts', '[]'::jsonb);
  v_lines             := COALESCE(v_quote->'lines', '[]'::jsonb);

  SELECT
    COUNT(*)::int,
    COALESCE(SUM((l->>'quantity')::int), 0)::int
  INTO v_total_items, v_total_quantity
  FROM jsonb_array_elements(v_lines) l;

  -- Canonical applied promocode code (from the matched campaign), not the
  -- raw user input. Stored in order_requests.applied_promocode_code so
  -- analytics can group by canonical code.
  SELECT a->>'code'
  INTO v_applied_promo_code
  FROM jsonb_array_elements(v_applied_discounts) a
  WHERE (a->>'kind') = 'promocode'
  LIMIT 1;

  -- ==========================================================================
  -- 7. Lock applied campaigns and re-validate. Prevents:
  --    - lost-update on used_count under concurrency
  --    - applying a campaign that became inactive/expired/at-cap/min-raised
  --      between quote and submit.
  -- ==========================================================================
  SELECT array_agg(DISTINCT (a->>'campaign_id')::uuid)
  INTO v_applied_ids
  FROM jsonb_array_elements(v_applied_discounts) a
  WHERE COALESCE((a->>'discount_amount')::NUMERIC(12,2), 0) > 0;

  IF v_applied_ids IS NOT NULL AND array_length(v_applied_ids, 1) > 0 THEN
    PERFORM 1
    FROM public.discount_campaigns
    WHERE id = ANY(v_applied_ids)
    FOR UPDATE;

    SELECT id
    INTO v_invalid_campaign_id
    FROM public.discount_campaigns
    WHERE id = ANY(v_applied_ids)
      AND (
        is_active = false
        OR (starts_at IS NOT NULL AND starts_at >  now())
        OR (ends_at   IS NOT NULL AND ends_at   <= now())
        OR (max_redemptions IS NOT NULL AND used_count >= max_redemptions)
        OR (min_order_amount > v_subtotal)
      )
    LIMIT 1;

    IF v_invalid_campaign_id IS NOT NULL THEN
      RETURN jsonb_build_object(
        'ok',     false,
        'errors', jsonb_build_array(jsonb_build_object(
          'code',         'quote_changed_or_discount_unavailable',
          'message',      'Скидки изменились с момента расчёта. Повторите расчёт.',
          'campaign_id',  v_invalid_campaign_id
        ))
      );
    END IF;
  END IF;

  -- ==========================================================================
  -- 8. Insert order_requests header. Mirrors submit_order_v2 column-for-column
  --    for the v2 columns; populates Phase 1 snapshot columns additively.
  --    total_price keeps v2 meaning (= subtotal).
  -- ==========================================================================
  v_email                 := NULLIF(TRIM(COALESCE(p_customer->>'email',           '')), '');
  v_loyalty_card          := NULLIF(TRIM(COALESCE(p_customer->>'loyalty_card',    '')), '');
  v_comment               := NULLIF(TRIM(COALESCE(p_customer->>'comment',         '')), '');
  v_legacy_delivery_method:= NULLIF(TRIM(COALESCE(p_customer->>'delivery_method', '')), '');
  v_legacy_payment_method := NULLIF(TRIM(COALESCE(p_customer->>'payment_method',  '')), '');
  v_source                := COALESCE(NULLIF(TRIM(COALESCE(p_customer->>'source','')), ''), 'mobile_app');

  -- Owner comes from the session. A client user_id may only repeat auth.uid().
  -- Guests cannot attach an order to any Auth user.
  IF auth.uid() IS NOT NULL THEN
    IF p_customer ? 'user_id'
       AND NULLIF(btrim(p_customer->>'user_id'), '') IS NOT NULL THEN
      BEGIN
        IF btrim(p_customer->>'user_id')::uuid IS DISTINCT FROM auth.uid() THEN
          RETURN jsonb_build_object('ok', false, 'errors', jsonb_build_array(
            jsonb_build_object(
              'code', 'user_id_mismatch',
              'message', 'Нельзя оформить заказ от имени другого пользователя'
            )));
        END IF;
      EXCEPTION WHEN invalid_text_representation THEN
        RETURN jsonb_build_object('ok', false, 'errors', jsonb_build_array(
          jsonb_build_object(
            'code', 'user_id_mismatch',
            'message', 'Нельзя оформить заказ от имени другого пользователя'
          )));
      END;
    END IF;
    v_user_id := auth.uid();
  ELSE
    IF p_customer ? 'user_id'
       AND NULLIF(btrim(p_customer->>'user_id'), '') IS NOT NULL THEN
      RETURN jsonb_build_object('ok', false, 'errors', jsonb_build_array(
        jsonb_build_object(
          'code', 'user_id_not_allowed',
          'message', 'Гостевой заказ нельзя привязать к аккаунту'
        )));
    END IF;
    v_user_id := NULL;
  END IF;

  INSERT INTO public.order_requests (
    customer_name,
    phone,
    email,
    delivery_method,
    delivery_address,
    payment_method,
    promo_code,
    loyalty_card,
    comment,
    consent_given,
    total_items,
    total_quantity,
    total_price,
    status,
    source,
    user_id,
    fulfillment_type,
    pickup_store_id,
    delivery_zone_code,
    fulfillment_method_code,
    fulfillment_fee,
    payment_method_code,
    -- Phase 1 snapshot columns (additive; do not change v2 meanings above):
    subtotal_amount,
    discount_amount,
    grand_total_amount,
    applied_promocode_code,
    applied_discount_snapshot,
    pricing_version,
    pricing_metadata
  )
  VALUES (
    v_name,
    v_phone,
    v_email,
    v_legacy_delivery_method,
    v_delivery_address,
    v_legacy_payment_method,
    v_promo_code_in,
    v_loyalty_card,
    v_comment,
    v_consent,
    v_total_items,
    v_total_quantity,
    v_subtotal,                 -- v2 contract: subtotal goes here
    'new',
    v_source,
    v_user_id,
    v_fulfillment_type,
    v_pickup_store_id,
    v_delivery_zone,
    v_fulfillment_method_code,
    v_fulfillment_fee_in,
    v_payment_method_code,
    v_subtotal,
    v_discount,
    v_grand_total,
    v_applied_promo_code,
    v_applied_discounts,
    'discount_v1',
    jsonb_build_object(
      'promo',          v_promo,
      'fulfillment_fee', v_fee
    )
  )
  RETURNING id INTO v_request_id;

  -- ==========================================================================
  -- 9. Insert order_request_items. Re-join catalog_items by canonical
  --    variant_id for fields not carried by the quote (image_url, old_price,
  --    edition/modification, is_active). product_id cast to uuid (production
  --    column type), per the 20260430190000 hotfix pattern.
  -- ==========================================================================
  INSERT INTO public.order_request_items (
    request_id,
    variant_id,
    product_id,
    title,
    brand,
    image_url,
    price,
    old_price,
    quantity,
    line_total,
    edition,
    modification,
    is_active,
    -- Phase 1 snapshot columns (additive):
    unit_price_amount,
    line_subtotal_amount,
    line_discount_amount,
    line_total_amount,
    applied_discount_snapshot
  )
  SELECT
    v_request_id,
    ql->>'variant_id',
    c.product_id::uuid,
    c.title,
    c.brand,
    c.photo,
    (ql->>'unit_price')::numeric(12,2),
    c.old_price,
    (ql->>'quantity')::INT,
    (ql->>'line_subtotal_amount')::DOUBLE PRECISION,  -- v2 contract: pre-discount
    c.editions,
    c.modifications,
    c.is_active,
    (ql->>'unit_price')::NUMERIC(12,2),
    (ql->>'line_subtotal_amount')::NUMERIC(12,2),
    (ql->>'line_discount_amount')::NUMERIC(12,2),
    (ql->>'line_total_amount')::NUMERIC(12,2),
    CASE
      WHEN jsonb_typeof(ql->'applied_discount') = 'object'
        THEN jsonb_build_array(ql->'applied_discount')
      ELSE '[]'::jsonb
    END
  FROM jsonb_array_elements(v_lines) ql
  JOIN public.catalog_items c ON c.variant_id = ql->>'variant_id';

  -- ==========================================================================
  -- 10. Discount redemptions + used_count increment (atomic with the order
  --     insert because we're inside a single function call / transaction).
  --     Both happen ONLY for campaigns that actually contributed a discount.
  -- ==========================================================================
  IF v_applied_ids IS NOT NULL AND array_length(v_applied_ids, 1) > 0 THEN
    INSERT INTO public.discount_redemptions (
      campaign_id,
      order_request_id,
      user_id,
      customer_phone,
      code,
      subtotal_amount,
      discount_amount,
      metadata
    )
    SELECT
      (a->>'campaign_id')::uuid,
      v_request_id,
      v_user_id,
      v_phone,
      a->>'code',
      v_subtotal,
      (a->>'discount_amount')::NUMERIC(12,2),
      jsonb_build_object(
        'kind',        a->>'kind',
        'name',        a->>'name',
        'percent_off', a->>'percent_off'
      )
    FROM jsonb_array_elements(v_applied_discounts) a
    WHERE COALESCE((a->>'discount_amount')::NUMERIC(12,2), 0) > 0;

    UPDATE public.discount_campaigns
    SET used_count = used_count + 1
    WHERE id = ANY(v_applied_ids);
  END IF;

  -- ==========================================================================
  -- 11. Result. Snake-case keys throughout to match current Flutter parser
  --     (cart_repository_impl.dart reads order_id/total_items/total_quantity/
  --     total_price). Phase 1/2 fields appended additively.
  -- ==========================================================================
  RETURN jsonb_build_object(
    'ok',                  true,
    'order_id',            v_request_id,
    'total_items',         v_total_items,
    'total_quantity',      v_total_quantity,
    'total_price',         v_subtotal,            -- v2 contract: subtotal
    'subtotal_amount',     v_subtotal,
    'discount_amount',     v_discount,
    'fulfillment_fee',     v_fee,
    'grand_total_amount',  v_grand_total,
    'pricing_version',     'discount_v1',
    'promo',               v_promo,
    'applied_discounts',   v_applied_discounts,
    'lines',               v_lines
  );
END;
$$;

CREATE OR REPLACE FUNCTION public.submit_order_v2(
  p_customer JSONB,
  p_items    JSONB
)
RETURNS JSONB
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public, pg_temp
AS $$
DECLARE
  v_name                    TEXT;
  v_phone                   TEXT;
  v_consent                 BOOLEAN;
  v_fulfillment_type        TEXT;
  v_pickup_store_id         TEXT;
  v_delivery_zone           TEXT;
  v_delivery_address        TEXT;
  v_fulfillment_method_code TEXT;
  v_fulfillment_fee         DOUBLE PRECISION;
  v_payment_method_code     TEXT;
  v_expected_fee            DOUBLE PRECISION;
  v_request_id              UUID;
  v_total_items             INT;
  v_total_qty               INT;
  v_total_price             DOUBLE PRECISION;
  v_bad                     TEXT[];
  v_merged                  JSONB;
  v_user_id                 UUID;
BEGIN
  -- 1. Validate core customer fields ----------------------------------------
  v_name := NULLIF(TRIM(COALESCE(p_customer->>'name', '')), '');
  IF v_name IS NULL THEN
    RAISE EXCEPTION 'name is required';
  END IF;

  v_phone := NULLIF(TRIM(COALESCE(p_customer->>'phone', '')), '');
  IF v_phone IS NULL THEN
    RAISE EXCEPTION 'phone is required';
  END IF;

  v_consent := COALESCE((p_customer->>'consent_given')::BOOLEAN, false);
  IF NOT v_consent THEN
    RAISE EXCEPTION 'consent_given must be true';
  END IF;

  -- 1b. Fulfillment fields ---------------------------------------------------
  v_fulfillment_type := NULLIF(TRIM(COALESCE(p_customer->>'fulfillment_type', '')), '');
  v_pickup_store_id  := NULLIF(TRIM(COALESCE(p_customer->>'pickup_store_id', '')), '');
  v_delivery_zone    := NULLIF(TRIM(COALESCE(p_customer->>'delivery_zone_code', '')), '');
  v_delivery_address := NULLIF(TRIM(COALESCE(p_customer->>'delivery_address', '')), '');

  IF v_fulfillment_type IS NULL THEN
    RAISE EXCEPTION 'fulfillment_type is required';
  END IF;

  IF v_fulfillment_type IS NOT NULL THEN
    IF v_fulfillment_type NOT IN ('pickup', 'delivery') THEN
      RAISE EXCEPTION 'fulfillment_type must be pickup or delivery, got: %', v_fulfillment_type;
    END IF;

    IF v_fulfillment_type = 'pickup' THEN
      IF v_pickup_store_id IS NULL THEN
        RAISE EXCEPTION 'pickup_store_id is required when fulfillment_type = pickup';
      END IF;
      IF v_delivery_zone IS NOT NULL THEN
        RAISE EXCEPTION 'delivery_zone_code must be empty for pickup orders';
      END IF;
      IF v_delivery_address IS NOT NULL THEN
        RAISE EXCEPTION 'delivery_address must be empty for pickup orders';
      END IF;
    END IF;

    IF v_fulfillment_type = 'delivery' THEN
      IF v_delivery_zone IS NULL THEN
        RAISE EXCEPTION 'delivery_zone_code is required when fulfillment_type = delivery';
      END IF;
      IF v_delivery_zone NOT IN ('tiraspol', 'bender', 'express', 'moldova') THEN
        RAISE EXCEPTION 'invalid delivery_zone_code: %', v_delivery_zone;
      END IF;
      IF v_delivery_address IS NULL THEN
        RAISE EXCEPTION 'delivery_address is required when fulfillment_type = delivery';
      END IF;
      IF v_pickup_store_id IS NOT NULL THEN
        RAISE EXCEPTION 'pickup_store_id must be empty for delivery orders';
      END IF;
    END IF;
  END IF;

  -- 1c. Method code, fee, payment code --------------------------------------
  v_fulfillment_method_code := NULLIF(TRIM(COALESCE(
    p_customer->>'fulfillment_method_code', '')), '');
  v_payment_method_code := NULLIF(TRIM(COALESCE(
    p_customer->>'payment_method_code', '')), '');

  IF p_customer->>'fulfillment_fee' IS NOT NULL THEN
    BEGIN
      v_fulfillment_fee := (p_customer->>'fulfillment_fee')::DOUBLE PRECISION;
    EXCEPTION WHEN others THEN
      RAISE EXCEPTION 'fulfillment_fee must be a number';
    END;
  END IF;

  IF v_fulfillment_method_code IS NULL THEN
    RAISE EXCEPTION 'fulfillment_method_code is required';
  END IF;

  IF v_fulfillment_method_code NOT IN (
    'pickup_store', 'courier_tiraspol', 'courier_bender',
    'express_post', 'moldova_post'
  ) THEN
    RAISE EXCEPTION 'invalid fulfillment_method_code: %', v_fulfillment_method_code;
  END IF;

  IF v_payment_method_code IS NOT NULL THEN
    IF v_payment_method_code NOT IN (
      'cash', 'mobile_payment', 'bank_transfer', 'clever_installment'
    ) THEN
      RAISE EXCEPTION 'invalid payment_method_code: %', v_payment_method_code;
    END IF;
  END IF;

  IF v_fulfillment_fee IS NOT NULL AND v_fulfillment_fee < 0 THEN
    RAISE EXCEPTION 'fulfillment_fee must be >= 0, got: %', v_fulfillment_fee;
  END IF;

  IF v_fulfillment_type IS NOT NULL AND v_fulfillment_method_code IS NOT NULL THEN
    IF v_fulfillment_type = 'pickup' AND v_fulfillment_method_code <> 'pickup_store' THEN
      RAISE EXCEPTION 'fulfillment_method_code must be pickup_store for pickup orders, got: %',
        v_fulfillment_method_code;
    END IF;
    IF v_fulfillment_type = 'delivery' AND v_fulfillment_method_code NOT IN (
      'courier_tiraspol', 'courier_bender', 'express_post', 'moldova_post'
    ) THEN
      RAISE EXCEPTION 'fulfillment_method_code invalid for delivery: %',
        v_fulfillment_method_code;
    END IF;
  END IF;

  IF v_fulfillment_method_code IS NOT NULL THEN
    v_expected_fee := CASE v_fulfillment_method_code
      WHEN 'pickup_store'     THEN 0
      WHEN 'courier_tiraspol' THEN 50
      WHEN 'courier_bender'   THEN 40
      WHEN 'express_post'     THEN 40
      WHEN 'moldova_post'     THEN 30
      ELSE NULL
    END;
    IF v_expected_fee IS NOT NULL THEN
      IF v_fulfillment_fee IS NOT NULL
         AND round(v_fulfillment_fee::numeric, 2) IS DISTINCT FROM v_expected_fee::numeric(12,2) THEN
        RAISE EXCEPTION 'fulfillment_fee_mismatch';
      END IF;
      v_fulfillment_fee := v_expected_fee;
    END IF;
  END IF;

  -- 2. Validate items array --------------------------------------------------
  IF p_items IS NULL OR jsonb_array_length(p_items) = 0 THEN
    RAISE EXCEPTION 'items cannot be empty';
  END IF;

  -- 3. Merge duplicate variant_ids, sum quantities --------------------------
  SELECT jsonb_agg(
    jsonb_build_object('variant_id', sub.vid, 'quantity', sub.qty)
  )
  INTO v_merged
  FROM (
    SELECT
      item->>'variant_id'          AS vid,
      SUM((item->>'quantity')::INT) AS qty
    FROM jsonb_array_elements(p_items) AS item
    GROUP BY item->>'variant_id'
  ) sub;

  -- 4. Validate individual quantities ---------------------------------------
  SELECT array_agg(item->>'variant_id')
  INTO v_bad
  FROM jsonb_array_elements(v_merged) AS item
  WHERE (item->>'quantity')::INT < 1;

  IF v_bad IS NOT NULL AND array_length(v_bad, 1) > 0 THEN
    RAISE EXCEPTION 'Invalid quantity for variants: %', array_to_string(v_bad, ', ');
  END IF;

  -- 5. Resolve catalog data into temp table ---------------------------------
  --
  -- product_id is cast to UUID at this boundary so that all downstream
  -- consumers (the WHERE product_id IS NULL validation in step 6, and the
  -- INSERT into order_request_items in step 11) see the canonical UUID
  -- type that order_request_items.product_id holds in production. The
  -- source value is `p.id::text` from the catalog_items VIEW, which is
  -- always a syntactically valid UUID since `products.id` is a uuid PK.
  --
  -- variant_id stays TEXT because the canonical contract is text and
  -- order_request_items.variant_id is text.
  --
  -- Back-compat resolution (preserved from 20260430180000):
  --   The LEFT JOIN matches the input variant_id against either the
  --   canonical `c.variant_id` or the legacy `c.legacy_variant_uuid`
  --   (cached carts that hold pv.id::text from the pre-fix view).
  --   `_order_lines.variant_id` is normalized to the canonical value
  --   via COALESCE so order_request_items always stores the canonical id.
  CREATE TEMP TABLE _order_lines ON COMMIT DROP AS
  SELECT
    COALESCE(c.variant_id, m.vid)        AS variant_id,
    m.qty                                AS quantity,
    c.product_id::uuid                   AS product_id,
    c.title,
    c.brand,
    c.photo                              AS image_url,
    c.price,
    c.old_price,
    c.is_active,
    c.editions                           AS edition,
    c.modifications                      AS modification,
    ROUND(COALESCE(c.price, 0) * m.qty, 2)::double precision AS line_total
  FROM (
    SELECT
      item->>'variant_id'           AS vid,
      (item->>'quantity')::INT      AS qty
    FROM jsonb_array_elements(v_merged) AS item
  ) m
  LEFT JOIN public.catalog_items c
    ON c.variant_id          = m.vid
    OR c.legacy_variant_uuid = m.vid;

  -- 6. Validate: all variants found -----------------------------------------
  SELECT array_agg(variant_id)
  INTO v_bad
  FROM _order_lines
  WHERE product_id IS NULL;

  IF v_bad IS NOT NULL AND array_length(v_bad, 1) > 0 THEN
    RAISE EXCEPTION 'Variants not found: %', array_to_string(v_bad, ', ');
  END IF;

  -- 7. Validate: all variants active ----------------------------------------
  SELECT array_agg(variant_id)
  INTO v_bad
  FROM _order_lines
  WHERE is_active = false;

  IF v_bad IS NOT NULL AND array_length(v_bad, 1) > 0 THEN
    RAISE EXCEPTION 'Inactive variants: %', array_to_string(v_bad, ', ');
  END IF;

  -- 8. Validate: all prices present -----------------------------------------
  SELECT array_agg(variant_id)
  INTO v_bad
  FROM _order_lines
  WHERE price IS NULL;

  IF v_bad IS NOT NULL AND array_length(v_bad, 1) > 0 THEN
    RAISE EXCEPTION 'No price for variants: %', array_to_string(v_bad, ', ');
  END IF;

  -- 9. Compute totals -------------------------------------------------------
  SELECT
    COUNT(*)::INT,
    SUM(quantity)::INT,
    SUM(line_total)
  INTO v_total_items, v_total_qty, v_total_price
  FROM _order_lines;

  -- Same identity rule as submit_order_v3. v2 reports it as an exception.
  IF auth.uid() IS NOT NULL THEN
    IF p_customer ? 'user_id'
       AND NULLIF(btrim(p_customer->>'user_id'), '') IS NOT NULL THEN
      BEGIN
        IF btrim(p_customer->>'user_id')::uuid IS DISTINCT FROM auth.uid() THEN
          RAISE EXCEPTION 'user_id_mismatch';
        END IF;
      EXCEPTION
        WHEN invalid_text_representation THEN
          RAISE EXCEPTION 'user_id_mismatch';
      END;
    END IF;
    v_user_id := auth.uid();
  ELSE
    IF p_customer ? 'user_id'
       AND NULLIF(btrim(p_customer->>'user_id'), '') IS NOT NULL THEN
      RAISE EXCEPTION 'user_id_not_allowed';
    END IF;
    v_user_id := NULL;
  END IF;

  -- 10. Insert order header -------------------------------------------------
  INSERT INTO order_requests (
    customer_name,
    phone,
    email,
    delivery_method,
    delivery_address,
    payment_method,
    promo_code,
    loyalty_card,
    comment,
    consent_given,
    total_items,
    total_quantity,
    total_price,
    status,
    source,
    user_id,
    fulfillment_type,
    pickup_store_id,
    delivery_zone_code,
    fulfillment_method_code,
    fulfillment_fee,
    payment_method_code
  )
  VALUES (
    v_name,
    v_phone,
    NULLIF(TRIM(COALESCE(p_customer->>'email', '')), ''),
    NULLIF(TRIM(COALESCE(p_customer->>'delivery_method', '')), ''),
    v_delivery_address,
    NULLIF(TRIM(COALESCE(p_customer->>'payment_method', '')), ''),
    NULLIF(TRIM(COALESCE(p_customer->>'promo_code', '')), ''),
    NULLIF(TRIM(COALESCE(p_customer->>'loyalty_card', '')), ''),
    NULLIF(TRIM(COALESCE(p_customer->>'comment', '')), ''),
    v_consent,
    v_total_items,
    v_total_qty,
    v_total_price,
    'new',
    COALESCE(NULLIF(TRIM(COALESCE(p_customer->>'source', '')), ''), 'mobile_app'),
    v_user_id,
    v_fulfillment_type,
    v_pickup_store_id,
    v_delivery_zone,
    v_fulfillment_method_code,
    v_fulfillment_fee,
    v_payment_method_code
  )
  RETURNING id INTO v_request_id;

  -- 11. Insert order line items (server-resolved snapshots) -----------------
  INSERT INTO order_request_items (
    request_id,
    variant_id,
    product_id,
    title,
    brand,
    image_url,
    price,
    old_price,
    quantity,
    line_total,
    edition,
    modification,
    is_active
  )
  SELECT
    v_request_id,
    ol.variant_id,
    ol.product_id,
    ol.title,
    ol.brand,
    ol.image_url,
    ol.price,
    ol.old_price,
    ol.quantity,
    ol.line_total,
    ol.edition,
    ol.modification,
    ol.is_active
  FROM _order_lines ol;

  -- 12. Return result -------------------------------------------------------
  RETURN jsonb_build_object(
    'order_id',       v_request_id,
    'total_items',    v_total_items,
    'total_quantity', v_total_qty,
    'total_price',    v_total_price
  );
END;
$$;

-- submit_consultation_v1(p_payload JSONB)
--
-- Single write path for consultation requests. Mirrors the order flow:
--   * SECURITY DEFINER so guest clients (anon) can insert
--   * validates minimal fields server-side (name, phone)
--   * phone pattern aligned with the existing Flutter checkout validator
--     (RegExp(r'^[\d\s\+\-\(\)]{7,20}$'))
--   * source defaults to 'mobile_app', overridable via payload
--   * user_id resolved from auth.uid() when present; ignored from payload
--     to prevent spoofing by unauthenticated callers
--   * returns compact JSON: { consultation_id, created_at, status }

CREATE OR REPLACE FUNCTION public.submit_consultation_v1(
  p_payload JSONB
)
RETURNS JSONB
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
  v_name       TEXT;
  v_phone      TEXT;
  v_source     TEXT;
  v_user_id    UUID;
  v_row        public.consultation_requests;
BEGIN
  IF p_payload IS NULL THEN
    RAISE EXCEPTION 'payload is required';
  END IF;

  -- -------------------------------------------------------------------------
  -- 1. Extract and validate required fields
  -- -------------------------------------------------------------------------
  v_name := NULLIF(btrim(COALESCE(p_payload->>'name', '')), '');
  IF v_name IS NULL THEN
    RAISE EXCEPTION 'name is required';
  END IF;
  IF length(v_name) > 200 THEN
    RAISE EXCEPTION 'name is too long';
  END IF;

  v_phone := NULLIF(btrim(COALESCE(p_payload->>'phone', '')), '');
  IF v_phone IS NULL THEN
    RAISE EXCEPTION 'phone is required';
  END IF;
  -- Aligned with client regex: [\d\s\+\-\(\)]{7,20}
  IF v_phone !~ '^[0-9\s\+\-\(\)]{7,20}$' THEN
    RAISE EXCEPTION 'phone format is invalid';
  END IF;

  -- -------------------------------------------------------------------------
  -- 2. Resolve source and user_id
  -- -------------------------------------------------------------------------
  v_source := NULLIF(btrim(COALESCE(p_payload->>'source', '')), '');
  IF v_source IS NULL THEN
    v_source := 'mobile_app';
  END IF;

  -- auth.uid() is authoritative; payload-provided user_id is intentionally
  -- ignored to avoid spoofing by unauthenticated callers.
  v_user_id := auth.uid();

  -- -------------------------------------------------------------------------
  -- 3. Insert and return summary
  -- -------------------------------------------------------------------------
  INSERT INTO public.consultation_requests (
    customer_name,
    phone,
    source,
    user_id
  )
  VALUES (
    v_name,
    v_phone,
    v_source,
    v_user_id
  )
  RETURNING * INTO v_row;

  RETURN jsonb_build_object(
    'consultation_id', v_row.id,
    'created_at',      v_row.created_at,
    'status',          v_row.status
  );
END;
$$;
