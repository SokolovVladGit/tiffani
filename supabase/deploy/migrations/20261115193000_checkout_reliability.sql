-- Checkout phone validation and idempotent submit_order_v4.
-- Forward-only. Does not edit or reapply the notification outbox.
--
-- submit_order_v3 stays callable and is NOT idempotent. A lost v3 response
-- followed by another v3 call creates a second order and a second notification
-- job. New Flutter checkout calls submit_order_v4.
--
-- The phone trigger is BEFORE INSERT only. Updates of historical orders,
-- including the stored 19-digit test phone, are not revalidated.

CREATE OR REPLACE FUNCTION public.checkout_phone_is_valid(p_phone text)
RETURNS boolean
LANGUAGE sql
IMMUTABLE
PARALLEL SAFE
SET search_path = pg_catalog
AS $$
  SELECT
    btrim(COALESCE(p_phone, '')) <> ''
    AND btrim(p_phone) ~ '^[+0-9 ()-]+$'
    AND (
      position('+' IN btrim(p_phone)) = 0
      OR (
        left(btrim(p_phone), 1) = '+'
        AND length(btrim(p_phone)) - length(replace(btrim(p_phone), '+', '')) = 1
      )
    )
    AND length(regexp_replace(btrim(p_phone), '\D', '', 'g')) BETWEEN 8 AND 15;
$$;

REVOKE ALL ON FUNCTION public.checkout_phone_is_valid(text) FROM PUBLIC;
GRANT EXECUTE ON FUNCTION public.checkout_phone_is_valid(text) TO anon, authenticated, service_role;

CREATE OR REPLACE FUNCTION public.order_requests_reject_invalid_phone()
RETURNS trigger
LANGUAGE plpgsql
SET search_path = pg_catalog
AS $$
BEGIN
  IF NOT public.checkout_phone_is_valid(NEW.phone) THEN
    RAISE EXCEPTION 'Некорректный номер телефона'
      USING ERRCODE = '23514';
  END IF;
  RETURN NEW;
END;
$$;

DROP TRIGGER IF EXISTS order_requests_reject_invalid_phone ON public.order_requests;

CREATE TRIGGER order_requests_reject_invalid_phone
  BEFORE INSERT ON public.order_requests
  FOR EACH ROW
  EXECUTE FUNCTION public.order_requests_reject_invalid_phone();

REVOKE ALL ON FUNCTION public.order_requests_reject_invalid_phone() FROM PUBLIC, anon, authenticated, service_role;

CREATE SCHEMA IF NOT EXISTS extensions;

DO $ext$
BEGIN
  IF NOT EXISTS (SELECT 1 FROM pg_extension WHERE extname = 'pgcrypto') THEN
    CREATE EXTENSION pgcrypto WITH SCHEMA extensions;
  END IF;
END
$ext$;

CREATE SCHEMA IF NOT EXISTS private;

REVOKE ALL ON SCHEMA private FROM PUBLIC, anon, authenticated;
GRANT USAGE ON SCHEMA private TO service_role;

CREATE TABLE private.checkout_submissions (
  request_id      uuid        PRIMARY KEY,
  owner_id        uuid        NULL,
  payload_digest  text        NOT NULL,
  order_id        uuid        NULL REFERENCES public.order_requests (id),
  response        jsonb       NULL,
  created_at      timestamptz NOT NULL DEFAULT now()
);

COMMENT ON TABLE private.checkout_submissions IS
  'One row per client checkout request id. Holds a payload digest and the original RPC response, not a second copy of the contact fields.';

COMMENT ON COLUMN private.checkout_submissions.owner_id IS
  'auth.uid() captured when the row is inserted. NULL is a guest capability token: anyone who presents that request_id can replay the guest attempt. A different auth.uid() gets request_forbidden and no order_id.';

ALTER TABLE private.checkout_submissions ENABLE ROW LEVEL SECURITY;

