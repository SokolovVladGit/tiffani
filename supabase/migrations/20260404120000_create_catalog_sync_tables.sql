-- ============================================================
-- Sync-layer tables + base-table prep for Tilda catalog sync
--
-- Schema truth:
--   catalog_items    = READ-ONLY VIEW (not writable)
--   products         = writable base table (product-level data)
--   product_variants = writable base table (variant/SKU-level data)
--   product_images   = writable base table (gallery images)
--
-- The sync writes to the three base tables only.
-- The VIEW automatically reflects the latest data.
-- ============================================================

-- 1. Sync run tracking
CREATE TABLE IF NOT EXISTS catalog_sync_runs (
  id                uuid        PRIMARY KEY DEFAULT gen_random_uuid(),
  started_at        timestamptz NOT NULL DEFAULT now(),
  finished_at       timestamptz,
  status            text        NOT NULL DEFAULT 'pending',
  source_type       text        NOT NULL DEFAULT 'yml',
  products_seen     integer     DEFAULT 0,
  variants_seen     integer     DEFAULT 0,
  images_seen       integer     DEFAULT 0,
  products_upserted integer     DEFAULT 0,
  variants_upserted integer     DEFAULT 0,
  images_upserted   integer     DEFAULT 0,
  error_count       integer     DEFAULT 0,
  metadata          jsonb
);

CREATE INDEX IF NOT EXISTS idx_catalog_sync_runs_started
  ON catalog_sync_runs (started_at DESC);

-- 2. Sync error tracking
CREATE TABLE IF NOT EXISTS catalog_sync_run_errors (
  id           uuid        PRIMARY KEY DEFAULT gen_random_uuid(),
  run_id       uuid        NOT NULL REFERENCES catalog_sync_runs(id) ON DELETE CASCADE,
  stage        text        NOT NULL,
  external_key text        NOT NULL DEFAULT '',
  message      text        NOT NULL,
  details      jsonb,
  created_at   timestamptz NOT NULL DEFAULT now()
);

CREATE INDEX IF NOT EXISTS idx_catalog_sync_run_errors_run
  ON catalog_sync_run_errors (run_id);

-- 3. RLS on sync tables
ALTER TABLE catalog_sync_runs ENABLE ROW LEVEL SECURITY;
ALTER TABLE catalog_sync_run_errors ENABLE ROW LEVEL SECURITY;

-- ============================================================
-- 4. Ensure tilda_uid column on products (base table)
--    Stores the Tilda product/group-level identifier.
-- ============================================================
ALTER TABLE products ADD COLUMN IF NOT EXISTS tilda_uid text;

-- Backfill: existing products get tilda_uid = id (as text)
-- so the unique index covers legacy rows.
UPDATE products SET tilda_uid = id::text WHERE tilda_uid IS NULL;

DO $$
BEGIN
  CREATE UNIQUE INDEX idx_products_tilda_uid_unique
    ON products (tilda_uid) WHERE tilda_uid IS NOT NULL;
EXCEPTION
  WHEN duplicate_table THEN NULL;
END$$;

-- ============================================================
-- 5. Ensure variant_id column on product_variants (base table)
--    Stores the Tilda offer-level identifier (unique per SKU).
-- ============================================================
ALTER TABLE product_variants ADD COLUMN IF NOT EXISTS variant_id text;

-- Backfill: existing variants get variant_id = id (as text)
UPDATE product_variants SET variant_id = id::text WHERE variant_id IS NULL;

DO $$
BEGIN
  CREATE UNIQUE INDEX idx_product_variants_variant_id_unique
    ON product_variants (variant_id) WHERE variant_id IS NOT NULL;
EXCEPTION
  WHEN duplicate_table THEN NULL;
END$$;

-- ============================================================
-- 6. product_images: dedup + unique index for upsert
-- ============================================================
DO $$
BEGIN
  DELETE FROM product_images a
    USING product_images b
    WHERE a.ctid > b.ctid
      AND a.product_id = b.product_id
      AND a.url = b.url;

  IF NOT EXISTS (
    SELECT 1 FROM pg_indexes WHERE indexname = 'idx_product_images_product_url_unique'
  ) THEN
    CREATE UNIQUE INDEX idx_product_images_product_url_unique
      ON product_images (product_id, url);
  END IF;
END$$;
