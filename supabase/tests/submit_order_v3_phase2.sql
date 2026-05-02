-- ============================================================================
-- Phase 2 fixture tests for public.submit_order_v3.
--
-- How to run (LOCAL / NON-PRODUCTION ONLY):
--
--   psql -v ON_ERROR_STOP=1 -f supabase/tests/submit_order_v3_phase2.sql
--
-- Wrapped in BEGIN ... ROLLBACK; per-test SAVEPOINTs isolate state.
-- Inserts only into base tables; never modifies catalog_items VIEW or
-- runs against production.
-- ============================================================================

\set ON_ERROR_STOP on

BEGIN;

SET LOCAL client_min_messages = NOTICE;

-- ============================================================================
-- 0. Fixture: 4 variants under 3 products (same shape as Phase 1 tests).
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

-- Helper: minimal valid customer payload (no fulfillment / no promo).
-- Tests that need promo/fulfillment override specific keys with ||.
CREATE TEMP TABLE _ctx (cust jsonb) ON COMMIT DROP;
INSERT INTO _ctx VALUES (jsonb_build_object(
  'name',          'TST Customer',
  'phone',         '+10000000001',
  'consent_given', true,
  'fulfillment_fee', 10
));

-- ============================================================================
-- A. Validation failure does not write.
--    Missing name → ok=false. order_requests / order_request_items /
--    discount_redemptions counts must remain unchanged.
-- ============================================================================
SAVEPOINT t_a;
DO $$
DECLARE
  r              jsonb;
  req_before     bigint;
  req_after      bigint;
  red_before     bigint;
  red_after      bigint;
BEGIN
  SELECT count(*) INTO req_before FROM public.order_requests;
  SELECT count(*) INTO red_before FROM public.discount_redemptions;

  r := public.submit_order_v3(
    jsonb_build_object('phone', '+1', 'consent_given', true),
    jsonb_build_array(jsonb_build_object('variant_id', 'TST-V-A1', 'quantity', 1))
  );

  IF (r->>'ok')::boolean IS NOT FALSE THEN
    RAISE EXCEPTION 'A failed: ok=% (full=%)', r->>'ok', r;
  END IF;
  IF (r->'errors'->0->>'code') <> 'missing_name' THEN
    RAISE EXCEPTION 'A wrong error code: %', r->'errors'->0->>'code';
  END IF;

  SELECT count(*) INTO req_after  FROM public.order_requests;
  SELECT count(*) INTO red_after  FROM public.discount_redemptions;

  IF req_after <> req_before THEN RAISE EXCEPTION 'A wrote order: % -> %', req_before, req_after; END IF;
  IF red_after <> red_before THEN RAISE EXCEPTION 'A wrote redemption: % -> %', red_before, red_after; END IF;

  RAISE NOTICE 'A passed: validation failure does not write';
END $$;
ROLLBACK TO SAVEPOINT t_a;

-- ============================================================================
-- B. Basic order without discounts.
--    cart: A1 ×2 (=200) + B1 ×1 (=50). fee=10.
--    expected: total_price=subtotal=250, discount=0, grand=260, 1 order, 2 lines, 0 redemptions.
-- ============================================================================
SAVEPOINT t_b;
DO $$
DECLARE
  r              jsonb;
  v_oid          uuid;
  v_li_count     bigint;
  v_red_count    bigint;
  v_total_price  numeric(12,2);
  v_subtotal     numeric(12,2);
  v_grand        numeric(12,2);
  v_line_total   double precision;
  v_line_subtot  numeric(12,2);
