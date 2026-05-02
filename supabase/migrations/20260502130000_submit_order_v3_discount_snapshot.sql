-- ============================================================================
-- Phase 2 — submit_order_v3: discount-aware order submission RPC.
--
-- Scope (intentionally bounded):
--   1. New SECURITY DEFINER RPC public.submit_order_v3(p_customer, p_items)
--      that:
--        - validates customer/fulfillment fields (mirrors submit_order_v2),
--        - prices the order via public.quote_order_v1 (single source of truth),
--        - locks applied campaigns with FOR UPDATE and re-validates them,
--        - persists the order header into public.order_requests using the
--          same v2 columns AND the Phase 1 snapshot columns
--          (subtotal_amount/discount_amount/grand_total_amount/...),
--        - persists each line into public.order_request_items using the
--          existing v2 columns AND the Phase 1 per-line snapshot columns,
--        - inserts one public.discount_redemptions row per applied campaign,
--        - increments public.discount_campaigns.used_count by 1 per campaign,
--        - returns the v2-shaped result PLUS the Phase 1/2 snapshot fields.
--
-- What this migration explicitly does NOT do:
--   - It does NOT modify public.submit_order_v2.
--   - It does NOT modify public.catalog_items.
--   - It does NOT modify public.quote_order_v1.
--   - It does NOT modify Phase 1 tables / columns / RLS / triggers.
--   - It does NOT touch Flutter, Edge Functions, cron, or sync code.
--   - It does NOT enable cron / call any Edge Function.
--
-- Compatibility:
--   - submit_order_v2 stays callable byte-identical for existing Flutter.
--   - order_requests.total_price keeps the v2 meaning: items SUBTOTAL only
--     (Phase 1 snapshot columns hold the full discount/total breakdown).
--   - order_request_items.line_total keeps the v2 meaning: pre-discount
--     line total (= unit_price * quantity). Phase 1 snapshot columns hold
--     the post-discount line total.
--
-- Promo gate (deliberate UX decision):
--   When the caller supplies a non-empty promo_code AND quote_order_v1
--   returns a hard-fail status for it (not_found / inactive / expired /
--   limit_reached / min_order_not_met / no_matching_items), the order
--   is rejected with a corresponding 'promo_<status>' error code so the
--   caller can show a clear message and re-quote. 'applied' and
--   'not_best_discount' are accepted (the latter means the user got a
--   better automatic discount than the promo).
--
-- Non-applied + provided promo lock-time race:
--   Between the quote and the FOR UPDATE lock, a campaign may become
--   invalid (e.g. another concurrent submit consumed the last redemption
--   slot). Detected post-lock and returned as
--   'quote_changed_or_discount_unavailable'.
-- ============================================================================

BEGIN;

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
  -- 2. Fulfillment fields — same value-domain rules as submit_order_v2.
  --    All optional; NULL fulfillment_type means legacy / unspecified.
  -- ==========================================================================
  v_fulfillment_type := NULLIF(TRIM(COALESCE(p_customer->>'fulfillment_type',     '')), '');
  v_pickup_store_id  := NULLIF(TRIM(COALESCE(p_customer->>'pickup_store_id',      '')), '');
  v_delivery_zone    := NULLIF(TRIM(COALESCE(p_customer->>'delivery_zone_code',   '')), '');
  v_delivery_address := NULLIF(TRIM(COALESCE(p_customer->>'delivery_address',     '')), '');

  IF v_fulfillment_type IS NOT NULL THEN
    IF v_fulfillment_type NOT IN ('pickup', 'delivery') THEN
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

  IF v_fulfillment_method_code IS NOT NULL
     AND v_fulfillment_method_code NOT IN (
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

  -- ==========================================================================
  -- 4. Price the order through quote_order_v1 (single source of truth).
  --    Pass through promo + fee so the quoter sees the same input.
  -- ==========================================================================
  v_promo_code_in := NULLIF(TRIM(COALESCE(p_customer->>'promo_code', '')), '');

  v_quote := public.quote_order_v1(
    p_customer,
    p_items
  );

  IF (v_quote->>'ok')::BOOLEAN IS NOT TRUE THEN
    -- Forward the quoter's structured errors verbatim. quote_order_v1 only
    -- returns ok=false for cart-shape problems (empty/unknown/inactive/no_price).
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

  IF p_customer ? 'user_id' AND p_customer->>'user_id' IS NOT NULL
     AND TRIM(p_customer->>'user_id') <> '' THEN
    BEGIN
      v_user_id := (p_customer->>'user_id')::UUID;
    EXCEPTION WHEN others THEN
      v_user_id := NULL;
    END;
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
    (ql->>'unit_price')::DOUBLE PRECISION,
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

GRANT EXECUTE ON FUNCTION public.submit_order_v3(JSONB, JSONB)
  TO anon, authenticated;

COMMIT;
