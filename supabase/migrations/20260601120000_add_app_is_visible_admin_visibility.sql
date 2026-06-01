-- ============================================================================
-- App-native product visibility (Phase 1 DB foundation)
--
-- Adds products.app_is_visible so admins can hide products without Tilda/YML
-- sync overwriting the decision. products.is_active remains source/import status.
--
-- catalog_items.is_active becomes the effective public flag:
--   (p.is_active AND p.app_is_visible)
--
-- Safety:
--   - Does NOT modify submit_order_v2 / submit_order_v3 (they read is_active
--     from catalog_items and continue to reject hidden lines).
--   - Does NOT change Edge Functions; sync ProductRow omits app_is_visible.
--   - Admin-native products (tilda_uid IS NULL) remain excluded from YML upsert.
-- ============================================================================

BEGIN;

-- ----------------------------------------------------------------------------
-- 1. App visibility column on products
-- ----------------------------------------------------------------------------
ALTER TABLE public.products
  ADD COLUMN IF NOT EXISTS app_is_visible boolean NOT NULL DEFAULT true;

COMMENT ON COLUMN public.products.app_is_visible IS
  'App/admin visibility override. When false, product is hidden from catalog_items '
  'effective is_active. Tilda/YML sync must NOT include this column in upsert payloads.';

COMMENT ON COLUMN public.products.is_active IS
  'Source/import active status from Tilda catalog pipeline. Distinct from app_is_visible; '
  'do not use alone for admin hide on Tilda-sourced rows (sync may set is_active = true).';

CREATE INDEX IF NOT EXISTS idx_products_app_is_visible
  ON public.products (app_is_visible);

-- ----------------------------------------------------------------------------
-- 2. Recreate catalog_items VIEW (effective is_active only)
--    Drop view-dependent filter RPCs first (column-level pg_depend).
-- ----------------------------------------------------------------------------
DROP FUNCTION IF EXISTS public.get_distinct_brands();
DROP FUNCTION IF EXISTS public.get_distinct_categories();
DROP FUNCTION IF EXISTS public.get_distinct_marks();

DROP VIEW IF EXISTS public.catalog_items;

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
  (p.is_active AND p.app_is_visible)   AS is_active,
  pv.price                             AS price,
  pv.old_price                         AS old_price,
  pv.quantity                          AS quantity,
  pv.editions                          AS editions,
  pv.modifications                     AS modifications,
  pv.attributes                        AS attributes
FROM public.product_variants pv
JOIN public.products p ON p.id = pv.product_id;

COMMENT ON VIEW public.catalog_items IS
  'Flutter catalog contract. is_active = products.is_active AND products.app_is_visible.';

GRANT SELECT ON public.catalog_items TO anon, authenticated;

-- ----------------------------------------------------------------------------
-- 3. Recreate view-dependent filter RPCs (unchanged logic; view is_active updated)
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
-- 4. Admin RPC: toggle app_is_visible only (never products.is_active)
-- ----------------------------------------------------------------------------
CREATE OR REPLACE FUNCTION public.admin_set_product_visibility(
  p_product_id uuid,
  p_visible    boolean
)
RETURNS jsonb
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
  v_row record;
BEGIN
  IF NOT public.is_admin() THEN
    RAISE EXCEPTION 'Admin access required';
  END IF;

  UPDATE public.products
  SET app_is_visible = p_visible
  WHERE id = p_product_id
  RETURNING
    id,
    app_is_visible,
    (is_active AND app_is_visible) AS effective_is_active
  INTO v_row;

  IF NOT FOUND THEN
    RAISE EXCEPTION 'Product not found: %', p_product_id;
  END IF;

  RETURN jsonb_build_object(
    'product_id',          v_row.id,
    'app_is_visible',      v_row.app_is_visible,
    'effective_is_active', v_row.effective_is_active
  );
END;
$$;

COMMENT ON FUNCTION public.admin_set_product_visibility(uuid, boolean) IS
  'Sets products.app_is_visible for admin users only. Does not modify products.is_active.';

GRANT EXECUTE ON FUNCTION public.admin_set_product_visibility(uuid, boolean)
  TO authenticated;

COMMIT;