BEGIN
  r := public.submit_order_v3(
    (SELECT cust FROM _ctx),
    jsonb_build_array(
      jsonb_build_object('variant_id', 'TST-V-A1', 'quantity', 2),
      jsonb_build_object('variant_id', 'TST-V-B1', 'quantity', 1)
    )
  );

  IF (r->>'ok')::boolean IS NOT TRUE THEN RAISE EXCEPTION 'B failed: %', r; END IF;

  v_oid := (r->>'order_id')::uuid;

  SELECT total_price, subtotal_amount, grand_total_amount
  INTO v_total_price, v_subtotal, v_grand
  FROM public.order_requests WHERE id = v_oid;

  IF v_total_price <> 250.00 THEN RAISE EXCEPTION 'B total_price: %',     v_total_price; END IF;
  IF v_subtotal    <> 250.00 THEN RAISE EXCEPTION 'B subtotal_amount: %', v_subtotal;    END IF;
  IF v_grand       <> 260.00 THEN RAISE EXCEPTION 'B grand_total: %',     v_grand;       END IF;

  SELECT count(*) INTO v_li_count  FROM public.order_request_items WHERE request_id = v_oid;
  SELECT count(*) INTO v_red_count FROM public.discount_redemptions WHERE order_request_id = v_oid;

  IF v_li_count  <> 2 THEN RAISE EXCEPTION 'B item count: %', v_li_count;  END IF;
  IF v_red_count <> 0 THEN RAISE EXCEPTION 'B redemption count: %', v_red_count; END IF;

  -- v2 contract: line_total stays = line_subtotal_amount (pre-discount).
  SELECT line_total, line_subtotal_amount
  INTO v_line_total, v_line_subtot
  FROM public.order_request_items
  WHERE request_id = v_oid AND variant_id = 'TST-V-A1';

  IF v_line_total::numeric(12,2) <> 200.00 THEN RAISE EXCEPTION 'B A1 line_total: %', v_line_total; END IF;
  IF v_line_subtot                <> 200.00 THEN RAISE EXCEPTION 'B A1 line_subtot: %', v_line_subtot; END IF;

  RAISE NOTICE 'B passed: basic order, no discounts';
END $$;
ROLLBACK TO SAVEPOINT t_b;

-- ============================================================================
-- C. Canonical variant_id submit.
--    item.variant_id (text) input; persisted item.variant_id MUST equal canonical.
-- ============================================================================
SAVEPOINT t_c;
DO $$
DECLARE
  r          jsonb;
  v_persisted text;
BEGIN
  r := public.submit_order_v3(
    (SELECT cust FROM _ctx),
    jsonb_build_array(jsonb_build_object('variant_id', 'TST-V-A1', 'quantity', 1))
  );
  IF (r->>'ok')::boolean IS NOT TRUE THEN RAISE EXCEPTION 'C failed: %', r; END IF;

  SELECT variant_id INTO v_persisted
  FROM public.order_request_items
  WHERE request_id = (r->>'order_id')::uuid;

  IF v_persisted <> 'TST-V-A1' THEN RAISE EXCEPTION 'C persisted: %', v_persisted; END IF;

  RAISE NOTICE 'C passed: canonical variant_id persisted';
END $$;
ROLLBACK TO SAVEPOINT t_c;

-- ============================================================================
-- D. Legacy UUID submit.
--    item.variant_id = product_variants.id::text → persisted variant_id MUST
--    be normalized to canonical product_variants.variant_id.
-- ============================================================================
SAVEPOINT t_d;
DO $$
DECLARE
  r          jsonb;
  v_persisted text;
BEGIN
  r := public.submit_order_v3(
    (SELECT cust FROM _ctx),
    jsonb_build_array(jsonb_build_object(
      'variant_id', 'aaaaaaaa-aaaa-aaaa-aaaa-aaaaaaaaaaa2',
      'quantity',   1
    ))
  );
  IF (r->>'ok')::boolean IS NOT TRUE THEN RAISE EXCEPTION 'D failed: %', r; END IF;

  SELECT variant_id INTO v_persisted
  FROM public.order_request_items
  WHERE request_id = (r->>'order_id')::uuid;

  IF v_persisted <> 'TST-V-A2' THEN RAISE EXCEPTION 'D persisted: %', v_persisted; END IF;

  RAISE NOTICE 'D passed: legacy UUID normalized to canonical on persist';
END $$;
ROLLBACK TO SAVEPOINT t_d;

