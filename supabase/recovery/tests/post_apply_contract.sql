-- Run after 0001..0009 on a Supabase database (auth schema and roles required).
-- DML is rolled back. Schema is not modified.
-- psql "$LOCAL_DB_URL" -v ON_ERROR_STOP=1 -f supabase/recovery/tests/post_apply_contract.sql

BEGIN;

DO $$
DECLARE
  v_type text;
  v_count int;
BEGIN
  SELECT c.data_type INTO v_type
  FROM information_schema.columns c
  WHERE c.table_schema = 'public'
    AND c.table_name = 'order_request_items'
    AND c.column_name = 'product_id';
  IF v_type IS DISTINCT FROM 'uuid' THEN
    RAISE EXCEPTION 'order_request_items.product_id type is %, expected uuid', v_type;
  END IF;

  SELECT c.data_type INTO v_type
  FROM information_schema.columns c
  WHERE c.table_schema = 'public'
    AND c.table_name = 'product_variants'
    AND c.column_name = 'variant_id';
  IF v_type IS DISTINCT FROM 'text' THEN
    RAISE EXCEPTION 'product_variants.variant_id type is %, expected text', v_type;
  END IF;

  SELECT c.udt_name INTO v_type
  FROM information_schema.columns c
  WHERE c.table_schema = 'public'
    AND c.table_name = 'product_variants'
    AND c.column_name = 'price';
  IF v_type IS DISTINCT FROM 'numeric' THEN
    RAISE EXCEPTION 'product_variants.price type is %, expected numeric', v_type;
  END IF;

  SELECT c.data_type INTO v_type
  FROM information_schema.columns c
  WHERE c.table_schema = 'public'
    AND c.table_name = 'product_variants'
    AND c.column_name = 'quantity';
  IF v_type IS DISTINCT FROM 'integer' THEN
    RAISE EXCEPTION 'product_variants.quantity type is %, expected integer', v_type;
  END IF;

  PERFORM 1
  FROM information_schema.views
  WHERE table_schema = 'public' AND table_name = 'catalog_items';
  IF NOT FOUND THEN
    RAISE EXCEPTION 'catalog_items view missing';
  END IF;

  PERFORM 1 FROM pg_proc p
  JOIN pg_namespace n ON n.oid = p.pronamespace
  WHERE n.nspname = 'public' AND p.proname = 'submit_order_v3';
  IF NOT FOUND THEN
    RAISE EXCEPTION 'submit_order_v3 missing';
  END IF;

  IF to_regprocedure('public.submit_order_v2(jsonb, jsonb)') IS NULL THEN
    RAISE EXCEPTION 'submit_order_v2(jsonb, jsonb) missing';
  END IF;
  IF to_regprocedure('public.quote_order_v1(jsonb, jsonb)') IS NULL THEN
    RAISE EXCEPTION 'quote_order_v1(jsonb, jsonb) missing';
  END IF;
  IF to_regprocedure('public.admin_upsert_native_product(jsonb)') IS NULL THEN
    RAISE EXCEPTION 'admin_upsert_native_product(jsonb) missing';
  END IF;
  IF to_regprocedure('public.is_admin()') IS NULL THEN
    RAISE EXCEPTION 'is_admin() missing';
  END IF;

  SELECT count(*) INTO v_count
  FROM pg_policies
  WHERE schemaname = 'public'
    AND tablename = 'order_requests'
    AND cmd = 'INSERT';
  IF v_count <> 0 THEN
    RAISE EXCEPTION 'order_requests has % INSERT policies; expected 0', v_count;
  END IF;

  SELECT count(*) INTO v_count
  FROM pg_policies
  WHERE schemaname = 'public'
    AND tablename = 'products'
    AND cmd = 'INSERT'
    AND 'anon' = ANY (roles);
  IF v_count <> 0 THEN
    RAISE EXCEPTION 'anon can insert products by policy';
  END IF;

  PERFORM 1
  FROM information_schema.role_table_grants
  WHERE grantee = 'anon'
    AND table_schema = 'public'
    AND table_name = 'products';
  IF FOUND THEN
    RAISE EXCEPTION 'anon still has a table grant on products';
  END IF;

  PERFORM 1
  FROM information_schema.role_table_grants
  WHERE grantee = 'anon'
    AND table_schema = 'public'
    AND table_name = 'order_requests'
    AND privilege_type = 'INSERT';
  IF FOUND THEN
    RAISE EXCEPTION 'anon has INSERT on order_requests';
  END IF;

  PERFORM 1
  FROM information_schema.role_table_grants
  WHERE grantee = 'anon'
    AND table_schema = 'public'
    AND table_name = 'catalog_items'
    AND privilege_type = 'SELECT';
  IF NOT FOUND THEN
    RAISE EXCEPTION 'anon cannot select catalog_items';
  END IF;

  IF has_function_privilege('anon', 'public.submit_order_v3(jsonb, jsonb)', 'EXECUTE') IS NOT TRUE THEN
    RAISE EXCEPTION 'anon cannot execute submit_order_v3';
  END IF;
  IF has_function_privilege('anon', 'public.admin_upsert_native_product(jsonb)', 'EXECUTE') IS TRUE THEN
    RAISE EXCEPTION 'anon can execute admin_upsert_native_product';
  END IF;
  IF has_function_privilege('anon', 'public._discount_text_match(text, text, text)', 'EXECUTE') IS TRUE THEN
    RAISE EXCEPTION 'anon can execute _discount_text_match';
  END IF;
  IF has_function_privilege('anon', 'public.product_is_publicly_visible(uuid)', 'EXECUTE') IS NOT TRUE THEN
    RAISE EXCEPTION 'anon cannot execute product_is_publicly_visible';
  END IF;
  IF has_function_privilege('authenticated', 'public.is_admin()', 'EXECUTE') IS NOT TRUE THEN
    RAISE EXCEPTION 'authenticated cannot execute is_admin';
  END IF;

  IF to_regnamespace('cron') IS NOT NULL THEN
    IF EXISTS (
      SELECT 1 FROM cron.job
      WHERE jobname = 'catalog-sync-every-10min'
         OR command ILIKE '%catalog-sync%'
    ) THEN
      RAISE EXCEPTION 'legacy catalog-sync cron job is present';
    END IF;
  END IF;
