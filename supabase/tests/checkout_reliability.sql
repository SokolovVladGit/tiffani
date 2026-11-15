-- Local-only checkout reliability checks.
-- Requires recovery 0001-0008, the notification outbox, and
-- 20261115193000_checkout_reliability.sql.
-- The transaction rolls back. It does not touch a hosted database.

\set ON_ERROR_STOP on

BEGIN;

INSERT INTO public.products (id, tilda_uid, title, brand, category, mark, is_active)
VALUES (
  '11111111-1111-4111-8111-111111111111',
  NULL,
  'TST Product A',
  'TST_BRAND_A',
  'TST_CATEGORY_X',
  'NEW',
  true
);

INSERT INTO public.product_variants (id, product_id, variant_id, price)
VALUES (
  'aaaaaaaa-aaaa-4aaa-8aaa-aaaaaaaaaaa1',
  '11111111-1111-4111-8111-111111111111',
  'TST-V-A1',
  100.00
);

INSERT INTO public.discount_campaigns (id, kind, name, percent_off, is_active)
VALUES (
  'bbbbbbbb-bbbb-4bbb-8bbb-bbbbbbbbbbb1',
  'automatic',
  'TST 10',
  10,
  true
);

INSERT INTO public.discount_campaign_targets (campaign_id, target_type, target_value)
VALUES (
  'bbbbbbbb-bbbb-4bbb-8bbb-bbbbbbbbbbb1',
  'all',
  NULL
);

INSERT INTO auth.users (id)
VALUES
  ('11111111-2222-4333-8444-555555555551'),
  ('11111111-2222-4333-8444-555555555552');

DO $$
BEGIN
  IF public.checkout_phone_is_valid('+37312345678') IS NOT TRUE THEN
    RAISE EXCEPTION 'moldova number rejected';
  END IF;
  IF public.checkout_phone_is_valid('12345678') IS NOT TRUE THEN
    RAISE EXCEPTION '8 digit number rejected';
  END IF;
  IF public.checkout_phone_is_valid('+12025550123') IS NOT TRUE THEN
    RAISE EXCEPTION 'international number rejected';
  END IF;
  IF public.checkout_phone_is_valid('+373 (12) 345-678') IS NOT TRUE THEN
    RAISE EXCEPTION 'separators rejected';
  END IF;
  IF public.checkout_phone_is_valid('123456789012345') IS NOT TRUE THEN
    RAISE EXCEPTION '15 digits rejected';
  END IF;
  IF public.checkout_phone_is_valid('') IS TRUE
     OR public.checkout_phone_is_valid(NULL) IS TRUE THEN
    RAISE EXCEPTION 'empty phone accepted';
  END IF;
  IF public.checkout_phone_is_valid('abc12345678') IS TRUE THEN
    RAISE EXCEPTION 'letters accepted';
  END IF;
  IF public.checkout_phone_is_valid('++37312345678') IS TRUE
     OR public.checkout_phone_is_valid('373+12345678') IS TRUE THEN
    RAISE EXCEPTION 'bad plus accepted';
  END IF;
  IF public.checkout_phone_is_valid('++--()') IS TRUE THEN
    RAISE EXCEPTION 'punctuation accepted';
  END IF;
  IF public.checkout_phone_is_valid('1234567') IS TRUE
     OR public.checkout_phone_is_valid('1234567890123456') IS TRUE
     OR public.checkout_phone_is_valid('1234567890123456789') IS TRUE THEN
    RAISE EXCEPTION 'digit bounds failed';
  END IF;
END $$;

DO $$
BEGIN
  BEGIN
    INSERT INTO public.order_requests (customer_name, phone)
    VALUES ('Bad', '1234567890123456789');
    RAISE EXCEPTION '19 digit insert was accepted';
  EXCEPTION
    WHEN check_violation THEN
      NULL;
  END;

  BEGIN
    INSERT INTO public.order_requests (customer_name, phone)
    VALUES ('Bad', 'abc');
    RAISE EXCEPTION 'alphabetic insert was accepted';
  EXCEPTION
    WHEN check_violation THEN
      NULL;
  END;

  BEGIN
    INSERT INTO public.order_requests (customer_name, phone)
    VALUES ('Bad', '++--()');
    RAISE EXCEPTION 'punctuation insert was accepted';
  EXCEPTION
    WHEN check_violation THEN
      NULL;
  END;

  BEGIN
    PERFORM public.submit_order_v3(
      jsonb_build_object(
        'name', 'Анна',
        'phone', 'abc12345678',
        'consent_given', true,
        'fulfillment_type', 'pickup',
        'pickup_store_id', 'store_central',
        'fulfillment_method_code', 'pickup_store',
        'fulfillment_fee', 0,
        'payment_method_code', 'cash'
      ),
      jsonb_build_array(jsonb_build_object('variant_id', 'TST-V-A1', 'quantity', 1))
    );
    RAISE EXCEPTION 'v3 accepted an alphabetic phone';
  EXCEPTION
    WHEN check_violation THEN
      NULL;
  END;
