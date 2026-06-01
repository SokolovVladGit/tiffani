-- ============================================================================
-- Phase 3A manual tests for admin_upsert_native_product (LOCAL / NON-PROD ONLY)
--
-- Prerequisite: auth.uid() must pass public.is_admin().
-- In SQL Editor as postgres, set a real admin_users.user_id first, e.g.:
--   SELECT set_config('request.jwt.claim.sub', '<admin-auth-uuid>', true);
--
-- Do NOT run against production.
-- ============================================================================

\set ON_ERROR_STOP on

BEGIN;

SET LOCAL client_min_messages = NOTICE;

-- ── 1. Create native product ─────────────────────────────────────────────────
DO $$
DECLARE
  v_result jsonb;
BEGIN
  v_result := public.admin_upsert_native_product(
    jsonb_build_object(
      'title', 'TEST Native Admin Product',
      'brand', 'TEST Brand',
      'category', 'TEST Category',
      'mark', 'TEST',
      'description', 'Test description',
      'text', 'Test full text',
      'price', 123.45,
      'old_price', 150,
      'quantity', 7,
      'image_urls', jsonb_build_array(
        'https://example.com/image-1.jpg',
        'https://example.com/image-2.jpg'
      ),
      'app_is_visible', true
    )
  );

  IF v_result->>'tilda_uid' IS NOT NULL THEN
    RAISE EXCEPTION 'expected tilda_uid null, got %', v_result->>'tilda_uid';
  END IF;
  IF v_result->>'variant_id' NOT LIKE 'admin_%' THEN
    RAISE EXCEPTION 'expected admin_ variant_id, got %', v_result->>'variant_id';
  END IF;
  IF (v_result->>'effective_is_active')::boolean IS DISTINCT FROM true THEN
    RAISE EXCEPTION 'expected effective_is_active true on create';
  END IF;

  RAISE NOTICE 'create result: %', v_result;
END;
$$;

-- ── 2. Update native product (variant_id stable, hide via app_is_visible) ───
DO $$
DECLARE
  v_create   jsonb;
  v_update   jsonb;
  v_pid      uuid;
  v_vid_before text;
  v_vid_after  text;
BEGIN
  v_create := public.admin_upsert_native_product(
    jsonb_build_object(
      'title', 'TEST Native Product Before Edit',
      'price', 100,
      'quantity', 3,
      'image_urls', jsonb_build_array('https://example.com/before.jpg'),
      'app_is_visible', true
    )
  );
  v_pid := (v_create->>'product_id')::uuid;
  v_vid_before := v_create->>'variant_id';

  v_update := public.admin_upsert_native_product(
    jsonb_build_object(
      'product_id', v_pid::text,
      'title', 'TEST Native Product After Edit',
      'price', 90,
      'old_price', 120,
      'quantity', 11,
      'image_urls', jsonb_build_array(
        'https://example.com/after-1.jpg',
        'https://example.com/after-2.jpg'
      ),
      'app_is_visible', false
    )
  );
  v_vid_after := v_update->>'variant_id';

  IF v_vid_before IS DISTINCT FROM v_vid_after THEN
    RAISE EXCEPTION 'variant_id changed: % -> %', v_vid_before, v_vid_after;
  END IF;
  IF (v_update->>'app_is_visible')::boolean IS DISTINCT FROM false THEN
    RAISE EXCEPTION 'expected app_is_visible false after edit';
  END IF;
  IF (v_update->>'effective_is_active')::boolean IS DISTINCT FROM false THEN
    RAISE EXCEPTION 'expected effective_is_active false when hidden';
  END IF;

  RAISE NOTICE 'update result: %', v_update;
END;
$$;

-- ── 3. Tilda edit must fail ──────────────────────────────────────────────────
DO $$
DECLARE
  v_tilda_id uuid;
  v_err      text;
BEGIN
  SELECT id INTO v_tilda_id
  FROM public.products
  WHERE tilda_uid IS NOT NULL
  LIMIT 1;

  IF v_tilda_id IS NULL THEN
    RAISE NOTICE 'skip: no Tilda product in DB';
    RETURN;
  END IF;

  BEGIN
    PERFORM public.admin_upsert_native_product(
      jsonb_build_object(
        'product_id', v_tilda_id::text,
        'title', 'SHOULD NOT EDIT TILDA',
        'price', 1,
        'quantity', 1,
        'image_urls', jsonb_build_array(),
        'app_is_visible', true
      )
    );
    RAISE EXCEPTION 'expected Tilda edit to fail';
  EXCEPTION
    WHEN others THEN
      v_err := SQLERRM;
      IF v_err NOT LIKE '%Tilda products cannot be edited%' THEN
        RAISE EXCEPTION 'unexpected error: %', v_err;
      END IF;
      RAISE NOTICE 'Tilda rejection OK: %', v_err;
  END;
END;
$$;

ROLLBACK;

DO $$ BEGIN RAISE NOTICE 'Phase 3A admin_upsert_native_product tests finished (rolled back).'; END $$;