END $$;

-- Catalog contract and hidden-product behavior. Rolled back with the transaction.
INSERT INTO public.products (title, brand, is_active, app_is_visible, tilda_uid)
VALUES ('Visible', 'Brand A', true, true, '1001');

INSERT INTO public.products (title, is_active, app_is_visible, tilda_uid)
VALUES ('Hidden by admin', true, false, NULL);

INSERT INTO public.products (title, tilda_uid)
VALUES ('Second native', NULL);

INSERT INTO public.product_variants (product_id, variant_id, price, quantity)
SELECT id, '1001', 10, 2 FROM public.products WHERE title = 'Visible';

INSERT INTO public.product_variants (product_id, variant_id, price, quantity)
SELECT id, 'admin_static_test', 5, 1 FROM public.products WHERE title = 'Hidden by admin';

INSERT INTO public.product_images (product_id, url, position)
SELECT id, 'https://example.test/recovery-visible.jpg', 0
FROM public.products WHERE title = 'Visible';

INSERT INTO public.product_images (product_id, url, position)
SELECT id, 'https://example.test/recovery-hidden.jpg', 0
FROM public.products WHERE title = 'Hidden by admin';

DO $$
BEGIN
  IF (
    SELECT is_active FROM public.catalog_items WHERE variant_id = '1001'
  ) IS NOT TRUE THEN
    RAISE EXCEPTION 'visible variant is not active in catalog_items';
  END IF;
  IF NOT EXISTS (
    SELECT 1 FROM public.catalog_items WHERE variant_id = 'admin_static_test'
  ) THEN
    NULL;
  ELSE
    RAISE EXCEPTION 'hidden product is still exposed by catalog_items';
  END IF;
  IF (
    SELECT product_id FROM public.catalog_items WHERE variant_id = '1001'
  ) !~* '^[0-9a-f-]{36}$' THEN
    RAISE EXCEPTION 'catalog_items.product_id is not a uuid string';
  END IF;
  IF (
    SELECT legacy_variant_uuid FROM public.catalog_items WHERE variant_id = '1001'
  ) IS NULL THEN
    RAISE EXCEPTION 'legacy_variant_uuid missing';
  END IF;
