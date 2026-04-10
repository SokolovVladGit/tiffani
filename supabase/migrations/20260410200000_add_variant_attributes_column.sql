-- Add attributes JSONB column to product_variants for
-- storing Tilda offer params (size, color, etc.)
ALTER TABLE product_variants
  ADD COLUMN IF NOT EXISTS attributes jsonb;
