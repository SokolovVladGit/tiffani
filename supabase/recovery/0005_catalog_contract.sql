-- TIFFANI recovery baseline 0005
-- Final catalog_items contract from
-- 20260601120000_add_app_is_visible_admin_visibility.sql.
-- Filter RPCs are the same SQL with SET search_path = pg_catalog added.
-- The view is created with the default owner rights (security_invoker off),
-- so anon can read it after base-table SELECT is limited to admins.
-- 0008 pins security_invoker = false when the server supports that option.

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
JOIN public.products p ON p.id = pv.product_id
WHERE p.is_active
  AND p.app_is_visible;

COMMENT ON VIEW public.catalog_items IS
  'Public catalog. Rows are limited to products where is_active AND app_is_visible. The is_active column remains for the Flutter DTO and is true for every returned row.';

-- ----------------------------------------------------------------------------
-- 3. Recreate view-dependent filter RPCs (unchanged logic; view is_active updated)
-- ----------------------------------------------------------------------------
CREATE OR REPLACE FUNCTION public.get_distinct_brands()
RETURNS SETOF TEXT
LANGUAGE sql
STABLE
SECURITY DEFINER
SET search_path = pg_catalog
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
SET search_path = pg_catalog
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
SET search_path = pg_catalog
AS $$
  SELECT DISTINCT mark
  FROM public.catalog_items
  WHERE is_active = true
    AND mark IS NOT NULL
    AND mark <> ''
  ORDER BY mark;
$$;