REVOKE ALL ON TABLE private.checkout_submissions FROM PUBLIC, anon, authenticated;
GRANT SELECT, INSERT, UPDATE ON TABLE private.checkout_submissions TO service_role;

CREATE OR REPLACE FUNCTION public.submit_order_v4(
  p_customer   jsonb,
  p_items      jsonb,
  p_request_id uuid
)
RETURNS jsonb
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public, pg_temp
AS $$
DECLARE
  v_owner   uuid := auth.uid();
  v_digest  text;
  v_row     private.checkout_submissions%ROWTYPE;
  v_result  jsonb;
  v_phone   text;
BEGIN
  IF p_request_id IS NULL THEN
    RETURN jsonb_build_object(
      'ok', false,
      'errors', jsonb_build_array(jsonb_build_object(
        'code', 'missing_request_id',
        'message', 'Не удалось оформить заказ. Попробуйте ещё раз.'
      ))
    );
  END IF;

  v_phone := NULLIF(btrim(COALESCE(p_customer->>'phone', '')), '');
  IF v_phone IS NULL THEN
    RETURN jsonb_build_object(
      'ok', false,
      'errors', jsonb_build_array(jsonb_build_object(
        'code', 'missing_phone',
        'message', 'Укажите телефон'
      ))
    );
  END IF;
  IF NOT public.checkout_phone_is_valid(v_phone) THEN
    RETURN jsonb_build_object(
      'ok', false,
      'errors', jsonb_build_array(jsonb_build_object(
        'code', 'invalid_phone',
        'message', 'Некорректный номер телефона'
      ))
    );
  END IF;

  v_digest := encode(
    extensions.digest(
      convert_to(
        jsonb_build_object('customer', p_customer, 'items', p_items)::text,
        'UTF8'
      ),
      'sha256'
    ),
    'hex'
  );

  -- A concurrent peer that lost the insert waits on this row. If the winner
  -- rolls back, the row disappears and this session inserts it.
  LOOP
    INSERT INTO private.checkout_submissions (request_id, owner_id, payload_digest)
    VALUES (p_request_id, v_owner, v_digest)
    ON CONFLICT (request_id) DO NOTHING;

    SELECT *
    INTO v_row
    FROM private.checkout_submissions
    WHERE request_id = p_request_id
    FOR UPDATE;

    EXIT WHEN FOUND;
  END LOOP;

  IF v_row.owner_id IS DISTINCT FROM v_owner THEN
    RETURN jsonb_build_object(
      'ok', false,
      'errors', jsonb_build_array(jsonb_build_object(
        'code', 'request_forbidden',
        'message', 'Этот запрос уже использован. Оформите заказ заново.'
      ))
    );
  END IF;

  IF v_row.payload_digest IS DISTINCT FROM v_digest THEN
    RETURN jsonb_build_object(
      'ok', false,
      'errors', jsonb_build_array(jsonb_build_object(
        'code', 'request_payload_conflict',
        'message', 'Данные заказа изменились. Оформите заказ заново.'
      ))
    );
  END IF;

  IF v_row.response IS NOT NULL THEN
    RETURN v_row.response;
  END IF;

  v_result := public.submit_order_v3(p_customer, p_items);

  UPDATE private.checkout_submissions
  SET response = v_result,
      order_id = CASE
        WHEN COALESCE((v_result->>'ok')::boolean, false)
          THEN NULLIF(v_result->>'order_id', '')::uuid
        ELSE NULL
      END
  WHERE request_id = p_request_id;

  RETURN v_result;
END;
$$;

REVOKE ALL ON FUNCTION public.submit_order_v4(jsonb, jsonb, uuid) FROM PUBLIC;
GRANT EXECUTE ON FUNCTION public.submit_order_v4(jsonb, jsonb, uuid)
  TO anon, authenticated, service_role;

COMMENT ON FUNCTION public.submit_order_v4(jsonb, jsonb, uuid) IS
  'Idempotent checkout. Same request id and same payload returns the original response and does not create another order. submit_order_v3 remains non-idempotent.';
