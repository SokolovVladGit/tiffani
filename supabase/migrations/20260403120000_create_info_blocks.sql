-- ============================================================
-- info_blocks — single content table for the Info screen
-- ============================================================

CREATE TABLE IF NOT EXISTS info_blocks (
  id           uuid        PRIMARY KEY DEFAULT gen_random_uuid(),
  block_type   text        NOT NULL,
  sort_order   integer     NOT NULL,
  title        text,
  subtitle     text,
  text_content text,
  image_url    text,
  items_json   jsonb,
  is_active    boolean     NOT NULL DEFAULT true,
  created_at   timestamptz NOT NULL DEFAULT now()
);

CREATE INDEX idx_info_blocks_sort ON info_blocks (sort_order)
  WHERE is_active = true;

-- ============================================================
-- RLS — public read for active blocks, no public writes
-- ============================================================

ALTER TABLE info_blocks ENABLE ROW LEVEL SECURITY;

CREATE POLICY "Public read active info blocks"
  ON info_blocks
  FOR SELECT
  TO anon, authenticated
  USING (is_active = true);