END $$;

-- Duplicate canonical variant_id must fail.
DO $$
BEGIN
  INSERT INTO public.product_variants (product_id, variant_id)
  SELECT id, '1001' FROM public.products WHERE title = 'Second native';
  RAISE EXCEPTION 'duplicate variant_id was accepted';
EXCEPTION
  WHEN unique_violation THEN
    NULL;
END $$;

-- Public gallery: anon sees only images of visible products.
DO $$
DECLARE
  v_visible int;
  v_hidden int;
BEGIN
  IF NOT EXISTS (SELECT 1 FROM pg_roles WHERE rolname = 'anon') THEN
    RAISE EXCEPTION 'anon role is required for gallery RLS test';
  END IF;

  EXECUTE 'SET LOCAL ROLE anon';
  SELECT count(*) INTO v_visible
  FROM public.product_images
  WHERE url = 'https://example.test/recovery-visible.jpg';
  SELECT count(*) INTO v_hidden
  FROM public.product_images
  WHERE url = 'https://example.test/recovery-hidden.jpg';
  IF v_visible <> 1 OR v_hidden <> 0 THEN
    RAISE EXCEPTION 'anon image visibility visible=% hidden=%', v_visible, v_hidden;
  END IF;

  BEGIN
    PERFORM 1 FROM public.products LIMIT 1;
    RAISE EXCEPTION 'anon can read public.products';
  EXCEPTION
    WHEN insufficient_privilege THEN
      NULL;
  END;
  EXECUTE 'RESET ROLE';
END $$;

-- Legacy uuid still resolves. Hidden variant is rejected as unknown.
DO $$
DECLARE
  v_legacy text;
  v_quote jsonb;
BEGIN
  SELECT id::text INTO v_legacy
  FROM public.product_variants
  WHERE variant_id = '1001';

  v_quote := public.quote_order_v1(
    '{"name":"Guest","phone":"+373000000","consent_given":true,"fulfillment_type":"pickup","fulfillment_method_code":"pickup_store","fulfillment_fee":0,"pickup_store_id":"store-1"}'::jsonb,
    jsonb_build_array(jsonb_build_object('variant_id', v_legacy, 'quantity', 2))
  );
  IF (v_quote->>'ok')::boolean IS NOT TRUE THEN
    RAISE EXCEPTION 'legacy variant quote failed: %', v_quote;
  END IF;
  IF (v_quote->>'subtotal_amount')::numeric <> 20.00 THEN
    RAISE EXCEPTION 'unexpected subtotal: %', v_quote->>'subtotal_amount';
  END IF;

  v_quote := public.quote_order_v1(
    '{"name":"Guest","phone":"+373000000","consent_given":true,"fulfillment_type":"pickup","fulfillment_method_code":"pickup_store","fulfillment_fee":0,"pickup_store_id":"store-1"}'::jsonb,
    jsonb_build_array(jsonb_build_object('variant_id', 'admin_static_test', 'quantity', 1))
  );
  IF v_quote->'errors'->0->>'code' IS DISTINCT FROM 'unknown_variant' THEN
    RAISE EXCEPTION 'hidden variant was not rejected: %', v_quote;
  END IF;
END $$;

-- Known methods use the server fee. A client cannot buy a paid method for 0.
DO $$
DECLARE
  v_quote jsonb;
  v_submit jsonb;
  v_order uuid;
  v_fee double precision;
