-- TIFFANI recovery baseline 0002
-- Profiles, admin allowlist, orders, consultations.
-- Requires Supabase auth.users. Does not schedule cron.
--
-- Resolved incompatibility:
--   order_request_items.product_id is uuid.
--   The historical bootstrap created TEXT, but the final submit_order_v2
--   and submit_order_v3 insert catalog_items.product_id::uuid.
--   variant_id stays text.

CREATE TABLE public.profiles (
  id           uuid        PRIMARY KEY REFERENCES auth.users (id) ON DELETE CASCADE,
  name         text        NULL,
  phone        text        NULL,
  loyalty_card text        NULL,
  created_at   timestamptz NOT NULL DEFAULT now(),
  updated_at   timestamptz NOT NULL DEFAULT now()
);

CREATE TABLE public.admin_users (
  id         uuid        PRIMARY KEY DEFAULT gen_random_uuid(),
  user_id    uuid        NOT NULL UNIQUE REFERENCES auth.users (id) ON DELETE CASCADE,
  email      text        NULL,
  created_at timestamptz NOT NULL DEFAULT now()
);

COMMENT ON TABLE public.admin_users IS
  'Admin allowlist. No client INSERT policy. First row is a manual SQL insert after the Auth user exists.';

CREATE TABLE public.order_requests (
  id                         uuid             PRIMARY KEY DEFAULT gen_random_uuid(),
  customer_name              text             NOT NULL,
  phone                      text             NOT NULL,
  email                      text             NULL,
  delivery_method            text             NULL,
  delivery_address           text             NULL,
  payment_method             text             NULL,
  promo_code                 text             NULL,
  loyalty_card               text             NULL,
  comment                    text             NULL,
  consent_given              boolean          NOT NULL DEFAULT false,
  total_items                integer          NULL,
  total_quantity             integer          NULL,
  total_price                double precision NULL,
  status                     text             NOT NULL DEFAULT 'new',
  source                     text             NOT NULL DEFAULT 'mobile_app',
  user_id                    uuid             NULL REFERENCES auth.users (id),
  created_at                 timestamptz      NOT NULL DEFAULT now(),
  fulfillment_type           text             NULL,
  pickup_store_id            text             NULL,
  delivery_zone_code         text             NULL,
  fulfillment_method_code    text             NULL,
  fulfillment_fee            double precision NULL,
  payment_method_code        text             NULL,
  subtotal_amount            numeric(12,2)    NULL,
  discount_amount            numeric(12,2)    NOT NULL DEFAULT 0,
  grand_total_amount         numeric(12,2)    NULL,
  applied_promocode_code     text             NULL,
  applied_discount_snapshot  jsonb            NOT NULL DEFAULT '[]'::jsonb,
  pricing_version            text             NULL,
  pricing_metadata           jsonb            NOT NULL DEFAULT '{}'::jsonb,
  CONSTRAINT chk_fulfillment_type_values CHECK (
    fulfillment_type IS NULL OR fulfillment_type IN ('pickup', 'delivery')
  ),
  CONSTRAINT chk_delivery_zone_code_values CHECK (
    delivery_zone_code IS NULL OR delivery_zone_code IN (
      'tiraspol', 'bender', 'express', 'moldova'
    )
  ),
  CONSTRAINT chk_fulfillment_consistency CHECK (
    fulfillment_type IS NULL
    OR (
      fulfillment_type = 'pickup'
      AND pickup_store_id IS NOT NULL
      AND delivery_zone_code IS NULL
      AND (delivery_address IS NULL OR btrim(delivery_address) = '')
    )
    OR (
      fulfillment_type = 'delivery'
      AND pickup_store_id IS NULL
      AND delivery_zone_code IS NOT NULL
      AND delivery_address IS NOT NULL
      AND btrim(delivery_address) <> ''
    )
  ),
  CONSTRAINT chk_fulfillment_method_code_values CHECK (
    fulfillment_method_code IS NULL OR fulfillment_method_code IN (
      'pickup_store',
      'courier_tiraspol',
      'courier_bender',
      'express_post',
      'moldova_post'
    )
  ),
  CONSTRAINT chk_payment_method_code_values CHECK (
    payment_method_code IS NULL OR payment_method_code IN (
      'cash',
      'mobile_payment',
      'bank_transfer',
      'clever_installment'
    )
  ),
  CONSTRAINT chk_fulfillment_fee_non_negative CHECK (
    fulfillment_fee IS NULL OR fulfillment_fee >= 0
  ),
  CONSTRAINT chk_fulfillment_method_type_agreement CHECK (
    fulfillment_type IS NULL
    OR fulfillment_method_code IS NULL
    OR (fulfillment_type = 'pickup' AND fulfillment_method_code = 'pickup_store')
    OR (
      fulfillment_type = 'delivery'
      AND fulfillment_method_code IN (
        'courier_tiraspol', 'courier_bender', 'express_post', 'moldova_post'
      )
    )
  ),
  CONSTRAINT chk_order_requests_discount_amount_non_negative CHECK (
    discount_amount >= 0
  )
);