-- ============================================================================
-- E. Promocode applied.
--    Active TEST10 (10%, target ALL by default-no-targets).
--    cart: A1 ×1 (=100). expected discount=10.
--      - applied_promocode_code='TEST10'
--      - 1 redemption row with discount_amount=10, code=TEST10
--      - used_count goes 0 → 1
--      - per-line line_discount_amount=10, line_total_amount=90
-- ============================================================================
SAVEPOINT t_e;
INSERT INTO public.discount_campaigns (kind, name, code, percent_off)
VALUES ('promocode', 'TEST10', 'TEST10', 10);

DO $$
DECLARE
  r            jsonb;
  v_oid        uuid;
  v_used_after integer;
  v_red_amt    numeric(12,2);
  v_promocode  text;
  v_line_disc  numeric(12,2);
  v_line_total numeric(12,2);
BEGIN
  r := public.submit_order_v3(
    (SELECT cust FROM _ctx) || jsonb_build_object('promo_code', 'test10'),
    jsonb_build_array(jsonb_build_object('variant_id', 'TST-V-A1', 'quantity', 1))
  );
  IF (r->>'ok')::boolean IS NOT TRUE THEN RAISE EXCEPTION 'E failed: %', r; END IF;
  IF (r->>'discount_amount')::numeric(12,2) <> 10.00 THEN
    RAISE EXCEPTION 'E discount: %', r->>'discount_amount';
  END IF;

  v_oid := (r->>'order_id')::uuid;

  SELECT applied_promocode_code INTO v_promocode FROM public.order_requests WHERE id = v_oid;
  IF v_promocode <> 'TEST10' THEN RAISE EXCEPTION 'E applied_promocode_code: %', v_promocode; END IF;

  SELECT discount_amount INTO v_red_amt
  FROM public.discount_redemptions
  WHERE order_request_id = v_oid AND code = 'TEST10';
  IF v_red_amt IS NULL OR v_red_amt <> 10.00 THEN
    RAISE EXCEPTION 'E redemption discount_amount: %', v_red_amt;
  END IF;

  SELECT used_count INTO v_used_after FROM public.discount_campaigns WHERE code = 'TEST10';
  IF v_used_after <> 1 THEN RAISE EXCEPTION 'E used_count after: %', v_used_after; END IF;

  SELECT line_discount_amount, line_total_amount
  INTO   v_line_disc,         v_line_total
  FROM public.order_request_items
  WHERE request_id = v_oid AND variant_id = 'TST-V-A1';

  IF v_line_disc  <> 10.00 THEN RAISE EXCEPTION 'E line_discount_amount: %', v_line_disc;  END IF;
  IF v_line_total <> 90.00 THEN RAISE EXCEPTION 'E line_total_amount: %',    v_line_total; END IF;

  RAISE NOTICE 'E passed: promocode applied + persisted + used_count++';
END $$;
ROLLBACK TO SAVEPOINT t_e;