BEGIN
  v_quote := public.quote_order_v1(
    '{"name":"Guest","phone":"+373000000","consent_given":true,"fulfillment_type":"pickup","fulfillment_method_code":"pickup_store","fulfillment_fee":0}'::jsonb,
    '[{"variant_id":"1001","quantity":1}]'::jsonb
  );
  IF (v_quote->>'ok')::boolean IS NOT TRUE
     OR (v_quote->>'fulfillment_fee')::numeric <> 0
     OR (v_quote->>'grand_total_amount')::numeric <> 10 THEN
    RAISE EXCEPTION 'pickup quote fee: %', v_quote;
  END IF;

  v_quote := public.quote_order_v1(
    '{"name":"Guest","phone":"+373000000","consent_given":true,"fulfillment_type":"delivery","fulfillment_method_code":"courier_tiraspol","fulfillment_fee":50}'::jsonb,
    '[{"variant_id":"1001","quantity":1}]'::jsonb
  );
  IF (v_quote->>'ok')::boolean IS NOT TRUE
     OR (v_quote->>'fulfillment_fee')::numeric <> 50
     OR (v_quote->>'grand_total_amount')::numeric <> 60 THEN
    RAISE EXCEPTION 'courier quote fee: %', v_quote;
  END IF;

  v_quote := public.quote_order_v1(
    '{"name":"Guest","phone":"+373000000","consent_given":true,"fulfillment_type":"delivery","fulfillment_method_code":"courier_tiraspol","fulfillment_fee":0}'::jsonb,
    '[{"variant_id":"1001","quantity":1}]'::jsonb
  );
  IF v_quote->'errors'->0->>'code' IS DISTINCT FROM 'fulfillment_fee_mismatch' THEN
    RAISE EXCEPTION 'zero fee was not rejected: %', v_quote;
  END IF;

  v_quote := public.quote_order_v1(
    '{"name":"Guest","phone":"+373000000","consent_given":true,"fulfillment_type":"delivery","fulfillment_method_code":"courier_tiraspol","fulfillment_fee":-1}'::jsonb,
    '[{"variant_id":"1001","quantity":1}]'::jsonb
  );
  IF v_quote->'errors'->0->>'code' IS DISTINCT FROM 'invalid_fulfillment_fee' THEN
    RAISE EXCEPTION 'negative fee was not rejected: %', v_quote;
  END IF;

  v_quote := public.quote_order_v1(
    '{"name":"Guest","phone":"+373000000","consent_given":true,"fulfillment_type":"delivery","fulfillment_method_code":"courier_tiraspol"}'::jsonb,
    '[{"variant_id":"1001","quantity":1}]'::jsonb
  );
  IF (v_quote->>'ok')::boolean IS NOT TRUE
     OR (v_quote->>'fulfillment_fee')::numeric <> 50 THEN
    RAISE EXCEPTION 'missing fee was not filled from the method: %', v_quote;
  END IF;

  v_submit := public.submit_order_v3(
    '{"name":"Guest","phone":"+373000000","consent_given":true,"fulfillment_type":"pickup","fulfillment_method_code":"courier_tiraspol","fulfillment_fee":50,"pickup_store_id":"store-1"}'::jsonb,
    '[{"variant_id":"1001","quantity":1}]'::jsonb
  );
  IF v_submit->'errors'->0->>'code' IS DISTINCT FROM 'invalid_fulfillment_method_code' THEN
    RAISE EXCEPTION 'method/type mismatch was not rejected: %', v_submit;
  END IF;

  v_quote := public.quote_order_v1(
    '{"name":"Guest","phone":"+373000000","consent_given":true,"fulfillment_type":"delivery","fulfillment_method_code":"courier_bender","fulfillment_fee":40,"delivery_zone_code":"bender","delivery_address":"ул. Тест 1","delivery_method":"Доставка курьером по Бендерам","payment_method":"Наличные","payment_method_code":"cash"}'::jsonb,
    '[{"variant_id":"1001","quantity":1}]'::jsonb
  );
  v_submit := public.submit_order_v3(
    '{"name":"Guest","phone":"+373000000","consent_given":true,"fulfillment_type":"delivery","fulfillment_method_code":"courier_bender","fulfillment_fee":40,"delivery_zone_code":"bender","delivery_address":"ул. Тест 1","delivery_method":"Доставка курьером по Бендерам","payment_method":"Наличные","payment_method_code":"cash"}'::jsonb,
    '[{"variant_id":"1001","quantity":1}]'::jsonb
  );
  IF (v_quote->>'ok')::boolean IS NOT TRUE OR (v_submit->>'ok')::boolean IS NOT TRUE THEN
    RAISE EXCEPTION 'legitimate checkout failed quote=% submit=%', v_quote, v_submit;
  END IF;
  IF (v_quote->>'fulfillment_fee')::numeric
     IS DISTINCT FROM (v_submit->>'fulfillment_fee')::numeric THEN
    RAISE EXCEPTION 'quote/submit fee diverge quote=% submit=%', v_quote->>'fulfillment_fee', v_submit->>'fulfillment_fee';
  END IF;
  IF (v_quote->>'grand_total_amount')::numeric
     IS DISTINCT FROM (v_submit->>'grand_total_amount')::numeric THEN
    RAISE EXCEPTION 'quote/submit total diverge';
  END IF;
  v_order := (v_submit->>'order_id')::uuid;
  SELECT fulfillment_fee INTO v_fee FROM public.order_requests WHERE id = v_order;
  IF v_fee IS DISTINCT FROM 40 THEN
    RAISE EXCEPTION 'stored fulfillment_fee %', v_fee;
  END IF;

  v_quote := public.quote_order_v1(
    '{"name":"Guest","phone":"+373000000","consent_given":true,"fulfillment_fee":0}'::jsonb,
    '[{"variant_id":"1001","quantity":1}]'::jsonb
  );
  IF v_quote->'errors'->0->>'code' IS DISTINCT FROM 'invalid_fulfillment_method_code' THEN
    RAISE EXCEPTION 'quote without a method was accepted: %', v_quote;
  END IF;

  v_submit := public.submit_order_v3(
    '{"name":"Guest","phone":"+373000000","consent_given":true,"fulfillment_type":"delivery","fulfillment_fee":0,"delivery_zone_code":"tiraspol","delivery_address":"ул. Тест 1"}'::jsonb,
    '[{"variant_id":"1001","quantity":1}]'::jsonb
  );
  IF v_submit->'errors'->0->>'code' IS DISTINCT FROM 'invalid_fulfillment_method_code'
     OR (v_submit->>'ok')::boolean IS TRUE THEN
    RAISE EXCEPTION 'submit without a method was accepted: %', v_submit;
  END IF;

  v_submit := public.submit_order_v3(
    '{"name":"Guest","phone":"+373000000","consent_given":true,"fulfillment_type":"pickup","fulfillment_method_code":"","fulfillment_fee":0,"pickup_store_id":"store-1"}'::jsonb,
    '[{"variant_id":"1001","quantity":1}]'::jsonb
  );
  IF v_submit->'errors'->0->>'code' IS DISTINCT FROM 'invalid_fulfillment_method_code' THEN
    RAISE EXCEPTION 'empty method was accepted: %', v_submit;
  END IF;

  BEGIN
    PERFORM public.submit_order_v2(
      '{"name":"Guest","phone":"+373000000","consent_given":true,"fulfillment_type":"delivery","fulfillment_fee":0,"delivery_zone_code":"express","delivery_address":"ул. Тест 1"}'::jsonb,
      '[{"variant_id":"1001","quantity":1}]'::jsonb
    );
    RAISE EXCEPTION 'v2 accepted an order without a method';
  EXCEPTION
    WHEN OTHERS THEN
      IF SQLERRM NOT ILIKE '%fulfillment_method_code is required%' THEN
        RAISE EXCEPTION 'unexpected v2 missing-method error: %', SQLERRM;
      END IF;
  END;

  BEGIN
    PERFORM public.submit_order_v2(
      '{"name":"Guest","phone":"+373000000","consent_given":true,"fulfillment_type":"delivery","fulfillment_method_code":"express_post","fulfillment_fee":0,"delivery_zone_code":"express","delivery_address":"ул. Тест 1"}'::jsonb,
      '[{"variant_id":"1001","quantity":1}]'::jsonb
    );
    RAISE EXCEPTION 'v2 accepted a zero delivery fee';
  EXCEPTION
    WHEN OTHERS THEN
      IF SQLERRM NOT ILIKE '%fulfillment_fee_mismatch%' THEN
        RAISE EXCEPTION 'unexpected v2 fee error: %', SQLERRM;
      END IF;
  END;
