-- TIFFANI recovery baseline 0004
-- Discount tables and the updated_at trigger.
-- quote_order_v1 is installed in 0006. RLS is installed in 0008.
-- Definitions match 20260502120000_discount_engine_phase1.sql.
-- No campaigns are seeded.

CREATE TABLE public.discount_campaigns (
  id                       uuid          PRIMARY KEY DEFAULT gen_random_uuid(),
  kind                     text          NOT NULL,
  name                     text          NOT NULL,
  code                     text          NULL,
  description              text          NULL,
  percent_off              numeric(5,2)  NOT NULL,
  min_order_amount         numeric(12,2) NOT NULL DEFAULT 0,
  starts_at                timestamptz   NULL,
  ends_at                  timestamptz   NULL,
  max_redemptions          integer       NULL,
  used_count               integer       NOT NULL DEFAULT 0,
  is_active                boolean       NOT NULL DEFAULT true,
  stackable_with_promocode boolean       NOT NULL DEFAULT false,
  priority                 integer       NOT NULL DEFAULT 100,
  source                   text          NOT NULL DEFAULT 'manual',
  external_ref             text          NULL,
  metadata                 jsonb         NOT NULL DEFAULT '{}'::jsonb,
  created_at               timestamptz   NOT NULL DEFAULT now(),
  updated_at               timestamptz   NOT NULL DEFAULT now(),
  CONSTRAINT chk_discount_campaigns_kind CHECK (
    kind IN ('automatic', 'promocode')
  ),
  CONSTRAINT chk_discount_campaigns_percent_off CHECK (
    percent_off > 0 AND percent_off <= 100
  ),
  CONSTRAINT chk_discount_campaigns_min_order_amount CHECK (
    min_order_amount >= 0
  ),
  CONSTRAINT chk_discount_campaigns_max_redemptions CHECK (
    max_redemptions IS NULL OR max_redemptions > 0
  ),
  CONSTRAINT chk_discount_campaigns_used_count CHECK (
    used_count >= 0
  ),
  CONSTRAINT chk_discount_campaigns_code_kind CHECK (
    (kind = 'promocode' AND code IS NOT NULL AND btrim(code) <> '')
    OR (kind = 'automatic' AND code IS NULL)
  )
);

CREATE UNIQUE INDEX uq_discount_campaigns_promocode_upper
  ON public.discount_campaigns (upper(code))
  WHERE kind = 'promocode' AND code IS NOT NULL;

CREATE INDEX idx_discount_campaigns_active_window
  ON public.discount_campaigns (is_active, starts_at, ends_at);

CREATE INDEX idx_discount_campaigns_kind_active
  ON public.discount_campaigns (kind, is_active);

CREATE TABLE public.discount_campaign_targets (
  id           uuid        PRIMARY KEY DEFAULT gen_random_uuid(),
  campaign_id  uuid        NOT NULL REFERENCES public.discount_campaigns (id) ON DELETE CASCADE,
  target_type  text        NOT NULL,
  target_value text        NULL,
  match_mode   text        NOT NULL DEFAULT 'exact',
  created_at   timestamptz NOT NULL DEFAULT now(),
  CONSTRAINT chk_discount_targets_type CHECK (
    target_type IN (
      'all', 'category', 'brand', 'mark',
      'product_tilda_uid', 'product_id', 'variant_id'
    )
  ),
  CONSTRAINT chk_discount_targets_match_mode CHECK (
    match_mode IN ('exact', 'prefix', 'contains')
  ),
  CONSTRAINT chk_discount_targets_value_presence CHECK (
    (target_type = 'all' AND target_value IS NULL)
    OR (target_type <> 'all' AND target_value IS NOT NULL)
  )
);

CREATE UNIQUE INDEX uq_discount_targets_combo
  ON public.discount_campaign_targets (
    campaign_id, target_type, COALESCE(target_value, ''), match_mode
  );

CREATE INDEX idx_discount_targets_campaign_id
  ON public.discount_campaign_targets (campaign_id);

CREATE INDEX idx_discount_targets_type_value_lower
  ON public.discount_campaign_targets (target_type, lower(target_value));

CREATE TABLE public.discount_redemptions (
  id                uuid          PRIMARY KEY DEFAULT gen_random_uuid(),
  campaign_id       uuid          NOT NULL REFERENCES public.discount_campaigns (id),
  order_request_id  uuid          NULL REFERENCES public.order_requests (id) ON DELETE SET NULL,
  user_id           uuid          NULL REFERENCES auth.users (id) ON DELETE SET NULL,
  customer_phone    text          NULL,
  code              text          NULL,
  subtotal_amount   numeric(12,2) NOT NULL DEFAULT 0,
  discount_amount   numeric(12,2) NOT NULL DEFAULT 0,
  metadata          jsonb         NOT NULL DEFAULT '{}'::jsonb,
  created_at        timestamptz   NOT NULL DEFAULT now(),
  CONSTRAINT chk_discount_redemptions_amounts_non_negative CHECK (
    subtotal_amount >= 0 AND discount_amount >= 0
  )
);

CREATE INDEX idx_discount_redemptions_campaign_id
  ON public.discount_redemptions (campaign_id);

CREATE INDEX idx_discount_redemptions_order_request_id
  ON public.discount_redemptions (order_request_id);

CREATE INDEX idx_discount_redemptions_user_id
  ON public.discount_redemptions (user_id);

CREATE INDEX idx_discount_redemptions_created_at
  ON public.discount_redemptions (created_at);

CREATE FUNCTION public.set_discount_campaigns_updated_at()
RETURNS trigger
LANGUAGE plpgsql
SET search_path = pg_catalog
AS $$
BEGIN
  NEW.updated_at := now();
  RETURN NEW;
END;
$$;

CREATE TRIGGER trg_discount_campaigns_updated_at
  BEFORE UPDATE ON public.discount_campaigns
  FOR EACH ROW
  EXECUTE FUNCTION public.set_discount_campaigns_updated_at();
