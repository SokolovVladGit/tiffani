-- Consultation requests: lightweight lead capture from the Info CTA block.
--
-- Separate from order_requests on purpose: no items, no totals, no
-- fulfillment. Writes flow through `submit_consultation_v1` (SECURITY
-- DEFINER) so RLS can remain restrictive for SELECT while staying
-- open enough for guest inserts through the RPC.
--
-- Columns are intentionally minimal; any workflow fields (assignee,
-- resolved_at, channel, etc.) should be added by a follow-up migration
-- once the workflow is defined.

CREATE TABLE IF NOT EXISTS public.consultation_requests (
  id            UUID         PRIMARY KEY DEFAULT gen_random_uuid(),
  created_at    TIMESTAMPTZ  NOT NULL    DEFAULT now(),
  status        TEXT         NOT NULL    DEFAULT 'new',
  source        TEXT         NOT NULL    DEFAULT 'mobile_app',
  user_id       UUID         NULL        REFERENCES auth.users(id) ON DELETE SET NULL,
  customer_name TEXT         NOT NULL,
  phone         TEXT         NOT NULL,
  CONSTRAINT chk_consultation_name_not_empty  CHECK (length(btrim(customer_name)) > 0),
  CONSTRAINT chk_consultation_phone_not_empty CHECK (length(btrim(phone)) > 0)
);

-- -----------------------------------------------------------------------------
-- Row Level Security
-- -----------------------------------------------------------------------------
-- Matches the `order_requests` convention:
--   * SELECT scoped to the authenticated owner (auth.uid() = user_id)
--   * INSERT open so the SECURITY DEFINER RPC works under anon/authenticated.
--     Direct inserts from clients are not part of the intended contract;
--     the policy mirrors `order_requests` so the RPC path is uniform.
-- -----------------------------------------------------------------------------

ALTER TABLE public.consultation_requests ENABLE ROW LEVEL SECURITY;

DROP POLICY IF EXISTS "Users can read own consultations"
  ON public.consultation_requests;
CREATE POLICY "Users can read own consultations"
  ON public.consultation_requests FOR SELECT
  USING (auth.uid() IS NOT NULL AND auth.uid() = user_id);

DROP POLICY IF EXISTS "Anyone can insert consultations"
  ON public.consultation_requests;
CREATE POLICY "Anyone can insert consultations"
  ON public.consultation_requests FOR INSERT
  WITH CHECK (true);

-- -----------------------------------------------------------------------------
-- Index
-- -----------------------------------------------------------------------------
-- Used by the (future) admin view that lists consultations newest-first.
-- Partial index on user_id is deferred until a user-facing history view exists.

CREATE INDEX IF NOT EXISTS idx_consultation_requests_created_at
  ON public.consultation_requests (created_at DESC);
