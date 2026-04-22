-- submit_consultation_v1(p_payload JSONB)
--
-- Single write path for consultation requests. Mirrors the order flow:
--   * SECURITY DEFINER so guest clients (anon) can insert
--   * validates minimal fields server-side (name, phone)
--   * phone pattern aligned with the existing Flutter checkout validator
--     (RegExp(r'^[\d\s\+\-\(\)]{7,20}$'))
--   * source defaults to 'mobile_app', overridable via payload
--   * user_id resolved from auth.uid() when present; ignored from payload
--     to prevent spoofing by unauthenticated callers
--   * returns compact JSON: { consultation_id, created_at, status }

CREATE OR REPLACE FUNCTION public.submit_consultation_v1(
  p_payload JSONB
)
RETURNS JSONB
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
  v_name       TEXT;
  v_phone      TEXT;
  v_source     TEXT;
  v_user_id    UUID;
  v_row        public.consultation_requests;
BEGIN
  IF p_payload IS NULL THEN
    RAISE EXCEPTION 'payload is required';
  END IF;

  -- -------------------------------------------------------------------------
  -- 1. Extract and validate required fields
  -- -------------------------------------------------------------------------
  v_name := NULLIF(btrim(COALESCE(p_payload->>'name', '')), '');
  IF v_name IS NULL THEN
    RAISE EXCEPTION 'name is required';
  END IF;
  IF length(v_name) > 200 THEN
    RAISE EXCEPTION 'name is too long';
  END IF;

  v_phone := NULLIF(btrim(COALESCE(p_payload->>'phone', '')), '');
  IF v_phone IS NULL THEN
    RAISE EXCEPTION 'phone is required';
  END IF;
  -- Aligned with client regex: [\d\s\+\-\(\)]{7,20}
  IF v_phone !~ '^[0-9\s\+\-\(\)]{7,20}$' THEN
    RAISE EXCEPTION 'phone format is invalid';
  END IF;

  -- -------------------------------------------------------------------------
  -- 2. Resolve source and user_id
  -- -------------------------------------------------------------------------
  v_source := NULLIF(btrim(COALESCE(p_payload->>'source', '')), '');
  IF v_source IS NULL THEN
    v_source := 'mobile_app';
  END IF;

  -- auth.uid() is authoritative; payload-provided user_id is intentionally
  -- ignored to avoid spoofing by unauthenticated callers.
  v_user_id := auth.uid();

  -- -------------------------------------------------------------------------
  -- 3. Insert and return summary
  -- -------------------------------------------------------------------------
  INSERT INTO public.consultation_requests (
    customer_name,
    phone,
    source,
    user_id
  )
  VALUES (
    v_name,
    v_phone,
    v_source,
    v_user_id
  )
  RETURNING * INTO v_row;

  RETURN jsonb_build_object(
    'consultation_id', v_row.id,
    'created_at',      v_row.created_at,
    'status',          v_row.status
  );
END;
$$;

-- Explicit grants so anon and authenticated roles can invoke the RPC.
GRANT EXECUTE ON FUNCTION public.submit_consultation_v1(JSONB)
  TO anon, authenticated;
