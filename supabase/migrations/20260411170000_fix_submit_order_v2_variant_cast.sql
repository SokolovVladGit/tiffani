-- Fix: explicit ::text cast on catalog_items.variant_id join to prevent
-- "operator does not exist: uuid = text" when VIEW column type differs.
-- Also adds SET search_path = public (SECURITY DEFINER best practice).

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
  v_name        TEXT;
  v_phone       TEXT;
  v_consent     BOOLEAN;
  v_request_id  UUID;
  v_total_items INT;
  v_total_qty   INT;
  v_total_price DOUBLE PRECISION;
  v_bad         TEXT[];
  v_merged      JSONB;
BEGIN
  -- ----------------------------------------------------------------
  -- 1. Validate customer fields
  -- ----------------------------------------------------------------
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

  -- ----------------------------------------------------------------
  -- 2. Validate items array
  -- ----------------------------------------------------------------
  IF p_items IS NULL OR jsonb_array_length(p_items) = 0 THEN
    RAISE EXCEPTION 'items cannot be empty';
  END IF;

  -- ----------------------------------------------------------------
  -- 3. Merge duplicate variant_ids, sum quantities
  -- ----------------------------------------------------------------
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

  -- ----------------------------------------------------------------
  -- 4. Validate individual quantities
  -- ----------------------------------------------------------------
  SELECT array_agg(item->>'variant_id')
  INTO v_bad
  FROM jsonb_array_elements(v_merged) AS item
  WHERE (item->>'quantity')::INT < 1;

  IF v_bad IS NOT NULL AND array_length(v_bad, 1) > 0 THEN
    RAISE EXCEPTION 'Invalid quantity for variants: %', array_to_string(v_bad, ', ');
  END IF;

  -- ----------------------------------------------------------------
  -- 5. Resolve catalog data into temp table
  -- ----------------------------------------------------------------
  CREATE TEMP TABLE _order_lines ON COMMIT DROP AS
  SELECT
    m.vid                                AS variant_id,
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
  LEFT JOIN catalog_items c ON c.variant_id::text = m.vid::text;

  -- ----------------------------------------------------------------
  -- 6. Validate: all variants found
  -- ----------------------------------------------------------------
  SELECT array_agg(variant_id)
  INTO v_bad
  FROM _order_lines
  WHERE product_id IS NULL;

  IF v_bad IS NOT NULL AND array_length(v_bad, 1) > 0 THEN
    RAISE EXCEPTION 'Variants not found: %', array_to_string(v_bad, ', ');
  END IF;

  -- ----------------------------------------------------------------
  -- 7. Validate: all variants active
  -- ----------------------------------------------------------------
  SELECT array_agg(variant_id)
  INTO v_bad
  FROM _order_lines
  WHERE is_active = false;

  IF v_bad IS NOT NULL AND array_length(v_bad, 1) > 0 THEN
    RAISE EXCEPTION 'Inactive variants: %', array_to_string(v_bad, ', ');
  END IF;

  -- ----------------------------------------------------------------
  -- 8. Validate: all prices present
  -- ----------------------------------------------------------------
  SELECT array_agg(variant_id)
  INTO v_bad
  FROM _order_lines
  WHERE price IS NULL;

  IF v_bad IS NOT NULL AND array_length(v_bad, 1) > 0 THEN
    RAISE EXCEPTION 'No price for variants: %', array_to_string(v_bad, ', ');
  END IF;

  -- ----------------------------------------------------------------
  -- 9. Compute totals
  -- ----------------------------------------------------------------
  SELECT
    COUNT(*)::INT,
    SUM(quantity)::INT,
    SUM(line_total)
  INTO v_total_items, v_total_qty, v_total_price
  FROM _order_lines;

  -- ----------------------------------------------------------------
  -- 10. Insert order header
  -- ----------------------------------------------------------------
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
    user_id
  )
  VALUES (
    v_name,
    v_phone,
    NULLIF(TRIM(COALESCE(p_customer->>'email', '')), ''),
    NULLIF(TRIM(COALESCE(p_customer->>'delivery_method', '')), ''),
    NULLIF(TRIM(COALESCE(p_customer->>'delivery_address', '')), ''),
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
    (p_customer->>'user_id')::UUID
  )
  RETURNING id INTO v_request_id;

  -- ----------------------------------------------------------------
  -- 11. Insert order line items (server-resolved snapshots)
  -- ----------------------------------------------------------------
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

  -- ----------------------------------------------------------------
  -- 12. Return result
  -- ----------------------------------------------------------------
  RETURN jsonb_build_object(
    'order_id',       v_request_id,
    'total_items',    v_total_items,
    'total_quantity',  v_total_qty,
    'total_price',    v_total_price
  );
END;
$$;
