-- ============================================================================
-- Phase 3A: Native product create/edit (admin-only RPC)
--
-- App-native product = products.tilda_uid IS NULL.
-- Tilda-imported products (tilda_uid IS NOT NULL) must not be edited here.
-- Native rows stay outside YML sync (upsert onConflict tilda_uid only).
--
-- Does NOT modify: catalog_items, submit_order_v2/v3, Edge Functions, cron.
-- ============================================================================

BEGIN;

-- ----------------------------------------------------------------------------
-- 1. Helper: collision-safe admin variant_id
-- ----------------------------------------------------------------------------
CREATE OR REPLACE FUNCTION public.generate_admin_variant_id()
RETURNS text
LANGUAGE plpgsql
VOLATILE
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
  v_candidate text;
  v_attempt   int := 0;
BEGIN
  LOOP
    v_candidate := 'admin_' || replace(gen_random_uuid()::text, '-', '');
    EXIT WHEN NOT EXISTS (
      SELECT 1
      FROM public.product_variants pv
      WHERE pv.variant_id = v_candidate
    );
    v_attempt := v_attempt + 1;
    IF v_attempt >= 20 THEN
      RAISE EXCEPTION 'Could not generate unique admin variant_id';
    END IF;
  END LOOP;
  RETURN v_candidate;
END;
$$;

COMMENT ON FUNCTION public.generate_admin_variant_id() IS
  'Returns a unique variant_id with admin_ prefix for app-native catalog SKUs. '
  'Stable cart/order key; must not change after create.';

-- ----------------------------------------------------------------------------
-- 2. Main RPC: create or update one native product + one variant + images
-- ----------------------------------------------------------------------------
CREATE OR REPLACE FUNCTION public.admin_upsert_native_product(p_payload jsonb)
RETURNS jsonb
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
  v_product_id_text text;
  v_product_id      uuid;
  v_is_update       boolean;

  v_title           text;
  v_brand           text;
  v_category        text;
  v_mark            text;
  v_description     text;
  v_text            text;
  v_price           numeric(12, 2);
  v_old_price       numeric(12, 2);
  v_quantity        int;
  v_app_visible     boolean;
  v_primary_photo   text;

  v_urls            text[] := ARRAY[]::text[];
  v_url_raw         text;
  v_url_norm        text;
  v_url_elem        jsonb;
  v_url_count       int := 0;
  v_pos             int;

  v_product         public.products%ROWTYPE;
  v_variant         public.product_variants%ROWTYPE;
  v_variant_count   int;
  v_variant_id      text;
  v_new_product_id  uuid;

  v_effective_active boolean;
