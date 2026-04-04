-- Ensures every product_variants row has a non-null variant_id.
-- The Flutter app casts variant_id as non-nullable String;
-- null values cause a runtime crash.

-- Step 1: Backfill any remaining nulls (idempotent)
UPDATE product_variants
SET variant_id = id::text
WHERE variant_id IS NULL;

-- Step 2: Set default for future inserts.
-- Uses gen_random_uuid() rather than id::text because `id` is not
-- available at DEFAULT evaluation time.
ALTER TABLE product_variants
ALTER COLUMN variant_id SET DEFAULT gen_random_uuid()::text;

-- Step 3: Enforce NOT NULL so nulls can never reappear.
ALTER TABLE product_variants
ALTER COLUMN variant_id SET NOT NULL;
