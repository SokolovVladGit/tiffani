-- ============================================================
-- Fix: Replace partial unique indexes with unconditional ones
-- so that ON CONFLICT (column) works in Supabase JS upserts.
--
-- Partial indexes (WHERE col IS NOT NULL) cannot serve as
-- conflict targets for ON CONFLICT (column) in PostgreSQL.
--
-- Behavior is preserved: NULLs remain distinct in PG unique
-- indexes, so multiple NULL rows are still allowed.
-- ============================================================

-- 1. Re-activate products incorrectly deactivated by a sync run
--    that failed upserts but succeeded at the deactivation step.
UPDATE products SET is_active = true WHERE is_active = false;

-- 2. Replace partial unique index on products.tilda_uid
DROP INDEX IF EXISTS idx_products_tilda_uid_unique;
CREATE UNIQUE INDEX idx_products_tilda_uid_unique ON products (tilda_uid);

-- 3. Replace partial unique index on product_variants.variant_id
DROP INDEX IF EXISTS idx_product_variants_variant_id_unique;
CREATE UNIQUE INDEX idx_product_variants_variant_id_unique ON product_variants (variant_id);
