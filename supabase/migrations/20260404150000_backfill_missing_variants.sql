-- Backfill: create a default product_variant for every product that has none.
-- Products without variants are invisible in catalog_items (JOIN-based VIEW).
--
-- Safety:
--   - variant_id is NOT included → DB default gen_random_uuid()::text applies
--   - LEFT JOIN + WHERE v.id IS NULL guarantees no duplicates
--   - Existing variants are untouched (INSERT only, no UPDATE/DELETE)

INSERT INTO product_variants (
  product_id,
  title,
  price,
  old_price,
  quantity,
  photo,
  editions,
  modifications,
  external_id,
  tilda_uid
)
SELECT
  p.id,
  p.title,
  0,
  NULL,
  0,
  p.photo,
  NULL,
  NULL,
  p.external_id,
  p.tilda_uid
FROM products p
LEFT JOIN product_variants v ON v.product_id = p.id
WHERE v.id IS NULL;