END $$;

-- admin_users SELECT must not recurse. Non-admins see no rows. Anon has no grant.
DO $$
DECLARE
  v_rows int;
BEGIN
  PERFORM set_config('request.jwt.claim.sub', '44444444-4444-4444-4444-444444444444', true);
  PERFORM set_config(
    'request.jwt.claims',
    '{"role":"authenticated","sub":"44444444-4444-4444-4444-444444444444"}',
    true
  );
  IF auth.uid() IS NULL THEN
    RAISE EXCEPTION 'auth.uid() is not driven by request.jwt settings';
  END IF;
  EXECUTE 'SET LOCAL ROLE authenticated';
  SELECT count(*) INTO v_rows FROM public.admin_users;
  IF v_rows <> 0 THEN
    RAISE EXCEPTION 'non-admin read % admin_users rows', v_rows;
  END IF;
  IF public.is_admin() THEN
    RAISE EXCEPTION 'is_admin() is true for a non-admin';
  END IF;
  EXECUTE 'RESET ROLE';

  EXECUTE 'SET LOCAL ROLE anon';
  BEGIN
    PERFORM 1 FROM public.admin_users;
    RAISE EXCEPTION 'anon read admin_users';
  EXCEPTION
    WHEN insufficient_privilege THEN
      NULL;
  END;
  BEGIN
    PERFORM public.is_admin();
    RAISE EXCEPTION 'anon executed is_admin()';
  EXCEPTION
    WHEN insufficient_privilege THEN
      NULL;
  END;
  EXECUTE 'RESET ROLE';
  PERFORM set_config('request.jwt.claim.sub', '', true);
  PERFORM set_config('request.jwt.claims', '', true);
