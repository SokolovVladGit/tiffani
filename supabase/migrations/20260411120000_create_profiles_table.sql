-- Phase 1: Customer profiles for optional user accounts.
-- One row per authenticated user; links to auth.users via PK.

CREATE TABLE IF NOT EXISTS public.profiles (
  id         UUID PRIMARY KEY REFERENCES auth.users(id) ON DELETE CASCADE,
  name       TEXT,
  phone      TEXT,
  loyalty_card TEXT,
  created_at TIMESTAMPTZ NOT NULL DEFAULT now(),
  updated_at TIMESTAMPTZ NOT NULL DEFAULT now()
);

ALTER TABLE public.profiles ENABLE ROW LEVEL SECURITY;

CREATE POLICY "Users can read own profile"
  ON public.profiles FOR SELECT
  USING (auth.uid() = id);

CREATE POLICY "Users can insert own profile"
  ON public.profiles FOR INSERT
  WITH CHECK (auth.uid() = id);

CREATE POLICY "Users can update own profile"
  ON public.profiles FOR UPDATE
  USING (auth.uid() = id);

-- Optional groundwork: nullable user_id on order_requests for future
-- order-history linking. Not used by Flutter checkout yet.
DO $$
BEGIN
  IF NOT EXISTS (
    SELECT 1 FROM information_schema.columns
    WHERE table_schema = 'public'
      AND table_name = 'order_requests'
      AND column_name = 'user_id'
  ) THEN
    ALTER TABLE public.order_requests
      ADD COLUMN user_id UUID REFERENCES auth.users(id);
    CREATE INDEX idx_order_requests_user_id
      ON public.order_requests(user_id);
  END IF;
END $$;