BEGIN
  IF p_payload IS NULL OR jsonb_typeof(p_payload) <> 'object' THEN
    RAISE EXCEPTION 'payload must be a JSON object';
  END IF;

  IF NOT public.is_admin() THEN
    RAISE EXCEPTION 'Admin access required';
  END IF;

  -- ── Parse product_id (create vs update) ───────────────────────────────────
  v_product_id_text := nullif(trim(p_payload->>'product_id'), '');
  IF v_product_id_text IS NOT NULL
     AND lower(v_product_id_text) IN ('null', 'undefined') THEN
    v_product_id_text := NULL;
  END IF;

  IF v_product_id_text IS NULL THEN
    v_is_update := false;
  ELSE
    BEGIN
      v_product_id := v_product_id_text::uuid;
    EXCEPTION
      WHEN invalid_text_representation THEN
        RAISE EXCEPTION 'product_id must be a valid UUID';
    END;
    v_is_update := true;
  END IF;

  -- ── Required / optional text fields ───────────────────────────────────────
  v_title := nullif(trim(p_payload->>'title'), '');
  IF v_title IS NULL THEN
    RAISE EXCEPTION 'title is required';
  END IF;
  IF length(v_title) > 500 THEN
    RAISE EXCEPTION 'title must be at most 500 characters';
  END IF;

  v_brand := nullif(trim(p_payload->>'brand'), '');
  v_category := nullif(trim(p_payload->>'category'), '');
  v_mark := nullif(trim(p_payload->>'mark'), '');
  v_description := nullif(trim(p_payload->>'description'), '');
  v_text := nullif(trim(p_payload->>'text'), '');

  -- ── price (required) ────────────────────────────────────────────────────
  IF p_payload->'price' IS NULL
     OR jsonb_typeof(p_payload->'price') NOT IN ('number', 'string') THEN
    RAISE EXCEPTION 'price is required';
  END IF;
  BEGIN
    v_price := (p_payload->>'price')::numeric(12, 2);
  EXCEPTION
    WHEN others THEN
      RAISE EXCEPTION 'price must be a valid number';
  END;
  IF v_price IS NULL OR v_price < 0 THEN
    RAISE EXCEPTION 'price must be greater than or equal to 0';
  END IF;

  -- ── old_price (optional) ──────────────────────────────────────────────────
  v_old_price := NULL;
  IF p_payload ? 'old_price'
     AND p_payload->'old_price' IS NOT NULL
     AND jsonb_typeof(p_payload->'old_price') <> 'null' THEN
    BEGIN
      v_old_price := (p_payload->>'old_price')::numeric(12, 2);
    EXCEPTION
      WHEN others THEN
        RAISE EXCEPTION 'old_price must be a valid number';
    END;
    IF v_old_price < 0 THEN
      RAISE EXCEPTION 'old_price must be greater than or equal to 0';
    END IF;
    IF v_old_price < v_price THEN
      RAISE EXCEPTION 'old_price must be greater than or equal to price';
    END IF;
  END IF;

  -- ── quantity (required) ───────────────────────────────────────────────────
  IF p_payload->'quantity' IS NULL
     OR jsonb_typeof(p_payload->'quantity') NOT IN ('number', 'string') THEN
    RAISE EXCEPTION 'quantity is required';
  END IF;
  BEGIN
    v_quantity := (p_payload->>'quantity')::int;
  EXCEPTION
    WHEN others THEN
      RAISE EXCEPTION 'quantity must be a valid integer';
  END;
  IF v_quantity IS NULL OR v_quantity < 0 THEN
    RAISE EXCEPTION 'quantity must be greater than or equal to 0';
  END IF;

  -- ── app_is_visible (default true) ─────────────────────────────────────────
  IF p_payload ? 'app_is_visible'
     AND p_payload->'app_is_visible' IS NOT NULL
     AND jsonb_typeof(p_payload->'app_is_visible') <> 'null' THEN
    BEGIN
      v_app_visible := (p_payload->>'app_is_visible')::boolean;
    EXCEPTION
      WHEN others THEN
        RAISE EXCEPTION 'app_is_visible must be a boolean';
    END;
  ELSE
    v_app_visible := true;
  END IF;

  -- ── image_urls: normalize, validate, dedupe (max 30) ─────────────────────
  IF p_payload ? 'image_urls'
     AND p_payload->'image_urls' IS NOT NULL
     AND jsonb_typeof(p_payload->'image_urls') <> 'null' THEN
    IF jsonb_typeof(p_payload->'image_urls') <> 'array' THEN
      RAISE EXCEPTION 'image_urls must be a JSON array';
    END IF;

    FOR v_url_elem IN
      SELECT value
      FROM jsonb_array_elements(p_payload->'image_urls')
    LOOP
      IF jsonb_typeof(v_url_elem) <> 'string' THEN
        RAISE EXCEPTION 'image_urls must contain only strings';
      END IF;
      v_url_raw := nullif(trim(v_url_elem #>> '{}'), '');
      IF v_url_raw IS NULL THEN
        CONTINUE;
      END IF;
      IF length(v_url_raw) > 2048 THEN
        RAISE EXCEPTION 'image URL must be at most 2048 characters';
      END IF;
      IF NOT (
        v_url_raw LIKE 'http://%'
        OR v_url_raw LIKE 'https://%'
      ) THEN
        RAISE EXCEPTION 'image URL must start with http:// or https://';
      END IF;
      IF v_url_raw = ANY (v_urls) THEN
        CONTINUE;
      END IF;
      v_urls := array_append(v_urls, v_url_raw);
      v_url_count := v_url_count + 1;
      IF v_url_count > 30 THEN
        RAISE EXCEPTION 'image_urls must contain at most 30 URLs';
      END IF;
    END LOOP;
  END IF;

  v_primary_photo := CASE
    WHEN array_length(v_urls, 1) IS NOT NULL THEN v_urls[1]
    ELSE NULL
  END;

  -- ── CREATE ────────────────────────────────────────────────────────────────
  IF NOT v_is_update THEN
    v_variant_id := public.generate_admin_variant_id();

    INSERT INTO public.products (
      tilda_uid,
      title,
      brand,
      category,
      mark,
      description,
      text,
      photo,
      is_active,
      app_is_visible
    )
    VALUES (
      NULL,
      v_title,
      v_brand,
      v_category,
      v_mark,
      v_description,
      v_text,
      v_primary_photo,
      true,
      v_app_visible
    )
    RETURNING id INTO v_new_product_id;

    INSERT INTO public.product_variants (
      product_id,
      variant_id,
      title,
      price,
      old_price,
      quantity,
      photo,
      editions,
      modifications,
      external_id,
      tilda_uid,
      attributes
    )
    VALUES (
      v_new_product_id,
      v_variant_id,
      v_title,
      v_price,
      v_old_price,
      v_quantity,
      v_primary_photo,
      NULL,
      NULL,
      v_variant_id,
      NULL,
      '{}'::jsonb
    );

    v_pos := 0;
    FOREACH v_url_norm IN ARRAY v_urls
    LOOP
      INSERT INTO public.product_images (product_id, url, position)
      VALUES (v_new_product_id, v_url_norm, v_pos);
      v_pos := v_pos + 1;
    END LOOP;

    v_product_id := v_new_product_id;
  ELSE
    -- ── UPDATE ──────────────────────────────────────────────────────────────
    SELECT *
    INTO v_product
    FROM public.products
    WHERE id = v_product_id
    FOR UPDATE;

    IF NOT FOUND THEN
      RAISE EXCEPTION 'Product not found: %', v_product_id;
    END IF;

    IF v_product.tilda_uid IS NOT NULL THEN
      RAISE EXCEPTION 'Tilda products cannot be edited';
    END IF;

    SELECT count(*)
    INTO v_variant_count
    FROM public.product_variants
    WHERE product_id = v_product_id;

    IF v_variant_count = 0 THEN
      RAISE EXCEPTION 'Product has no variants';
    END IF;
    IF v_variant_count > 1 THEN
      RAISE EXCEPTION
        'Multi-variant native edit is not supported in MVP';
    END IF;

    SELECT *
    INTO v_variant
    FROM public.product_variants
    WHERE product_id = v_product_id
    FOR UPDATE;

    v_variant_id := v_variant.variant_id;

    UPDATE public.products
    SET
      tilda_uid      = NULL,
      title          = v_title,
      brand          = v_brand,
      category       = v_category,
      mark           = v_mark,
      description    = v_description,
      text           = v_text,
      photo          = v_primary_photo,
      is_active      = true,
      app_is_visible = v_app_visible
    WHERE id = v_product_id;

    UPDATE public.product_variants
    SET
      title          = v_title,
      price          = v_price,
      old_price      = v_old_price,
      quantity       = v_quantity,
      photo          = v_primary_photo,
      tilda_uid      = NULL
    WHERE id = v_variant.id;

    DELETE FROM public.product_images
    WHERE product_id = v_product_id;

    v_pos := 0;
    FOREACH v_url_norm IN ARRAY v_urls
    LOOP
      INSERT INTO public.product_images (product_id, url, position)
      VALUES (v_product_id, v_url_norm, v_pos);
      v_pos := v_pos + 1;
    END LOOP;
  END IF;

  v_effective_active := true AND v_app_visible;

  RETURN jsonb_build_object(
    'product_id',            v_product_id,
    'variant_id',            v_variant_id,
    'title',                 v_title,
    'brand',                 v_brand,
    'category',              v_category,
    'mark',                  v_mark,
    'photo',                 v_primary_photo,
    'price',                 v_price,
    'old_price',             v_old_price,
    'quantity',              v_quantity,
    'app_is_visible',        v_app_visible,
    'is_active',             true,
    'effective_is_active',   v_effective_active,
    'tilda_uid',             NULL,
    'image_urls',            to_jsonb(v_urls)
  );
END;
$$;

COMMENT ON FUNCTION public.admin_upsert_native_product(jsonb) IS
  'Creates or updates an app-native catalog product (products.tilda_uid IS NULL). '
  'Rejects Tilda-imported products. MVP: exactly one variant per native product; '
  'variant_id is generated on create (admin_ prefix) and never changes on edit. '
  'Visibility for the public catalog uses app_is_visible; is_active is forced true. '
  'Tilda/YML sync must not overwrite native products (keep tilda_uid NULL).';

GRANT EXECUTE ON FUNCTION public.generate_admin_variant_id() TO authenticated;
GRANT EXECUTE ON FUNCTION public.admin_upsert_native_product(jsonb) TO authenticated;

COMMIT;