END $$;

ALTER TABLE public.order_requests DISABLE TRIGGER order_requests_reject_invalid_phone;
INSERT INTO public.order_requests (id, customer_name, phone)
VALUES (
  'b1f40755-1111-4111-8111-111111111111',
  'Historical',
  '1234567890123456789'
);
ALTER TABLE public.order_requests ENABLE TRIGGER order_requests_reject_invalid_phone;

UPDATE public.order_requests
SET status = 'new'
WHERE id = 'b1f40755-1111-4111-8111-111111111111';

DO $$
DECLARE
  v_customer jsonb := jsonb_build_object(
    'name', 'Анна',
    'phone', '+373 (12) 345-678',
    'consent_given', true,
    'fulfillment_type', 'pickup',
    'pickup_store_id', 'store_central',
    'fulfillment_method_code', 'pickup_store',
    'fulfillment_fee', 0,
    'payment_method_code', 'cash'
  );
  v_items jsonb := jsonb_build_array(jsonb_build_object(
    'variant_id', 'TST-V-A1',
    'quantity', 1
  ));
  v_request uuid := 'aaaaaaaa-aaaa-4aaa-8aaa-aaaaaaaaaa01';
  v_other uuid := 'aaaaaaaa-aaaa-4aaa-8aaa-aaaaaaaaaa02';
  v_guest uuid := 'aaaaaaaa-aaaa-4aaa-8aaa-aaaaaaaaaa03';
  v_first jsonb;
  v_replay jsonb;
  v_conflict jsonb;
  v_second jsonb;
  v_guest_result jsonb;
  v_auth jsonb;
  v_forbidden jsonb;
  v_invalid jsonb;
  v_missing jsonb;
  v_orders integer;
  v_jobs integer;
  v_items_count integer;
  v_redemptions integer;
  v_keys integer;
  v_owner uuid;
BEGIN
  EXECUTE 'SET LOCAL ROLE anon';
  v_invalid := public.submit_order_v4(
    jsonb_build_object('name', 'Анна', 'phone', '1234567', 'consent_given', true),
    v_items,
    v_request
  );
  v_missing := public.submit_order_v4(
    jsonb_build_object('name', 'Анна', 'phone', '   ', 'consent_given', true),
    v_items,
    v_request
  );
  IF v_invalid->'errors'->0->>'code' IS DISTINCT FROM 'invalid_phone'
     OR v_missing->'errors'->0->>'code' IS DISTINCT FROM 'missing_phone' THEN
    RAISE EXCEPTION 'v4 phone gate failed: % / %', v_invalid, v_missing;
  END IF;

  v_first := public.submit_order_v4(v_customer, v_items, v_request);
  IF COALESCE((v_first->>'ok')::boolean, false) IS NOT TRUE THEN
    RAISE EXCEPTION 'first v4 submit failed: %', v_first;
  END IF;
  IF v_first->>'discount_amount' IS DISTINCT FROM '10.00'
     OR v_first->>'grand_total_amount' IS DISTINCT FROM '90.00' THEN
    RAISE EXCEPTION 'unexpected priced total: %', v_first;
  END IF;

  v_replay := public.submit_order_v4(v_customer, v_items, v_request);
  IF v_replay->>'order_id' IS DISTINCT FROM v_first->>'order_id'
     OR v_replay->>'grand_total_amount' IS DISTINCT FROM v_first->>'grand_total_amount'
     OR v_replay->>'discount_amount' IS DISTINCT FROM v_first->>'discount_amount' THEN
    RAISE EXCEPTION 'replay changed the order or the price';
  END IF;

  EXECUTE 'RESET ROLE';

  SELECT count(*) INTO v_orders
  FROM public.order_requests
  WHERE id = (v_first->>'order_id')::uuid;
  SELECT count(*) INTO v_jobs
  FROM private.order_notification_jobs
  WHERE order_id = (v_first->>'order_id')::uuid;
  SELECT count(*) INTO v_items_count
  FROM public.order_request_items
  WHERE request_id = (v_first->>'order_id')::uuid;
  SELECT count(*) INTO v_redemptions
  FROM public.discount_redemptions
  WHERE order_request_id = (v_first->>'order_id')::uuid;
  IF v_orders <> 1 OR v_jobs <> 1 OR v_items_count <> 1 OR v_redemptions <> 1 THEN
    RAISE EXCEPTION
      'replay duplicated state orders=% jobs=% items=% redemptions=%',
      v_orders, v_jobs, v_items_count, v_redemptions;
  END IF;

  SELECT count(*) INTO v_keys
  FROM private.checkout_submissions
  WHERE request_id = v_request
    AND order_id = (v_first->>'order_id')::uuid
    AND payload_digest ~ '^[0-9a-f]{64}$';
  IF v_keys <> 1 THEN
    RAISE EXCEPTION 'idempotency row missing or did not store a digest';
  END IF;

  EXECUTE 'SET LOCAL ROLE anon';
  v_conflict := public.submit_order_v4(
    v_customer || jsonb_build_object('comment', 'changed'),
    v_items,
    v_request
  );
  IF v_conflict->'errors'->0->>'code' IS DISTINCT FROM 'request_payload_conflict'
     OR v_conflict ? 'order_id' THEN
    RAISE EXCEPTION 'payload conflict was accepted or leaked data: %', v_conflict;
  END IF;

  v_second := public.submit_order_v4(v_customer, v_items, v_other);
  IF COALESCE((v_second->>'ok')::boolean, false) IS NOT TRUE
     OR v_second->>'order_id' = v_first->>'order_id' THEN
    RAISE EXCEPTION 'distinct request did not create its own order: %', v_second;
  END IF;
  IF v_second->>'grand_total_amount' IS DISTINCT FROM '90.00' THEN
    RAISE EXCEPTION 'second order was not repriced from the catalog: %', v_second;
  END IF;
  EXECUTE 'RESET ROLE';

  SELECT user_id INTO v_owner
  FROM public.order_requests
  WHERE id = (v_first->>'order_id')::uuid;
  IF v_owner IS NOT NULL THEN
    RAISE EXCEPTION 'guest order was assigned to a user';
  END IF;

  PERFORM set_config(
    'request.jwt.claim.sub',
    '11111111-2222-4333-8444-555555555552',
    true
  );
  v_forbidden := public.submit_order_v4(v_customer, v_items, v_request);
  IF v_forbidden->'errors'->0->>'code' IS DISTINCT FROM 'request_forbidden'
     OR v_forbidden ? 'order_id' THEN
    RAISE EXCEPTION 'cross-user replay leaked or was accepted: %', v_forbidden;
  END IF;
  PERFORM set_config('request.jwt.claim.sub', '', true);

  EXECUTE 'SET LOCAL ROLE authenticated';
  PERFORM set_config(
    'request.jwt.claim.sub',
    '11111111-2222-4333-8444-555555555551',
    true
  );
  v_auth := public.submit_order_v4(
    v_customer,
    v_items,
    'aaaaaaaa-aaaa-4aaa-8aaa-aaaaaaaaaa04'
  );
  EXECUTE 'RESET ROLE';
  IF COALESCE((v_auth->>'ok')::boolean, false) IS NOT TRUE THEN
    RAISE EXCEPTION 'authenticated submit failed: %', v_auth;
  END IF;
  SELECT user_id INTO v_owner
  FROM public.order_requests
  WHERE id = (v_auth->>'order_id')::uuid;
  IF v_owner IS DISTINCT FROM '11111111-2222-4333-8444-555555555551'::uuid THEN
    RAISE EXCEPTION 'authenticated order owner mismatch: %', v_owner;
  END IF;

  PERFORM set_config('request.jwt.claim.sub', '', true);
  v_guest_result := public.submit_order_v4(v_customer, v_items, v_guest);
  IF COALESCE((v_guest_result->>'ok')::boolean, false) IS NOT TRUE THEN
    RAISE EXCEPTION 'second guest submit failed: %', v_guest_result;
  END IF;