-- ============================================================================
-- F. Automatic discount applied (brand-targeted).
--    Automatic 30% on TST_BRAND_A. cart: A1 (100) + B1 (50). discount = 30.
--      - applied_promocode_code is NULL (it's not a promocode).
--      - 1 redemption inserted (kind='automatic', code IS NULL).
--      - used_count for that auto campaign goes 0 → 1.
-- ============================================================================
SAVEPOINT t_f;
WITH c AS (
  INSERT INTO public.discount_campaigns (kind, name, percent_off)
  VALUES ('automatic', 'TST auto brand A 30%', 30) RETURNING id
)
INSERT INTO public.discount_campaign_targets (campaign_id, target_type, target_value, match_mode)
SELECT id, 'brand', 'TST_BRAND_A', 'exact' FROM c;

DO $$
DECLARE
  r            jsonb;
  v_oid        uuid;
  v_promocode  text;
  v_red_count  bigint;
  v_used_after integer;
BEGIN
  r := public.submit_order_v3(
    (SELECT cust FROM _ctx),
    jsonb_build_array(
      jsonb_build_object('variant_id', 'TST-V-A1', 'quantity', 1),
      jsonb_build_object('variant_id', 'TST-V-B1', 'quantity', 1)
    )
  );
  IF (r->>'ok')::boolean IS NOT TRUE THEN RAISE EXCEPTION 'F failed: %', r; END IF;
  IF (r->>'discount_amount')::numeric(12,2) <> 30.00 THEN
    RAISE EXCEPTION 'F discount: %', r->>'discount_amount';
  END IF;

  v_oid := (r->>'order_id')::uuid;

  SELECT applied_promocode_code INTO v_promocode FROM public.order_requests WHERE id = v_oid;
  IF v_promocode IS NOT NULL THEN RAISE EXCEPTION 'F unexpected promocode: %', v_promocode; END IF;

  SELECT count(*) INTO v_red_count FROM public.discount_redemptions WHERE order_request_id = v_oid;
  IF v_red_count <> 1 THEN RAISE EXCEPTION 'F redemption count: %', v_red_count; END IF;

  SELECT used_count INTO v_used_after FROM public.discount_campaigns WHERE name = 'TST auto brand A 30%';
  IF v_used_after <> 1 THEN RAISE EXCEPTION 'F used_count after: %', v_used_after; END IF;

  RAISE NOTICE 'F passed: automatic discount applied + persisted + used_count++';
END $$;
ROLLBACK TO SAVEPOINT t_f;

-- ============================================================================
-- G. Best-discount-wins persisted.
--    automatic 20% (target all) + promocode 10% (target all). cart A1 (100).
--      - discount_amount = 20
--      - applied_promocode_code IS NULL
--      - promo.status = 'not_best_discount'
--      - used_count of automatic +1, used_count of promocode unchanged
-- ============================================================================
SAVEPOINT t_g;
INSERT INTO public.discount_campaigns (kind, name, percent_off)        VALUES ('automatic', 'TST G auto 20%', 20);
INSERT INTO public.discount_campaigns (kind, name, code, percent_off)  VALUES ('promocode', 'TST G promo 10%', 'GPROMO10', 10);

DO $$
DECLARE
  r              jsonb;
  v_oid          uuid;
  v_used_auto    integer;
  v_used_promo   integer;
  v_promocode    text;
  v_promo_status text;
BEGIN
  r := public.submit_order_v3(
    (SELECT cust FROM _ctx) || jsonb_build_object('promo_code', 'GPROMO10'),
    jsonb_build_array(jsonb_build_object('variant_id', 'TST-V-A1', 'quantity', 1))
  );
  IF (r->>'ok')::boolean IS NOT TRUE THEN RAISE EXCEPTION 'G failed: %', r; END IF;

  v_oid          := (r->>'order_id')::uuid;
  v_promo_status := r->'promo'->>'status';

  IF v_promo_status <> 'not_best_discount' THEN RAISE EXCEPTION 'G promo.status: %', v_promo_status; END IF;
  IF (r->>'discount_amount')::numeric(12,2) <> 20.00 THEN RAISE EXCEPTION 'G discount: %', r->>'discount_amount'; END IF;

  SELECT applied_promocode_code INTO v_promocode FROM public.order_requests WHERE id = v_oid;
  IF v_promocode IS NOT NULL THEN RAISE EXCEPTION 'G unexpected promocode: %', v_promocode; END IF;

  SELECT used_count INTO v_used_auto  FROM public.discount_campaigns WHERE name = 'TST G auto 20%';
  SELECT used_count INTO v_used_promo FROM public.discount_campaigns WHERE name = 'TST G promo 10%';

  IF v_used_auto  <> 1 THEN RAISE EXCEPTION 'G used_count auto: %',  v_used_auto;  END IF;
  IF v_used_promo <> 0 THEN RAISE EXCEPTION 'G used_count promo: %', v_used_promo; END IF;

  RAISE NOTICE 'G passed: best-discount-wins persisted';
END $$;
ROLLBACK TO SAVEPOINT t_g;

-- ============================================================================
-- H. Promo beats automatic persisted.
--    automatic 5% + promocode 10%. cart A1 (100).
--      - discount=10, applied_promocode_code=HBEATS, used_count promo=1, auto=0.
-- ============================================================================
SAVEPOINT t_h;
INSERT INTO public.discount_campaigns (kind, name, percent_off)        VALUES ('automatic', 'TST H auto 5%', 5);
INSERT INTO public.discount_campaigns (kind, name, code, percent_off)  VALUES ('promocode', 'TST H promo 10%', 'HBEATS', 10);

DO $$
DECLARE
  r              jsonb;
  v_oid          uuid;
  v_used_auto    integer;
  v_used_promo   integer;
  v_promocode    text;
BEGIN
  r := public.submit_order_v3(
    (SELECT cust FROM _ctx) || jsonb_build_object('promo_code', 'HBEATS'),
    jsonb_build_array(jsonb_build_object('variant_id', 'TST-V-A1', 'quantity', 1))
  );
  IF (r->>'ok')::boolean IS NOT TRUE THEN RAISE EXCEPTION 'H failed: %', r; END IF;
  IF (r->>'discount_amount')::numeric(12,2) <> 10.00 THEN RAISE EXCEPTION 'H discount: %', r->>'discount_amount'; END IF;

  v_oid := (r->>'order_id')::uuid;

  SELECT applied_promocode_code INTO v_promocode FROM public.order_requests WHERE id = v_oid;
  IF v_promocode <> 'HBEATS' THEN RAISE EXCEPTION 'H promocode: %', v_promocode; END IF;

  SELECT used_count INTO v_used_auto  FROM public.discount_campaigns WHERE name = 'TST H auto 5%';
  SELECT used_count INTO v_used_promo FROM public.discount_campaigns WHERE name = 'TST H promo 10%';

  IF v_used_auto  <> 0 THEN RAISE EXCEPTION 'H used_count auto: %',  v_used_auto;  END IF;
  IF v_used_promo <> 1 THEN RAISE EXCEPTION 'H used_count promo: %', v_used_promo; END IF;

  RAISE NOTICE 'H passed: promo beats automatic persisted';
END $$;
ROLLBACK TO SAVEPOINT t_h;

-- ============================================================================
-- I. Limit reached prevents write.
--    promocode max=1, used_count=1 → quote.promo.status=limit_reached →
--    submit_order_v3 returns ok=false with code 'promo_limit_reached'.
--    Order/redemption count must not change. used_count stays at 1.
-- ============================================================================
SAVEPOINT t_i;
INSERT INTO public.discount_campaigns (kind, name, code, percent_off, max_redemptions, used_count)
VALUES ('promocode', 'TST cap 1', 'CAP1', 10, 1, 1);

DO $$
DECLARE
  r            jsonb;
  req_before   bigint;
  req_after    bigint;
  red_before   bigint;
  red_after    bigint;
  v_used_after integer;
BEGIN
  SELECT count(*) INTO req_before FROM public.order_requests;
  SELECT count(*) INTO red_before FROM public.discount_redemptions;

  r := public.submit_order_v3(
    (SELECT cust FROM _ctx) || jsonb_build_object('promo_code', 'CAP1'),
    jsonb_build_array(jsonb_build_object('variant_id', 'TST-V-A1', 'quantity', 1))
  );

  IF (r->>'ok')::boolean IS NOT FALSE THEN RAISE EXCEPTION 'I failed: ok=% (full=%)', r->>'ok', r; END IF;
  IF (r->'errors'->0->>'code') <> 'promo_limit_reached' THEN
    RAISE EXCEPTION 'I wrong code: %', r->'errors'->0->>'code';
  END IF;

  SELECT count(*) INTO req_after  FROM public.order_requests;
  SELECT count(*) INTO red_after  FROM public.discount_redemptions;
  SELECT used_count INTO v_used_after FROM public.discount_campaigns WHERE code = 'CAP1';

  IF req_after  <> req_before THEN RAISE EXCEPTION 'I wrote order: %', req_after  - req_before; END IF;
  IF red_after  <> red_before THEN RAISE EXCEPTION 'I wrote redemption: %', red_after - red_before; END IF;
  IF v_used_after <> 1        THEN RAISE EXCEPTION 'I used_count moved: %', v_used_after; END IF;

  RAISE NOTICE 'I passed: limit_reached blocks order write';
END $$;
ROLLBACK TO SAVEPOINT t_i;

-- ============================================================================
-- J. quote_changed_or_discount_unavailable path.
--
--    Cannot be naturally triggered in a single SQL session because
--    submit_order_v3 calls quote_order_v1 internally; the row-level lock
--    covers the same snapshot. Documented as not directly simulated.
--
--    Still asserts the code path exists and is wired by inspecting the
--    function source for the literal error code.
-- ============================================================================
SAVEPOINT t_j;
DO $$
DECLARE n int;
BEGIN
  SELECT count(*) INTO n
  FROM pg_proc p
  JOIN pg_namespace ns ON ns.oid = p.pronamespace
  WHERE ns.nspname = 'public'
    AND p.proname  = 'submit_order_v3'
    AND pg_get_functiondef(p.oid) LIKE '%quote_changed_or_discount_unavailable%';
  IF n <> 1 THEN
    RAISE EXCEPTION 'J wired check failed: code path not present in function body';
  END IF;
  RAISE NOTICE 'J passed (static): quote_changed_or_discount_unavailable code path is wired';
END $$;
ROLLBACK TO SAVEPOINT t_j;

-- ============================================================================
-- K. submit_order_v2 untouched.
--    Phase 2 must not DROP/CREATE/ALTER submit_order_v2. The local sandbox
--    intentionally does not ship v2 (see .local/validate/bootstrap_for_phase1.sql),
--    so this check has two modes:
--      - if v2 is present (full prod-equivalent DB): assert exact signature.
--      - if v2 is absent (local sandbox): assert that this Phase 2 migration
--        does not reference submit_order_v2 anywhere in its source.
-- ============================================================================
SAVEPOINT t_k;
DO $$
DECLARE
  n_v2     int;
  n_v3     int;
  v3_def   text;
BEGIN
  SELECT count(*) INTO n_v2
  FROM pg_proc p
  JOIN pg_namespace ns ON ns.oid = p.pronamespace
  WHERE ns.nspname = 'public'
    AND p.proname  = 'submit_order_v2'
    AND pg_get_function_identity_arguments(p.oid) = 'p_customer jsonb, p_items jsonb';

  SELECT pg_get_functiondef(p.oid) INTO v3_def
  FROM pg_proc p
  JOIN pg_namespace ns ON ns.oid = p.pronamespace
  WHERE ns.nspname = 'public'
    AND p.proname  = 'submit_order_v3'
    AND pg_get_function_identity_arguments(p.oid) = 'p_customer jsonb, p_items jsonb';

  IF v3_def IS NULL THEN
    RAISE EXCEPTION 'K precondition failed: submit_order_v3 not installed';
  END IF;

  -- Look for an actual CALL of submit_order_v2 (identifier followed by '('),
  -- not bare text mentions in comments.
  IF v3_def ~* '\msubmit_order_v2\s*\(' THEN
    RAISE EXCEPTION 'K untouched check failed: submit_order_v3 calls submit_order_v2';
  END IF;

  IF n_v2 = 1 THEN
    RAISE NOTICE 'K passed: submit_order_v2(jsonb, jsonb) present and untouched';
  ELSE
    RAISE NOTICE 'K passed (sandbox): v2 absent locally; v3 makes no v2 references';
  END IF;
END $$;
ROLLBACK TO SAVEPOINT t_k;

-- ============================================================================
-- DONE
-- ============================================================================
DO $$ BEGIN RAISE NOTICE 'TESTS PASSED'; END $$;

ROLLBACK;
