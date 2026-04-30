-- ============================================================================
-- Hotfix: submit_order_v2 must cast catalog_items.product_id to uuid before
-- inserting into order_request_items.product_id (which is uuid in production).
--
-- Surfaced after 20260430180000_fix_catalog_items_variant_id_contract.sql.
--
-- Root cause:
--   The contract-fix migration restored canonical text variant_id resolution
--   in submit_order_v2, so the Section-5 LEFT JOIN finally produces matching
--   rows for Tilda numeric variant ids. The function then reaches Section 11
--   (INSERT INTO order_request_items) with `_order_lines.product_id` typed
--   as TEXT (it was selected as `c.product_id` from catalog_items, which is
--   `p.id::text`). Production `order_request_items.product_id` is UUID
--   (the bootstrap migration's intent of TEXT was a no-op because the table
--   pre-existed). Postgres rejects implicit text→uuid casts:
--
--       ERROR 42804: column "product_id" is of type uuid but expression
--                    is of type text
--
--   The previous v2 versions never hit this because variant resolution
--   always failed first ("Variants not found"), masking the type mismatch.
--
-- Fix scope (minimal):
--   Cast `c.product_id::uuid` once at the TEMP TABLE boundary so
--   `_order_lines.product_id` is uuid for every downstream consumer
--   (validation `WHERE product_id IS NULL` and the final INSERT). All other
--   semantics, validation messages, signature, and return shape are
--   preserved byte-identical to 20260430180000.
--
-- Other type mismatches audited and confirmed safe:
--   - variant_id      text → text                     OK
--   - title/brand/image_url/edition/modification text → text   OK
--   - price/old_price/line_total double precision → double precision OK
--   - quantity        int → int                       OK
--   - is_active       boolean → boolean               OK
--   - request_id      uuid → uuid (RETURNING)         OK
--   - product_id      text → uuid                     FIXED HERE
--
-- This migration touches submit_order_v2 only. No data, no view, no other
-- function, no Flutter, no schema, no cron, no catalog-sync.
-- ============================================================================

BEGIN;

CREATE OR REPLACE FUNCTION public.submit_order_v2(
  p_customer JSONB,
  p_items    JSONB
)
RETURNS JSONB
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
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

  IF v_fulfillment_method_code IS NOT NULL THEN
    IF v_fulfillment_method_code NOT IN (
      'pickup_store', 'courier_tiraspol', 'courier_bender',
      'express_post', 'moldova_post'
    ) THEN
      RAISE EXCEPTION 'invalid fulfillment_method_code: %', v_fulfillment_method_code;
    END IF;
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

  IF v_fulfillment_method_code IS NOT NULL AND v_fulfillment_fee IS NOT NULL THEN
    v_expected_fee := CASE v_fulfillment_method_code
      WHEN 'pickup_store'      THEN 0
      WHEN 'courier_tiraspol'  THEN 50
      WHEN 'courier_bender'    THEN 40
      WHEN 'express_post'      THEN 40
      WHEN 'moldova_post'      THEN 30
      ELSE NULL
    END;
    IF v_expected_fee IS NOT NULL AND v_fulfillment_fee <> v_expected_fee THEN
      RAISE NOTICE 'fulfillment_fee % does not match expected % for method %',
        v_fulfillment_fee, v_expected_fee, v_fulfillment_method_code;
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
    COALESCE(c.price, 0) * m.qty         AS line_total
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
    (p_customer->>'user_id')::UUID,
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

COMMIT;