END $$;

-- 10% automatic campaign with no targets applies to every visible line.
DO $$
DECLARE
  v_quote jsonb;
BEGIN
  INSERT INTO public.discount_campaigns (kind, name, percent_off)
  VALUES ('automatic', 'recovery 10', 10);

  v_quote := public.quote_order_v1(
    '{"name":"Guest","phone":"+373000000","consent_given":true,"fulfillment_type":"pickup","fulfillment_method_code":"pickup_store","fulfillment_fee":0,"pickup_store_id":"store-1"}'::jsonb,
    '[{"variant_id":"1001","quantity":2}]'::jsonb
  );
  IF (v_quote->>'ok')::boolean IS NOT TRUE
     OR (v_quote->>'discount_amount')::numeric <> 2.00
     OR (v_quote->>'subtotal_amount')::numeric <> 20.00 THEN
    RAISE EXCEPTION 'discount quote mismatch: %', v_quote;
  END IF;
END $$;

-- Guest checkout succeeds. A supplied user_id is rejected and writes nothing.
DO $$
DECLARE
  v_result jsonb;
  v_order uuid;
BEGIN
  v_result := public.submit_order_v3(
    '{"name":"Guest","phone":"+373000000","consent_given":true,"user_id":"11111111-1111-1111-1111-111111111111","fulfillment_type":"pickup","fulfillment_method_code":"pickup_store","fulfillment_fee":0,"pickup_store_id":"store-1"}'::jsonb,
    '[{"variant_id":"1001","quantity":1}]'::jsonb
  );
  IF v_result->'errors'->0->>'code' IS DISTINCT FROM 'user_id_not_allowed' THEN
    RAISE EXCEPTION 'forged guest user_id was not rejected: %', v_result;
  END IF;

  v_result := public.submit_order_v3(
    '{"name":"Guest","phone":"+373000000","consent_given":true,"fulfillment_type":"pickup","fulfillment_method_code":"pickup_store","fulfillment_fee":0,"pickup_store_id":"store-1"}'::jsonb,
    '[{"variant_id":"1001","quantity":1}]'::jsonb
  );
  IF (v_result->>'ok')::boolean IS NOT TRUE THEN
    RAISE EXCEPTION 'guest checkout failed: %', v_result;
  END IF;
  v_order := (v_result->>'order_id')::uuid;
  IF (SELECT user_id FROM public.order_requests WHERE id = v_order) IS NOT NULL THEN
    RAISE EXCEPTION 'guest order stored a user_id';
  END IF;
  IF (SELECT price FROM public.order_request_items WHERE request_id = v_order) <> 10.00 THEN
    RAISE EXCEPTION 'order line price was not numeric 10.00';
  END IF;
