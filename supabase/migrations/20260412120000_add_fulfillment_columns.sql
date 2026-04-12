-- Migration: add structured fulfillment model to order_requests.
--
-- Introduces three new columns alongside the existing delivery_method /
-- delivery_address pair.  Old columns are kept intact for backward
-- compatibility — nothing is dropped or renamed.
--
-- New columns:
--   fulfillment_type   – canonical type: 'pickup' | 'delivery'
--   pickup_store_id    – references a store row (TEXT, no FK yet — see note)
--   delivery_zone_code – normalised delivery zone key
--
-- CHECK constraints enforce valid combinations only when new fields are
-- populated.  Rows with fulfillment_type IS NULL are treated as legacy
-- and pass all checks unconditionally.
--
-- NOTE on pickup_store_id:
--   The `stores` table exists in production but has no CREATE TABLE
--   migration in this repo.  Its PK type (UUID vs TEXT) is unconfirmed.
--   We use TEXT here and skip the FK.  A follow-up migration should add
--   `ALTER TABLE … ADD CONSTRAINT … FOREIGN KEY` once the `stores`
--   schema is codified.

-- =========================================================================
-- 1. Add columns (idempotent)
-- =========================================================================

ALTER TABLE public.order_requests
  ADD COLUMN IF NOT EXISTS fulfillment_type   TEXT;

ALTER TABLE public.order_requests
  ADD COLUMN IF NOT EXISTS pickup_store_id    TEXT;

ALTER TABLE public.order_requests
  ADD COLUMN IF NOT EXISTS delivery_zone_code TEXT;

-- =========================================================================
-- 2. Value domain constraints
-- =========================================================================

-- fulfillment_type must be one of the two allowed values (or NULL for legacy).
ALTER TABLE public.order_requests
  DROP CONSTRAINT IF EXISTS chk_fulfillment_type_values;
ALTER TABLE public.order_requests
  ADD CONSTRAINT chk_fulfillment_type_values
  CHECK (fulfillment_type IS NULL OR fulfillment_type IN ('pickup', 'delivery'));

-- delivery_zone_code must be one of the known zone codes (or NULL).
ALTER TABLE public.order_requests
  DROP CONSTRAINT IF EXISTS chk_delivery_zone_code_values;
ALTER TABLE public.order_requests
  ADD CONSTRAINT chk_delivery_zone_code_values
  CHECK (delivery_zone_code IS NULL OR delivery_zone_code IN (
    'tiraspol', 'bender', 'express', 'moldova'
  ));

-- =========================================================================
-- 3. Combination constraints (only enforced when fulfillment_type is set)
-- =========================================================================

-- Pickup: store required, no zone, no address.
-- Delivery: zone + address required, no store.
-- NULL fulfillment_type: legacy row — skip all checks.
ALTER TABLE public.order_requests
  DROP CONSTRAINT IF EXISTS chk_fulfillment_consistency;
ALTER TABLE public.order_requests
  ADD CONSTRAINT chk_fulfillment_consistency
  CHECK (
    fulfillment_type IS NULL
    OR (
      fulfillment_type = 'pickup'
      AND pickup_store_id IS NOT NULL
      AND delivery_zone_code IS NULL
      AND (delivery_address IS NULL OR TRIM(delivery_address) = '')
    )
    OR (
      fulfillment_type = 'delivery'
      AND pickup_store_id IS NULL
      AND delivery_zone_code IS NOT NULL
      AND delivery_address IS NOT NULL
      AND TRIM(delivery_address) <> ''
    )
  );

-- =========================================================================
-- 4. Index for pickup_store_id (sparse — only pickup orders)
-- =========================================================================

CREATE INDEX IF NOT EXISTS idx_order_requests_pickup_store_id
  ON public.order_requests (pickup_store_id)
  WHERE pickup_store_id IS NOT NULL;

CREATE INDEX IF NOT EXISTS idx_order_requests_fulfillment_type
  ON public.order_requests (fulfillment_type)
  WHERE fulfillment_type IS NOT NULL;