COMMENT ON COLUMN public.order_requests.pickup_store_id IS
  'Checkout slug (store_central, store_balka, store_bendery). Not a foreign key to public.stores.';

COMMENT ON COLUMN public.order_requests.total_price IS
  'Legacy v2 subtotal kept as double precision. Account history reads it with a JSON number cast. Discount totals are numeric(12,2).';

CREATE INDEX idx_order_requests_user_id
  ON public.order_requests (user_id);

CREATE INDEX idx_order_requests_pickup_store_id
  ON public.order_requests (pickup_store_id)
  WHERE pickup_store_id IS NOT NULL;

CREATE INDEX idx_order_requests_fulfillment_type
  ON public.order_requests (fulfillment_type)
  WHERE fulfillment_type IS NOT NULL;

CREATE TABLE public.order_request_items (
  id                         uuid             PRIMARY KEY DEFAULT gen_random_uuid(),
  request_id                 uuid             NOT NULL REFERENCES public.order_requests (id) ON DELETE CASCADE,
  variant_id                 text             NOT NULL,
  product_id                 uuid             NULL,
  title                      text             NULL,
  brand                      text             NULL,
  image_url                  text             NULL,
  price                      numeric(12,2)    NULL,
  old_price                  numeric(12,2)    NULL,
  quantity                   integer          NOT NULL,
  line_total                 double precision NULL,
  edition                    text             NULL,
  modification               text             NULL,
  is_active                  boolean          NULL,
  created_at                 timestamptz      NOT NULL DEFAULT now(),
  unit_price_amount          numeric(12,2)    NULL,
  line_subtotal_amount       numeric(12,2)    NULL,
  line_discount_amount       numeric(12,2)    NOT NULL DEFAULT 0,
  line_total_amount          numeric(12,2)    NULL,
  applied_discount_snapshot  jsonb            NOT NULL DEFAULT '[]'::jsonb,
  CONSTRAINT chk_order_request_items_line_discount_non_negative CHECK (
    line_discount_amount >= 0
  )
);

COMMENT ON COLUMN public.order_request_items.price IS
  'Snapshot unit price as numeric(12,2). line_total stays double precision for the legacy v2 column.';

COMMENT ON COLUMN public.order_request_items.variant_id IS
  'Canonical text variant id. Matches catalog_items.variant_id.';

COMMENT ON COLUMN public.order_request_items.product_id IS
  'uuid. Final submit_order_v2/v3 cast catalog_items.product_id::uuid into this column.';

CREATE INDEX idx_order_request_items_request_id
  ON public.order_request_items (request_id);

CREATE INDEX idx_order_request_items_variant_id
  ON public.order_request_items (variant_id);

CREATE TABLE public.consultation_requests (
  id            uuid        PRIMARY KEY DEFAULT gen_random_uuid(),
  created_at    timestamptz NOT NULL DEFAULT now(),
  status        text        NOT NULL DEFAULT 'new',
  source        text        NOT NULL DEFAULT 'mobile_app',
  user_id       uuid        NULL REFERENCES auth.users (id) ON DELETE SET NULL,
  customer_name text        NOT NULL,
  phone         text        NOT NULL,
  CONSTRAINT chk_consultation_name_not_empty CHECK (length(btrim(customer_name)) > 0),
  CONSTRAINT chk_consultation_phone_not_empty CHECK (length(btrim(phone)) > 0)
);

CREATE INDEX idx_consultation_requests_created_at
  ON public.consultation_requests (created_at DESC);