END $$;

-- A failure inside v3 must remove the idempotency row with the order.
CREATE OR REPLACE FUNCTION public.submit_order_v3(p_customer jsonb, p_items jsonb)
RETURNS jsonb
LANGUAGE plpgsql
AS $$
BEGIN
  INSERT INTO public.order_requests (customer_name, phone)
  VALUES ('Boom', '+37312345678');
  RAISE EXCEPTION 'forced rollback';
END;
$$;

DO $$
DECLARE
  v_before integer;
  v_after integer;
  v_keys integer;
BEGIN
  SELECT count(*) INTO v_before FROM public.order_requests;
  BEGIN
    PERFORM public.submit_order_v4(
      jsonb_build_object(
        'name', 'Анна',
        'phone', '+37312345678',
        'consent_given', true,
        'fulfillment_type', 'pickup',
        'pickup_store_id', 'store_central',
        'fulfillment_method_code', 'pickup_store',
        'fulfillment_fee', 0,
        'payment_method_code', 'cash'
      ),
      jsonb_build_array(jsonb_build_object('variant_id', 'TST-V-A1', 'quantity', 1)),
      'aaaaaaaa-aaaa-4aaa-8aaa-aaaaaaaaaa09'
    );
    RAISE EXCEPTION 'v4 swallowed the forced failure';
  EXCEPTION
    WHEN OTHERS THEN
      IF SQLERRM NOT ILIKE '%forced rollback%' THEN
        RAISE;
      END IF;
  END;
  SELECT count(*) INTO v_after FROM public.order_requests;
  SELECT count(*) INTO v_keys
  FROM private.checkout_submissions
  WHERE request_id = 'aaaaaaaa-aaaa-4aaa-8aaa-aaaaaaaaaa09';
  IF v_after <> v_before OR v_keys <> 0 THEN
    RAISE EXCEPTION 'rollback leaked orders %->% keys %', v_before, v_after, v_keys;
  END IF;
END $$;

ROLLBACK;

SELECT 'checkout_reliability_ok' AS result;
