-- Ensure catalog_items VIEW exists.
-- On production this is a no-op (VIEW already exists).
-- On fresh environments this creates the VIEW from base tables.
--
-- Depends on: products, product_variants (base tables created outside migrations).
-- Column contract matches Flutter CatalogItemDto.fromMap exactly.

DO $$
BEGIN
  IF NOT EXISTS (
    SELECT 1 FROM information_schema.views
    WHERE table_schema = 'public' AND table_name = 'catalog_items'
  ) THEN
    EXECUTE $view$
      CREATE VIEW public.catalog_items AS
      SELECT
        pv.variant_id,
        p.id::text           AS product_id,
        p.title,
        p.brand,
        p.category,
        p.mark,
        p.description,
        p.text,
        COALESCE(pv.photo, p.photo) AS photo,
        pv.price,
        pv.old_price,
        pv.quantity,
        pv.editions,
        pv.modifications,
        pv.external_id,
        p.tilda_uid,
        p.is_active,
        pv.attributes
      FROM public.product_variants pv
      JOIN public.products p ON p.id = pv.product_id
    $view$;
  END IF;
END $$;
