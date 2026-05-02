-- ============================================================================
-- Phase 1.1 fixture tests for public.quote_order_v1.
--
-- How to run (LOCAL / NON-PRODUCTION ONLY):
--
--   1. Start a local Postgres (e.g. supabase start, or any local Postgres
--      already loaded with this repo's migrations).
--
--   2. From a shell with PGHOST/PGUSER/PGPASSWORD/PGDATABASE pointing at the
--      LOCAL DB only (never production), run:
--
--          psql -v ON_ERROR_STOP=1 -f supabase/tests/quote_order_v1_phase1.sql
--
--      Successful runs end with: TESTS PASSED. Failed runs raise an
--      EXCEPTION and ROLLBACK; nothing is committed.
--
-- Properties:
--   - Wrapped in a single transaction with ROLLBACK at the end.
--   - Per-test SAVEPOINTs isolate campaign/target/variant state.
--   - Inserts only into base tables (products, product_variants,
--     discount_campaigns, discount_campaign_targets); never into the
--     catalog_items VIEW or into order_requests / discount_redemptions.
--   - All test data uses the 'TST-' prefix or the namespaced UUIDs below
--     to make accidental survival in a local DB obvious and easy to clean.
--   - The script does not write to discount_redemptions and asserts that
--     quote_order_v1 does not write to it either.
--
-- This file does NOT modify production. Do NOT run against production.
-- ============================================================================

\set ON_ERROR_STOP on

BEGIN;

SET LOCAL client_min_messages = NOTICE;

-- ============================================================================
-- 0. Fixture: 4 variants under 3 products, with mixed brand/category/mark.
--    These rows live only inside this transaction (final ROLLBACK clears).
-- ============================================================================

INSERT INTO public.products (id, tilda_uid, title, brand, category, mark, is_active)
VALUES
  ('11111111-1111-1111-1111-111111111111', NULL, 'TST Product A', 'TST_BRAND_A', 'TST_CATEGORY_X', 'NEW',  true),
  ('22222222-2222-2222-2222-222222222222', NULL, 'TST Product B', 'TST_BRAND_B', 'TST_CATEGORY_Y', 'HIT',  true),
  ('33333333-3333-3333-3333-333333333333', NULL, 'TST Product C', 'TST_BRAND_C', 'TST_CATEGORY_X', 'SALE', true);

INSERT INTO public.product_variants (id, product_id, variant_id, price)
VALUES
  ('aaaaaaaa-aaaa-aaaa-aaaa-aaaaaaaaaaa1', '11111111-1111-1111-1111-111111111111', 'TST-V-A1', 100.00),
  ('aaaaaaaa-aaaa-aaaa-aaaa-aaaaaaaaaaa2', '11111111-1111-1111-1111-111111111111', 'TST-V-A2', 200.00),
  ('bbbbbbbb-bbbb-bbbb-bbbb-bbbbbbbbbbb1', '22222222-2222-2222-2222-222222222222', 'TST-V-B1',  50.00),
  ('cccccccc-cccc-cccc-cccc-ccccccccccc1', '33333333-3333-3333-3333-333333333333', 'TST-V-C1',  80.00);

DO $$
DECLARE n int;
BEGIN
  SELECT count(*) INTO n FROM public.catalog_items WHERE variant_id LIKE 'TST-V-%';
  IF n <> 4 THEN
    RAISE EXCEPTION 'fixture sanity failed: expected 4 catalog_items rows, got %', n;
  END IF;
  RAISE NOTICE 'fixture: 4 catalog_items rows visible';
END $$;

-- ============================================================================
-- A. Empty items → ok=false, code=empty_items.
-- ============================================================================
SAVEPOINT t_a;
DO $$
DECLARE r jsonb;
BEGIN
  r := public.quote_order_v1('{}'::jsonb, '[]'::jsonb);
  IF (r->>'ok')::boolean IS NOT FALSE THEN
    RAISE EXCEPTION 'A failed: ok=% (full=%)', r->>'ok', r;
  END IF;
  IF (r->'errors'->0->>'code') <> 'empty_items' THEN
    RAISE EXCEPTION 'A wrong error code: %', r->'errors'->0->>'code';
  END IF;
  RAISE NOTICE 'A passed: empty items';
END $$;
ROLLBACK TO SAVEPOINT t_a;

-- ============================================================================
-- B. Unknown variant → ok=false, code=unknown_variant.
-- ============================================================================
SAVEPOINT t_b;
DO $$
DECLARE r jsonb;
BEGIN
  r := public.quote_order_v1(
    '{}'::jsonb,
    jsonb_build_array(jsonb_build_object('variant_id', 'TST-V-DOESNOTEXIST', 'quantity', 1))
  );
  IF (r->>'ok')::boolean IS NOT FALSE THEN
    RAISE EXCEPTION 'B failed: ok=% (full=%)', r->>'ok', r;
  END IF;
  IF (r->'errors'->0->>'code') <> 'unknown_variant' THEN
    RAISE EXCEPTION 'B wrong error code: %', r->'errors'->0->>'code';
  END IF;
  RAISE NOTICE 'B passed: unknown variant';
END $$;
ROLLBACK TO SAVEPOINT t_b;

-- ============================================================================
-- C. Basic quote without discounts.
--    cart: A1 ×2 (=200) + B1 ×1 (=50). fee=10. expected grand=260, no promo.
-- ============================================================================
SAVEPOINT t_c;
DO $$
DECLARE r jsonb;
BEGIN
  r := public.quote_order_v1(
    jsonb_build_object('fulfillment_fee', 10),
    jsonb_build_array(
      jsonb_build_object('variant_id', 'TST-V-A1', 'quantity', 2),
      jsonb_build_object('variant_id', 'TST-V-B1', 'quantity', 1)
    )
  );
  IF (r->>'ok')::boolean IS NOT TRUE THEN
    RAISE EXCEPTION 'C failed: ok=% (full=%)', r->>'ok', r;
  END IF;
  IF (r->>'subtotal_amount')::numeric(12,2)    <> 250.00 THEN RAISE EXCEPTION 'C subtotal: %',    r->>'subtotal_amount'; END IF;
  IF (r->>'discount_amount')::numeric(12,2)    <>   0.00 THEN RAISE EXCEPTION 'C discount: %',    r->>'discount_amount'; END IF;
  IF (r->>'fulfillment_fee')::numeric(12,2)    <>  10.00 THEN RAISE EXCEPTION 'C fee: %',         r->>'fulfillment_fee'; END IF;
  IF (r->>'grand_total_amount')::numeric(12,2) <> 260.00 THEN RAISE EXCEPTION 'C grand: %',       r->>'grand_total_amount'; END IF;
  IF (r->'promo'->>'status') <> 'not_provided' THEN RAISE EXCEPTION 'C promo status: %', r->'promo'->>'status'; END IF;
  RAISE NOTICE 'C passed: basic quote, no discount';
END $$;
ROLLBACK TO SAVEPOINT t_c;

-- ============================================================================
-- D. Canonical variant_id resolution.
--    Output line.variant_id MUST equal the canonical input.
-- ============================================================================
SAVEPOINT t_d;
DO $$
DECLARE r jsonb;
BEGIN
  r := public.quote_order_v1(
    '{}'::jsonb,
    jsonb_build_array(jsonb_build_object('variant_id', 'TST-V-A1', 'quantity', 1))
  );
  IF (r->>'ok')::boolean IS NOT TRUE THEN
    RAISE EXCEPTION 'D failed: ok=% (full=%)', r->>'ok', r;
  END IF;
  IF (r->'lines'->0->>'variant_id') <> 'TST-V-A1' THEN
    RAISE EXCEPTION 'D canonical mismatch: %', r->'lines'->0->>'variant_id';
  END IF;
  RAISE NOTICE 'D passed: canonical variant_id resolution';
END $$;
ROLLBACK TO SAVEPOINT t_d;

-- ============================================================================
-- E. Legacy UUID resolution.
--    Input is product_variants.id::text; output line.variant_id MUST be
--    normalized to the canonical product_variants.variant_id.
-- ============================================================================
SAVEPOINT t_e;
DO $$
DECLARE r jsonb;
BEGIN
  r := public.quote_order_v1(
    '{}'::jsonb,
    jsonb_build_array(jsonb_build_object(
      'variant_id', 'aaaaaaaa-aaaa-aaaa-aaaa-aaaaaaaaaaa2',
      'quantity',   1
    ))
  );
  IF (r->>'ok')::boolean IS NOT TRUE THEN
    RAISE EXCEPTION 'E failed: ok=% (full=%)', r->>'ok', r;
  END IF;
  IF (r->'lines'->0->>'variant_id') <> 'TST-V-A2' THEN
    RAISE EXCEPTION 'E canonical normalization failed: %', r->'lines'->0->>'variant_id';
  END IF;
  IF (r->'lines'->0->>'legacy_variant_uuid') <> 'aaaaaaaa-aaaa-aaaa-aaaa-aaaaaaaaaaa2' THEN
    RAISE EXCEPTION 'E legacy_variant_uuid mismatch: %', r->'lines'->0->>'legacy_variant_uuid';
  END IF;
  RAISE NOTICE 'E passed: legacy UUID resolution';
END $$;
ROLLBACK TO SAVEPOINT t_e;

-- ============================================================================
-- F. Promocode applied (TEST10, 10% on all).
--    cart: A1 ×1 (=100). discount=10. grand=100-10+0=90.
-- ============================================================================
SAVEPOINT t_f;
INSERT INTO public.discount_campaigns (kind, name, code, percent_off)
VALUES ('promocode', 'TEST10', 'TEST10', 10);

DO $$
DECLARE r jsonb; v_cid uuid;
BEGIN
  SELECT id INTO v_cid FROM public.discount_campaigns WHERE code = 'TEST10';
  r := public.quote_order_v1(
    jsonb_build_object('promo_code', 'test10'),
    jsonb_build_array(jsonb_build_object('variant_id', 'TST-V-A1', 'quantity', 1))
  );
  IF (r->'promo'->>'status') <> 'applied' THEN
    RAISE EXCEPTION 'F status: % (full=%)', r->'promo'->>'status', r;
  END IF;
  IF (r->>'discount_amount')::numeric(12,2) <> 10.00 THEN
    RAISE EXCEPTION 'F discount: %', r->>'discount_amount';
  END IF;
  IF (r->>'grand_total_amount')::numeric(12,2) <> 90.00 THEN
    RAISE EXCEPTION 'F grand: %', r->>'grand_total_amount';
  END IF;
  IF NOT EXISTS (
    SELECT 1 FROM jsonb_array_elements(r->'applied_discounts') ad
    WHERE (ad->>'code') = 'TEST10'
  ) THEN
    RAISE EXCEPTION 'F applied_discounts missing TEST10: %', r->'applied_discounts';
  END IF;
  IF (r->'lines'->0->'applied_discount'->>'campaign_id')::uuid <> v_cid THEN
    RAISE EXCEPTION 'F line.applied_discount.campaign_id mismatch';
  END IF;
  RAISE NOTICE 'F passed: promocode applied';
END $$;
ROLLBACK TO SAVEPOINT t_f;

-- ============================================================================
-- G. Promocode not_found.
-- ============================================================================
SAVEPOINT t_g;
DO $$
DECLARE r jsonb;
BEGIN
  r := public.quote_order_v1(
    jsonb_build_object('promo_code', 'NOPE_NOT_REAL'),
    jsonb_build_array(jsonb_build_object('variant_id', 'TST-V-A1', 'quantity', 1))
  );
  IF (r->'promo'->>'status') <> 'not_found' THEN
    RAISE EXCEPTION 'G status: % (full=%)', r->'promo'->>'status', r;
  END IF;
  IF (r->>'discount_amount')::numeric(12,2) <> 0.00 THEN
    RAISE EXCEPTION 'G discount: %', r->>'discount_amount';
  END IF;
  RAISE NOTICE 'G passed: promocode not_found';
END $$;
ROLLBACK TO SAVEPOINT t_g;

-- ============================================================================
-- H. Expired promocode.
-- ============================================================================
SAVEPOINT t_h;
INSERT INTO public.discount_campaigns (kind, name, code, percent_off, ends_at)
VALUES ('promocode', 'OLD10', 'OLD10', 10, now() - interval '1 day');

DO $$
DECLARE r jsonb;
BEGIN
  r := public.quote_order_v1(
    jsonb_build_object('promo_code', 'OLD10'),
    jsonb_build_array(jsonb_build_object('variant_id', 'TST-V-A1', 'quantity', 1))
  );
  IF (r->'promo'->>'status') <> 'expired' THEN
    RAISE EXCEPTION 'H status: % (full=%)', r->'promo'->>'status', r;
  END IF;
  IF (r->>'discount_amount')::numeric(12,2) <> 0.00 THEN
    RAISE EXCEPTION 'H discount: %', r->>'discount_amount';
  END IF;
  RAISE NOTICE 'H passed: expired promocode';
END $$;
ROLLBACK TO SAVEPOINT t_h;

-- ============================================================================
-- I. Min order not met.
--    Promocode requires min_order_amount=500; cart subtotal=100.
-- ============================================================================
SAVEPOINT t_i;
INSERT INTO public.discount_campaigns (kind, name, code, percent_off, min_order_amount)
VALUES ('promocode', 'MIN500', 'MIN500', 10, 500);

DO $$
DECLARE r jsonb;
BEGIN
  r := public.quote_order_v1(
    jsonb_build_object('promo_code', 'MIN500'),
    jsonb_build_array(jsonb_build_object('variant_id', 'TST-V-A1', 'quantity', 1))
  );
  IF (r->'promo'->>'status') <> 'min_order_not_met' THEN
    RAISE EXCEPTION 'I status: % (full=%)', r->'promo'->>'status', r;
  END IF;
  IF (r->>'discount_amount')::numeric(12,2) <> 0.00 THEN
    RAISE EXCEPTION 'I discount: %', r->>'discount_amount';
  END IF;
  RAISE NOTICE 'I passed: min_order_not_met';
END $$;
ROLLBACK TO SAVEPOINT t_i;

-- ============================================================================
-- J. Targeted automatic discounts (brand, category prefix, variant_id).
-- ============================================================================

-- J.1 brand exact: 20% off TST_BRAND_A only.
--   cart: A1 (100, brand A) + B1 (50, brand B). discount only on A1 = 20.
SAVEPOINT t_j1;
WITH c AS (
  INSERT INTO public.discount_campaigns (kind, name, percent_off)
  VALUES ('automatic', 'TST brand A 20%', 20) RETURNING id
)
INSERT INTO public.discount_campaign_targets (campaign_id, target_type, target_value, match_mode)
SELECT id, 'brand', 'TST_BRAND_A', 'exact' FROM c;

DO $$
DECLARE r jsonb;
BEGIN
  r := public.quote_order_v1(
    '{}'::jsonb,
    jsonb_build_array(
      jsonb_build_object('variant_id', 'TST-V-A1', 'quantity', 1),
      jsonb_build_object('variant_id', 'TST-V-B1', 'quantity', 1)
    )
  );
  IF (r->>'ok')::boolean IS NOT TRUE THEN RAISE EXCEPTION 'J1 ok=%', r->>'ok'; END IF;
  IF (r->>'subtotal_amount')::numeric(12,2)    <> 150.00 THEN RAISE EXCEPTION 'J1 subtotal: %',    r->>'subtotal_amount'; END IF;
  IF (r->>'discount_amount')::numeric(12,2)    <>  20.00 THEN RAISE EXCEPTION 'J1 discount: %',    r->>'discount_amount'; END IF;
  IF (r->'lines'->0->>'line_discount_amount')::numeric(12,2) <> 20.00 THEN
    RAISE EXCEPTION 'J1 A1 line_discount: %', r->'lines'->0->>'line_discount_amount';
  END IF;
  IF (r->'lines'->1->>'line_discount_amount')::numeric(12,2) <>  0.00 THEN
    RAISE EXCEPTION 'J1 B1 line_discount: %', r->'lines'->1->>'line_discount_amount';
  END IF;
  RAISE NOTICE 'J.1 passed: brand exact target';
END $$;
ROLLBACK TO SAVEPOINT t_j1;

-- J.2 category prefix: 10% off categories starting with 'TST_CATEGORY_X'.
--   cart: A1 (cat X) + B1 (cat Y). discount only on A1 = 10.
SAVEPOINT t_j2;
WITH c AS (
  INSERT INTO public.discount_campaigns (kind, name, percent_off)
  VALUES ('automatic', 'TST cat-X 10%', 10) RETURNING id
)
INSERT INTO public.discount_campaign_targets (campaign_id, target_type, target_value, match_mode)
SELECT id, 'category', 'TST_CATEGORY_X', 'prefix' FROM c;

DO $$
DECLARE r jsonb;
BEGIN
  r := public.quote_order_v1(
    '{}'::jsonb,
    jsonb_build_array(
      jsonb_build_object('variant_id', 'TST-V-A1', 'quantity', 1),
      jsonb_build_object('variant_id', 'TST-V-B1', 'quantity', 1)
    )
  );
  IF (r->>'discount_amount')::numeric(12,2) <> 10.00 THEN
    RAISE EXCEPTION 'J2 discount: %', r->>'discount_amount';
  END IF;
  IF (r->'lines'->0->>'line_discount_amount')::numeric(12,2) <> 10.00 THEN
    RAISE EXCEPTION 'J2 A1 line_discount: %', r->'lines'->0->>'line_discount_amount';
  END IF;
  IF (r->'lines'->1->>'line_discount_amount')::numeric(12,2) <>  0.00 THEN
    RAISE EXCEPTION 'J2 B1 line_discount: %', r->'lines'->1->>'line_discount_amount';
  END IF;
  RAISE NOTICE 'J.2 passed: category prefix target';
END $$;
ROLLBACK TO SAVEPOINT t_j2;

-- J.3 variant_id exact: 30% off TST-V-A1 only.
--   cart: A1 (100) + B1 (50). discount = 30.
SAVEPOINT t_j3;
WITH c AS (
  INSERT INTO public.discount_campaigns (kind, name, percent_off)
  VALUES ('automatic', 'TST V-A1 30%', 30) RETURNING id
)
INSERT INTO public.discount_campaign_targets (campaign_id, target_type, target_value, match_mode)
SELECT id, 'variant_id', 'TST-V-A1', 'exact' FROM c;

DO $$
DECLARE r jsonb;
BEGIN
  r := public.quote_order_v1(
    '{}'::jsonb,
    jsonb_build_array(
      jsonb_build_object('variant_id', 'TST-V-A1', 'quantity', 1),
      jsonb_build_object('variant_id', 'TST-V-B1', 'quantity', 1)
    )
  );
  IF (r->>'discount_amount')::numeric(12,2) <> 30.00 THEN
    RAISE EXCEPTION 'J3 discount: %', r->>'discount_amount';
  END IF;
  IF (r->'lines'->0->>'line_discount_amount')::numeric(12,2) <> 30.00 THEN
    RAISE EXCEPTION 'J3 A1 line_discount: %', r->'lines'->0->>'line_discount_amount';
  END IF;
  IF (r->'lines'->1->>'line_discount_amount')::numeric(12,2) <>  0.00 THEN
    RAISE EXCEPTION 'J3 B1 line_discount: %', r->'lines'->1->>'line_discount_amount';
  END IF;
  RAISE NOTICE 'J.3 passed: variant_id exact target';
END $$;
ROLLBACK TO SAVEPOINT t_j3;

-- ============================================================================
-- K. Best-discount-wins: automatic 20% beats promocode 10%.
--    cart: A1 (100). expected discount=20, promo.status=not_best_discount.
-- ============================================================================
SAVEPOINT t_k;
INSERT INTO public.discount_campaigns (kind, name, percent_off)
VALUES ('automatic', 'TST auto 20%', 20);

INSERT INTO public.discount_campaigns (kind, name, code, percent_off)
VALUES ('promocode', 'TST promo 10%', 'PROMO10', 10);

DO $$
DECLARE r jsonb;
BEGIN
  r := public.quote_order_v1(
    jsonb_build_object('promo_code', 'PROMO10'),
    jsonb_build_array(jsonb_build_object('variant_id', 'TST-V-A1', 'quantity', 1))
  );
  IF (r->'promo'->>'status') <> 'not_best_discount' THEN
    RAISE EXCEPTION 'K status: % (full=%)', r->'promo'->>'status', r;
  END IF;
  IF (r->>'discount_amount')::numeric(12,2) <> 20.00 THEN
    RAISE EXCEPTION 'K discount: %', r->>'discount_amount';
  END IF;
  IF NOT EXISTS (
    SELECT 1 FROM jsonb_array_elements(r->'applied_discounts') ad
    WHERE (ad->>'kind') = 'automatic' AND (ad->>'percent_off')::numeric = 20
  ) THEN
    RAISE EXCEPTION 'K applied_discounts missing automatic 20: %', r->'applied_discounts';
  END IF;
  RAISE NOTICE 'K passed: best-discount-wins (automatic > promo)';
END $$;
ROLLBACK TO SAVEPOINT t_k;

-- ============================================================================
-- L. Promo beats automatic: automatic 5% vs promocode 10%.
--    cart: A1 (100). expected discount=10, promo.status=applied.
-- ============================================================================
SAVEPOINT t_l;
INSERT INTO public.discount_campaigns (kind, name, percent_off)
VALUES ('automatic', 'TST auto 5%', 5);

INSERT INTO public.discount_campaigns (kind, name, code, percent_off)
VALUES ('promocode', 'TST promo 10b%', 'PROMO10B', 10);

DO $$
DECLARE r jsonb;
BEGIN
  r := public.quote_order_v1(
    jsonb_build_object('promo_code', 'PROMO10B'),
    jsonb_build_array(jsonb_build_object('variant_id', 'TST-V-A1', 'quantity', 1))
  );
  IF (r->'promo'->>'status') <> 'applied' THEN
    RAISE EXCEPTION 'L status: % (full=%)', r->'promo'->>'status', r;
  END IF;
  IF (r->>'discount_amount')::numeric(12,2) <> 10.00 THEN
    RAISE EXCEPTION 'L discount: %', r->>'discount_amount';
  END IF;
  RAISE NOTICE 'L passed: promo beats weaker automatic';
END $$;
ROLLBACK TO SAVEPOINT t_l;

-- ============================================================================
-- M. Limit reached.
--    promocode max_redemptions=1, used_count=1.
-- ============================================================================
SAVEPOINT t_m;
INSERT INTO public.discount_campaigns (kind, name, code, percent_off, max_redemptions, used_count)
VALUES ('promocode', 'TST cap 1', 'CAP1', 10, 1, 1);

DO $$
DECLARE r jsonb;
BEGIN
  r := public.quote_order_v1(
    jsonb_build_object('promo_code', 'CAP1'),
    jsonb_build_array(jsonb_build_object('variant_id', 'TST-V-A1', 'quantity', 1))
  );
  IF (r->'promo'->>'status') <> 'limit_reached' THEN
    RAISE EXCEPTION 'M status: % (full=%)', r->'promo'->>'status', r;
  END IF;
  IF (r->>'discount_amount')::numeric(12,2) <> 0.00 THEN
    RAISE EXCEPTION 'M discount: %', r->>'discount_amount';
  END IF;
  RAISE NOTICE 'M passed: limit_reached';
END $$;
ROLLBACK TO SAVEPOINT t_m;

-- ============================================================================
-- N. quote_order_v1 is read-only.
--    Counts of discount_redemptions and used_count of all campaigns must
--    be unchanged after invocation, including for the matched promocode.
-- ============================================================================
SAVEPOINT t_n;
INSERT INTO public.discount_campaigns (kind, name, code, percent_off, used_count)
VALUES ('promocode', 'TST readonly', 'READONLY10', 10, 0);

DO $$
DECLARE
  r              jsonb;
  red_before     bigint;
  red_after      bigint;
  used_before    integer;
  used_after     integer;
BEGIN
  SELECT count(*) INTO red_before FROM public.discount_redemptions;
  SELECT used_count INTO used_before FROM public.discount_campaigns WHERE code = 'READONLY10';

  r := public.quote_order_v1(
    jsonb_build_object('promo_code', 'READONLY10'),
    jsonb_build_array(jsonb_build_object('variant_id', 'TST-V-A1', 'quantity', 1))
  );

  IF (r->'promo'->>'status') <> 'applied' THEN
    RAISE EXCEPTION 'N precondition: status=% (full=%)', r->'promo'->>'status', r;
  END IF;

  SELECT count(*) INTO red_after FROM public.discount_redemptions;
  SELECT used_count INTO used_after FROM public.discount_campaigns WHERE code = 'READONLY10';

  IF red_after <> red_before THEN
    RAISE EXCEPTION 'N redemptions changed: % -> %', red_before, red_after;
  END IF;
  IF used_after <> used_before THEN
    RAISE EXCEPTION 'N used_count changed: % -> %', used_before, used_after;
  END IF;
  RAISE NOTICE 'N passed: quote_order_v1 is read-only';
END $$;
ROLLBACK TO SAVEPOINT t_n;

-- ============================================================================
-- DONE: rollback so the local DB is unchanged.
-- ============================================================================
DO $$ BEGIN RAISE NOTICE 'TESTS PASSED'; END $$;

ROLLBACK;
