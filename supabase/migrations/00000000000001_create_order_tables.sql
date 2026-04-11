-- Bootstrap: ensures order tables exist with full target schema.
-- Safe on existing production (IF NOT EXISTS + ADD COLUMN IF NOT EXISTS).
-- Enables fresh environments to run all subsequent migrations.

-- ==========================================================================
-- 1. order_requests
-- ==========================================================================
CREATE TABLE IF NOT EXISTS public.order_requests (
  id               UUID            PRIMARY KEY DEFAULT gen_random_uuid(),
  customer_name    TEXT            NOT NULL,
  phone            TEXT            NOT NULL,
  email            TEXT,
  delivery_method  TEXT,
  delivery_address TEXT,
  payment_method   TEXT,
  promo_code       TEXT,
  loyalty_card     TEXT,
  comment          TEXT,
  consent_given    BOOLEAN         NOT NULL DEFAULT false,
  total_items      INT,
  total_quantity   INT,
  total_price      DOUBLE PRECISION,
  status           TEXT            NOT NULL DEFAULT 'new',
  source           TEXT            NOT NULL DEFAULT 'mobile_app',
  user_id          UUID            REFERENCES auth.users(id),
  created_at       TIMESTAMPTZ     NOT NULL DEFAULT now()
);

-- Idempotent column additions for existing production tables.
ALTER TABLE public.order_requests ADD COLUMN IF NOT EXISTS email            TEXT;
ALTER TABLE public.order_requests ADD COLUMN IF NOT EXISTS delivery_method  TEXT;
ALTER TABLE public.order_requests ADD COLUMN IF NOT EXISTS delivery_address TEXT;
ALTER TABLE public.order_requests ADD COLUMN IF NOT EXISTS payment_method   TEXT;
ALTER TABLE public.order_requests ADD COLUMN IF NOT EXISTS promo_code       TEXT;
ALTER TABLE public.order_requests ADD COLUMN IF NOT EXISTS loyalty_card     TEXT;
ALTER TABLE public.order_requests ADD COLUMN IF NOT EXISTS consent_given    BOOLEAN NOT NULL DEFAULT false;

-- ==========================================================================
-- 2. order_request_items
-- ==========================================================================
CREATE TABLE IF NOT EXISTS public.order_request_items (
  id           UUID             PRIMARY KEY DEFAULT gen_random_uuid(),
  request_id   UUID             NOT NULL REFERENCES public.order_requests(id) ON DELETE CASCADE,
  variant_id   TEXT             NOT NULL,
  product_id   TEXT,
  title        TEXT,
  brand        TEXT,
  image_url    TEXT,
  price        DOUBLE PRECISION,
  old_price    DOUBLE PRECISION,
  quantity     INT              NOT NULL,
  line_total   DOUBLE PRECISION,
  edition      TEXT,
  modification TEXT,
  is_active    BOOLEAN,
  created_at   TIMESTAMPTZ      NOT NULL DEFAULT now()
);

-- Idempotent column additions for existing production tables.
ALTER TABLE public.order_request_items ADD COLUMN IF NOT EXISTS old_price   DOUBLE PRECISION;
ALTER TABLE public.order_request_items ADD COLUMN IF NOT EXISTS line_total  DOUBLE PRECISION;
ALTER TABLE public.order_request_items ADD COLUMN IF NOT EXISTS is_active   BOOLEAN;

-- ==========================================================================
-- 3. Indexes
-- ==========================================================================
CREATE INDEX IF NOT EXISTS idx_order_request_items_request_id
  ON public.order_request_items (request_id);

CREATE INDEX IF NOT EXISTS idx_order_request_items_variant_id
  ON public.order_request_items (variant_id);
