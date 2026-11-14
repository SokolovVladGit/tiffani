-- TIFFANI product gallery source.
-- Additive. Does not change ids, urls, positions, RLS, or uniqueness.
-- NULL stays the legacy/app-native value. This file does not classify
-- every NULL row as Tilda.
--
-- Apply only after review. Do not run from the app or from YML sync.

BEGIN;

ALTER TABLE public.product_images
  ADD COLUMN IF NOT EXISTS source text;

DO $$
BEGIN
  IF NOT EXISTS (
    SELECT 1
    FROM pg_constraint
    WHERE conname = 'product_images_source_check'
      AND conrelid = 'public.product_images'::regclass
  ) THEN
    ALTER TABLE public.product_images
      ADD CONSTRAINT product_images_source_check
      CHECK (source IS NULL OR source IN ('yml_variant', 'tilda_gallery'));
  END IF;
END $$;

COMMENT ON COLUMN public.product_images.source IS
  'yml_variant = primary photo of a Tilda variant from YML. '
  'tilda_gallery = supplementary photo whose product-level association was verified. '
  'NULL = app-native or otherwise unclassified. Flutter must not treat NULL as a Tilda angle.';

-- Confirmed variant primaries on Tilda products only.
-- A row is confirmed when its URL equals that product's variant.photo.
-- Native products (tilda_uid IS NULL) are not updated.
-- Rows already classified, including tilda_gallery, are left alone.
UPDATE public.product_images AS image
SET source = 'yml_variant'
FROM public.products AS product
WHERE image.product_id = product.id
  AND product.tilda_uid IS NOT NULL
  AND image.source IS NULL
  AND EXISTS (
    SELECT 1
    FROM public.product_variants AS variant
    WHERE variant.product_id = image.product_id
      AND variant.photo IS NOT NULL
      AND variant.photo = image.url
  );

COMMIT;