END $$;

-- Authenticated caller cannot stamp another user's id when auth.uid() is visible.
DO $$
DECLARE
  v_result jsonb;
  v_uid uuid := '22222222-2222-2222-2222-222222222222';
BEGIN
  PERFORM set_config('request.jwt.claim.sub', v_uid::text, true);
  PERFORM set_config(
    'request.jwt.claims',
    jsonb_build_object('sub', v_uid)::text,
    true
  );
  IF auth.uid() IS NULL THEN
    RAISE EXCEPTION 'auth.uid() is not driven by request.jwt settings';
  END IF;
  IF auth.uid() IS DISTINCT FROM v_uid THEN
    RAISE EXCEPTION 'auth.uid() ignored the test jwt';
  END IF;

  v_result := public.submit_order_v3(
    jsonb_build_object(
      'name', 'Signed in',
      'phone', '+373000000',
      'consent_given', true,
      'user_id', '33333333-3333-3333-3333-333333333333',
      'fulfillment_type', 'pickup',
      'fulfillment_method_code', 'pickup_store',
      'fulfillment_fee', 0,
      'pickup_store_id', 'store-1'
    ),
    '[{"variant_id":"1001","quantity":1}]'::jsonb
  );
  IF v_result->'errors'->0->>'code' IS DISTINCT FROM 'user_id_mismatch' THEN
    RAISE EXCEPTION 'mismatched user_id was not rejected: %', v_result;
  END IF;
END $$;

-- Non-admin RPC must fail closed without inventing an Auth user.
DO $$
BEGIN
  PERFORM public.admin_upsert_native_product('{"title":"x","price":1}'::jsonb);
  RAISE EXCEPTION 'admin_upsert_native_product succeeded without an admin';
EXCEPTION
  WHEN insufficient_privilege THEN
    RAISE EXCEPTION 'admin_upsert_native_product is not executable by the migration role: %', SQLERRM;
  WHEN OTHERS THEN
    IF SQLERRM NOT ILIKE '%Admin access required%' THEN
      RAISE EXCEPTION 'unexpected admin_upsert error: %', SQLERRM;
    END IF;
END $$;

-- Anonymous callers cannot execute admin RPCs.
-- An authenticated non-admin can execute them and is rejected inside.
DO $$
BEGIN
  EXECUTE 'SET LOCAL ROLE anon';
  BEGIN
    PERFORM public.admin_upsert_native_product('{"title":"x","price":1}'::jsonb);
    RAISE EXCEPTION 'anon executed admin_upsert_native_product';
  EXCEPTION
    WHEN insufficient_privilege THEN
      NULL;
  END;

  EXECUTE 'SET LOCAL ROLE authenticated';
  BEGIN
    PERFORM public.admin_upsert_native_product('{"title":"x","price":1}'::jsonb);
    RAISE EXCEPTION 'authenticated non-admin created a product';
  EXCEPTION
    WHEN OTHERS THEN
      IF SQLERRM NOT ILIKE '%Admin access required%' THEN
        RAISE EXCEPTION 'unexpected authenticated admin_upsert error: %', SQLERRM;
      END IF;
  END;
  EXECUTE 'RESET ROLE';
END $$;

ROLLBACK;
