-- ============================================================================
-- Fix: catalog_items VIEW must expose the canonical variant_id contract.
--
-- Root cause (production evidence):
--   The production `catalog_items` VIEW was created outside the migration
--   pipeline (before 20260411140000_ensure_catalog_items_view.sql), and it
--   selects the UUID primary key instead of the TEXT variant_id column:
--
--       SELECT pv.id AS variant_id     -- WRONG: uuid, not text
--
--   The 20260411140000 migration is guarded by `IF NOT EXISTS` so it was
--   a no-op on production. After the Tilda refill (run_id
--   999e72cd-0634-4d87-8b55-65849e1d8655) the base table
--   `product_variants.variant_id` correctly holds Tilda numeric offer UIDs
--   (e.g. '184192311111'), but the VIEW still exposes the UUID PK, which
--   breaks:
--     - Flutter catalog queries by variant_id (they pass Tilda numeric
--       strings that never match UUIDs),
--     - `submit_order_v2` item resolution (`LEFT JOIN catalog_items c
--       ON c.variant_id::text = m.vid::text` yields zero hits),
--     - the canonical contract documented in the sync engine and DTOs.
--
-- This migration recreates the VIEW with the canonical contract and adds
-- a `legacy_variant_uuid` column so in-flight clients with cart items
-- cached under the old UUID-shaped variant_id can still submit orders.
--
-- Safety boundaries (enforced by what this migration does NOT do):
--   - No mutation of `products`, `product_variants`, `product_images`,
--     `order_requests`, `order_request_items`.
--   - No change to Flutter DTO.
--   - No change to catalog-sync behavior.
--   - No cron reactivation.
--   - No deactivation of any product/variant.
--
-- Idempotency:
--   The `DROP … IF EXISTS` + `CREATE OR REPLACE` pattern makes every step
--   repeatable without error on a clean or already-fixed schema.
-- ============================================================================

BEGIN;

-- ----------------------------------------------------------------------------
-- 1. Drop functions that depend on the VIEW's columns.
--    SQL-language functions record pg_depend entries on referenced columns,
--    which would block DROP VIEW otherwise. We recreate them verbatim below.
-- ----------------------------------------------------------------------------
DROP FUNCTION IF EXISTS public.get_distinct_brands();
DROP FUNCTION IF EXISTS public.get_distinct_categories();
DROP FUNCTION IF EXISTS public.get_distinct_marks();

-- ----------------------------------------------------------------------------
-- 2. Drop the VIEW so we can change the type of its variant_id/product_id
--    columns. CREATE OR REPLACE VIEW cannot change existing column types.
-- ----------------------------------------------------------------------------
DROP VIEW IF EXISTS public.catalog_items;

-- ----------------------------------------------------------------------------
-- 3. Recreate the VIEW with the canonical contract.
--
--    Column contract (matches Flutter CatalogItemDto.fromMap):
--      variant_id           TEXT   — canonical stable id (Tilda offer UID
--                                     or gen_random_uuid() text for admin
--                                     rows); equal to product_variants.variant_id
--      product_id           TEXT   — product UUID cast to text
--      legacy_variant_uuid  TEXT   — product_variants.id cast to text
--                                     (see submit_order_v2 back-compat note)
--      external_id          TEXT   — Tilda external id
--      tilda_uid            TEXT   — Tilda product/group-level id
--      title, brand, category, mark, description, text
--      photo                TEXT   — variant photo or product photo fallback
--      is_active            BOOL   — product-level active flag
--      price, old_price, quantity, editions, modifications, attributes
-- ----------------------------------------------------------------------------
CREATE VIEW public.catalog_items AS
SELECT
  pv.variant_id::text                  AS variant_id,
  p.id::text                           AS product_id,
  pv.id::text                          AS legacy_variant_uuid,
  pv.external_id                       AS external_id,
  p.tilda_uid                          AS tilda_uid,
  p.title                              AS title,
  p.brand                              AS brand,
  p.category                           AS category,
  p.mark                               AS mark,
  p.description                        AS description,
  p.text                               AS text,
  COALESCE(pv.photo, p.photo)          AS photo,
  p.is_active                          AS is_active,
  pv.price                             AS price,
  pv.old_price                         AS old_price,
  pv.quantity                          AS quantity,
  pv.editions                          AS editions,
  pv.modifications                     AS modifications,
  pv.attributes                        AS attributes
FROM public.product_variants pv
JOIN public.products p ON p.id = pv.product_id;

-- Mobile app (anon) + authenticated users must keep SELECT access.
GRANT SELECT ON public.catalog_items TO anon, authenticated;

-- ----------------------------------------------------------------------------
-- 4. Recreate the view-dependent RPCs (verbatim contract).
--    Column-level deps are rebuilt against the new VIEW.
-- ----------------------------------------------------------------------------
CREATE OR REPLACE FUNCTION public.get_distinct_brands()
RETURNS SETOF TEXT
LANGUAGE sql
STABLE
SECURITY DEFINER
AS $$
  SELECT DISTINCT brand
  FROM public.catalog_items
  WHERE is_active = true
    AND brand IS NOT NULL
    AND brand <> ''
  ORDER BY brand;
$$;

CREATE OR REPLACE FUNCTION public.get_distinct_categories()
RETURNS SETOF TEXT
LANGUAGE sql
STABLE
SECURITY DEFINER
AS $$
  SELECT DISTINCT category
  FROM public.catalog_items
  WHERE is_active = true
    AND category IS NOT NULL
    AND category <> ''
  ORDER BY category;
$$;

CREATE OR REPLACE FUNCTION public.get_distinct_marks()
RETURNS SETOF TEXT
LANGUAGE sql
STABLE
SECURITY DEFINER
AS $$
  SELECT DISTINCT mark
  FROM public.catalog_items
  WHERE is_active = true
    AND mark IS NOT NULL
    AND mark <> ''
  ORDER BY mark;
$$;

-- ----------------------------------------------------------------------------
-- 5. Replace submit_order_v2 with the back-compatible resolution path.
--
--    Bodies are byte-identical to the 20260412150000 version EXCEPT:
--      - Section 5 JOIN now resolves against either the canonical
--        `variant_id` or the legacy `legacy_variant_uuid` (old cached carts
--        that held product_variants.id::text as their cart item id).
--      - _order_lines.variant_id is now the CANONICAL value coming from
--        the view — `COALESCE(c.variant_id, m.vid)` — so persisted order
--        rows always store the stable text contract. Legacy callers
--        continue to work; new callers are unaffected.
--
--    Everything else (fulfillment, method fee, payment code, validation
--    messages, inserts into order_requests / order_request_items) is
--    preserved verbatim. Function signature, return shape, and error
--    contract are unchanged.
-- ----------------------------------------------------------------------------
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
  -- Back-compat resolution:
  --   Clients built against the previous view schema stored the product
  --   variant UUID (pv.id::text) as their cart item id. Clients built
  --   against the fixed view schema store the canonical
  --   product_variants.variant_id. We accept either by matching on both
  --   axes; the persisted `variant_id` column is normalized to the
  --   canonical value so downstream systems see a single contract.
  CREATE TEMP TABLE _order_lines ON COMMIT DROP AS
  SELECT
    COALESCE(c.variant_id, m.vid)        AS variant_id,
    m.qty                                AS quantity,
    c.product_id,
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
