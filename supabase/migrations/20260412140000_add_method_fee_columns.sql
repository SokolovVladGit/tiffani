-- Migration: add fulfillment method, fee, and payment method code columns
-- to order_requests.
--
-- New columns:
--   fulfillment_method_code – canonical method key (e.g. 'courier_tiraspol')
--   fulfillment_fee         – fee charged for the fulfillment method (>= 0)
--   payment_method_code     – canonical payment key (e.g. 'cash')
--
-- All nullable for backward compatibility with legacy rows.
-- CHECK constraints enforce value domains when fields are populated.

-- =========================================================================
-- 1. Add columns (idempotent)
-- =========================================================================

ALTER TABLE public.order_requests
  ADD COLUMN IF NOT EXISTS fulfillment_method_code TEXT;

ALTER TABLE public.order_requests
  ADD COLUMN IF NOT EXISTS fulfillment_fee DOUBLE PRECISION;

ALTER TABLE public.order_requests
  ADD COLUMN IF NOT EXISTS payment_method_code TEXT;

-- =========================================================================
-- 2. Value domain constraints
-- =========================================================================

ALTER TABLE public.order_requests
  DROP CONSTRAINT IF EXISTS chk_fulfillment_method_code_values;
ALTER TABLE public.order_requests
  ADD CONSTRAINT chk_fulfillment_method_code_values
  CHECK (fulfillment_method_code IS NULL OR fulfillment_method_code IN (
    'pickup_store',
    'courier_tiraspol',
    'courier_bender',
    'express_post',
    'moldova_post'
  ));

ALTER TABLE public.order_requests
  DROP CONSTRAINT IF EXISTS chk_payment_method_code_values;
ALTER TABLE public.order_requests
  ADD CONSTRAINT chk_payment_method_code_values
  CHECK (payment_method_code IS NULL OR payment_method_code IN (
    'cash',
    'mobile_payment',
    'bank_transfer',
    'clever_installment'
  ));

ALTER TABLE public.order_requests
  DROP CONSTRAINT IF EXISTS chk_fulfillment_fee_non_negative;
ALTER TABLE public.order_requests
  ADD CONSTRAINT chk_fulfillment_fee_non_negative
  CHECK (fulfillment_fee IS NULL OR fulfillment_fee >= 0);

-- =========================================================================
-- 3. Cross-field consistency: method code must agree with fulfillment_type
-- =========================================================================
-- Only enforced when BOTH fulfillment_type and fulfillment_method_code are
-- populated.  Legacy rows (either NULL) pass unconditionally.

ALTER TABLE public.order_requests
  DROP CONSTRAINT IF EXISTS chk_fulfillment_method_type_agreement;
ALTER TABLE public.order_requests
  ADD CONSTRAINT chk_fulfillment_method_type_agreement
  CHECK (
    fulfillment_type IS NULL
    OR fulfillment_method_code IS NULL
    OR (
      fulfillment_type = 'pickup'
      AND fulfillment_method_code = 'pickup_store'
    )
    OR (
      fulfillment_type = 'delivery'
      AND fulfillment_method_code IN (
        'courier_tiraspol', 'courier_bender', 'express_post', 'moldova_post'
      )
    )
  );
