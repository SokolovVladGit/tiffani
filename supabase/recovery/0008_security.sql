-- TIFFANI recovery baseline 0008
-- Explicit grants and RLS.
--
-- Guest checkout stays on submit_order_v2 / submit_order_v3 (SECURITY DEFINER).
-- Direct INSERT into orders and consultations is not granted.
-- The historical "Anyone can insert" policies are intentionally omitted:
-- the current Flutter client writes orders and consultations only through RPCs.
--
-- Public catalog reads catalog_items, not the base tables.
-- The view keeps owner rights. 0005 created it without security_invoker.
-- Anon has no SELECT on products or product_variants.
-- Anon SELECT on product_images is limited by product_is_publicly_visible().
--
-- service_role keeps full table access for a later Edge Function phase.
-- This file does not create cron jobs and does not call catalog-sync.

-- Pin view rights on servers that support the reloption (PostgreSQL 15+).
DO $$
BEGIN
  EXECUTE 'ALTER VIEW public.catalog_items SET (security_invoker = false)';
EXCEPTION
  WHEN invalid_parameter_value THEN
    NULL;
END $$;

-- Used by the product_images SELECT policy. Runs as owner so anon does not
-- need a grant on public.products. Returns only a boolean.
CREATE FUNCTION public.product_is_publicly_visible(p_product_id uuid)
RETURNS boolean
LANGUAGE sql
STABLE
SECURITY DEFINER
SET search_path = pg_catalog
AS $$
  SELECT EXISTS (
    SELECT 1
    FROM public.products p
    WHERE p.id = p_product_id
      AND p.is_active
      AND p.app_is_visible
  );
$$;

-- ---------------------------------------------------------------------------
-- RLS
-- ---------------------------------------------------------------------------

ALTER TABLE public.products ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.product_variants ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.product_images ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.profiles ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.admin_users ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.order_requests ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.order_request_items ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.consultation_requests ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.info_blocks ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.stores ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.delivery_rules ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.articles ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.article_blocks ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.catalog_sync_runs ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.catalog_sync_run_errors ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.discount_campaigns ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.discount_campaign_targets ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.discount_redemptions ENABLE ROW LEVEL SECURITY;

-- Catalog writes and base-table reads: admins only.
-- No anon policy, so anonymous clients cannot read or modify these tables.
CREATE POLICY products_admin_select ON public.products
  FOR SELECT TO authenticated USING (public.is_admin());
CREATE POLICY products_admin_insert ON public.products
  FOR INSERT TO authenticated WITH CHECK (public.is_admin());
CREATE POLICY products_admin_update ON public.products
  FOR UPDATE TO authenticated
  USING (public.is_admin()) WITH CHECK (public.is_admin());
CREATE POLICY products_admin_delete ON public.products
  FOR DELETE TO authenticated USING (public.is_admin());

CREATE POLICY product_variants_admin_select ON public.product_variants
  FOR SELECT TO authenticated USING (public.is_admin());
CREATE POLICY product_variants_admin_insert ON public.product_variants
  FOR INSERT TO authenticated WITH CHECK (public.is_admin());
CREATE POLICY product_variants_admin_update ON public.product_variants
  FOR UPDATE TO authenticated
  USING (public.is_admin()) WITH CHECK (public.is_admin());
CREATE POLICY product_variants_admin_delete ON public.product_variants
  FOR DELETE TO authenticated USING (public.is_admin());

CREATE POLICY product_images_admin_select ON public.product_images
  FOR SELECT TO authenticated USING (public.is_admin());
CREATE POLICY product_images_public_select ON public.product_images
  FOR SELECT TO anon, authenticated
  USING (public.product_is_publicly_visible(product_id));
CREATE POLICY product_images_admin_insert ON public.product_images
  FOR INSERT TO authenticated WITH CHECK (public.is_admin());
CREATE POLICY product_images_admin_update ON public.product_images
  FOR UPDATE TO authenticated
  USING (public.is_admin()) WITH CHECK (public.is_admin());
CREATE POLICY product_images_admin_delete ON public.product_images
  FOR DELETE TO authenticated USING (public.is_admin());

CREATE POLICY profiles_select_own ON public.profiles
  FOR SELECT TO authenticated USING (auth.uid() = id);
CREATE POLICY profiles_insert_own ON public.profiles
  FOR INSERT TO authenticated WITH CHECK (auth.uid() = id);
CREATE POLICY profiles_update_own ON public.profiles
  FOR UPDATE TO authenticated
  USING (auth.uid() = id) WITH CHECK (auth.uid() = id);

-- is_admin() is SECURITY DEFINER, so this does not re-enter RLS on admin_users.
CREATE POLICY admin_users_select ON public.admin_users
  FOR SELECT TO authenticated
  USING (public.is_admin());

CREATE POLICY order_requests_select_own ON public.order_requests
  FOR SELECT TO authenticated
  USING (auth.uid() IS NOT NULL AND user_id = auth.uid());

CREATE POLICY order_request_items_select_own ON public.order_request_items
  FOR SELECT TO authenticated
  USING (
    auth.uid() IS NOT NULL
    AND auth.uid() = (
      SELECT r.user_id FROM public.order_requests r WHERE r.id = request_id
    )
  );

CREATE POLICY consultation_requests_select_own ON public.consultation_requests
  FOR SELECT TO authenticated
  USING (auth.uid() IS NOT NULL AND auth.uid() = user_id);

CREATE POLICY info_blocks_public_read ON public.info_blocks
  FOR SELECT TO anon, authenticated
  USING (is_active = true);

CREATE POLICY stores_public_read ON public.stores
  FOR SELECT TO anon, authenticated
  USING (is_active = true);

CREATE POLICY delivery_rules_public_read ON public.delivery_rules
  FOR SELECT TO anon, authenticated
  USING (is_active = true);

CREATE POLICY articles_public_read ON public.articles
  FOR SELECT TO anon, authenticated
  USING (is_published = true);

CREATE POLICY article_blocks_public_read ON public.article_blocks
  FOR SELECT TO anon, authenticated
  USING (
    EXISTS (
      SELECT 1
      FROM public.articles a
      WHERE a.id = article_id
        AND a.is_published = true
    )
  );

CREATE POLICY discount_campaigns_admin_select ON public.discount_campaigns
  FOR SELECT TO authenticated USING (public.is_admin());
CREATE POLICY discount_campaigns_admin_insert ON public.discount_campaigns
  FOR INSERT TO authenticated WITH CHECK (public.is_admin());
CREATE POLICY discount_campaigns_admin_update ON public.discount_campaigns
  FOR UPDATE TO authenticated
  USING (public.is_admin()) WITH CHECK (public.is_admin());
CREATE POLICY discount_campaigns_admin_delete ON public.discount_campaigns
  FOR DELETE TO authenticated USING (public.is_admin());

CREATE POLICY discount_targets_admin_select ON public.discount_campaign_targets
  FOR SELECT TO authenticated USING (public.is_admin());
CREATE POLICY discount_targets_admin_insert ON public.discount_campaign_targets
  FOR INSERT TO authenticated WITH CHECK (public.is_admin());
CREATE POLICY discount_targets_admin_update ON public.discount_campaign_targets
  FOR UPDATE TO authenticated
  USING (public.is_admin()) WITH CHECK (public.is_admin());
CREATE POLICY discount_targets_admin_delete ON public.discount_campaign_targets
  FOR DELETE TO authenticated USING (public.is_admin());

CREATE POLICY discount_redemptions_admin_select ON public.discount_redemptions
  FOR SELECT TO authenticated USING (public.is_admin());
CREATE POLICY discount_redemptions_admin_insert ON public.discount_redemptions
  FOR INSERT TO authenticated WITH CHECK (public.is_admin());
CREATE POLICY discount_redemptions_admin_update ON public.discount_redemptions
  FOR UPDATE TO authenticated
  USING (public.is_admin()) WITH CHECK (public.is_admin());
CREATE POLICY discount_redemptions_admin_delete ON public.discount_redemptions
  FOR DELETE TO authenticated USING (public.is_admin());

-- catalog_sync_* : RLS on, no policies. service_role bypasses RLS.

-- ---------------------------------------------------------------------------
-- Table grants
-- Supabase default privileges grant new public tables to anon/authenticated.
-- Revoke that, then grant only the privileges RLS is prepared to enforce.
-- ---------------------------------------------------------------------------

DO $$
DECLARE
  t text;
BEGIN
  FOREACH t IN ARRAY ARRAY[
    'products',
    'product_variants',
    'product_images',
    'profiles',
    'admin_users',
    'order_requests',
    'order_request_items',
    'consultation_requests',
    'info_blocks',
    'stores',
    'delivery_rules',
    'articles',
    'article_blocks',
    'catalog_sync_runs',
    'catalog_sync_run_errors',
    'discount_campaigns',
    'discount_campaign_targets',
    'discount_redemptions'
  ]
  LOOP
    EXECUTE format('REVOKE ALL ON TABLE public.%I FROM PUBLIC, anon, authenticated', t);
    EXECUTE format('GRANT ALL ON TABLE public.%I TO service_role', t);
  END LOOP;
END $$;

-- 0005 creates the view before this file revokes default privileges.
-- Supabase default privileges otherwise leave TRIGGER, TRUNCATE, and
-- REFERENCES on the view. SELECT is the only public privilege.
REVOKE ALL ON TABLE public.catalog_items FROM PUBLIC, anon, authenticated;
GRANT SELECT ON public.catalog_items TO anon, authenticated, service_role;

GRANT SELECT, INSERT, UPDATE, DELETE ON public.products TO authenticated;
GRANT SELECT, INSERT, UPDATE, DELETE ON public.product_variants TO authenticated;
GRANT SELECT, INSERT, UPDATE, DELETE ON public.product_images TO authenticated;
GRANT SELECT ON public.product_images TO anon;

GRANT SELECT, INSERT, UPDATE ON public.profiles TO authenticated;
GRANT SELECT ON public.admin_users TO authenticated;
GRANT SELECT ON public.order_requests TO authenticated;
GRANT SELECT ON public.order_request_items TO authenticated;
GRANT SELECT ON public.consultation_requests TO authenticated;

GRANT SELECT ON public.info_blocks TO anon, authenticated;
GRANT SELECT ON public.stores TO anon, authenticated;
GRANT SELECT ON public.delivery_rules TO anon, authenticated;
GRANT SELECT ON public.articles TO anon, authenticated;
GRANT SELECT ON public.article_blocks TO anon, authenticated;

GRANT SELECT, INSERT, UPDATE, DELETE ON public.discount_campaigns TO authenticated;
GRANT SELECT, INSERT, UPDATE, DELETE ON public.discount_campaign_targets TO authenticated;
GRANT SELECT, INSERT, UPDATE, DELETE ON public.discount_redemptions TO authenticated;

-- ---------------------------------------------------------------------------
-- Function grants
-- New functions are executable by PUBLIC unless revoked.
-- ---------------------------------------------------------------------------

REVOKE ALL ON FUNCTION public.is_admin() FROM PUBLIC, anon, authenticated;
GRANT EXECUTE ON FUNCTION public.is_admin() TO authenticated, service_role;

REVOKE ALL ON FUNCTION public.product_is_publicly_visible(uuid) FROM PUBLIC;
GRANT EXECUTE ON FUNCTION public.product_is_publicly_visible(uuid)
  TO anon, authenticated, service_role;

REVOKE ALL ON FUNCTION public.get_distinct_brands() FROM PUBLIC;
REVOKE ALL ON FUNCTION public.get_distinct_categories() FROM PUBLIC;
REVOKE ALL ON FUNCTION public.get_distinct_marks() FROM PUBLIC;
GRANT EXECUTE ON FUNCTION public.get_distinct_brands() TO anon, authenticated, service_role;
GRANT EXECUTE ON FUNCTION public.get_distinct_categories() TO anon, authenticated, service_role;
GRANT EXECUTE ON FUNCTION public.get_distinct_marks() TO anon, authenticated, service_role;

REVOKE ALL ON FUNCTION public.admin_set_product_visibility(uuid, boolean) FROM PUBLIC, anon, authenticated;
REVOKE ALL ON FUNCTION public.generate_admin_variant_id() FROM PUBLIC, anon, authenticated;
REVOKE ALL ON FUNCTION public.admin_upsert_native_product(jsonb) FROM PUBLIC, anon, authenticated;
GRANT EXECUTE ON FUNCTION public.admin_set_product_visibility(uuid, boolean) TO authenticated, service_role;
GRANT EXECUTE ON FUNCTION public.generate_admin_variant_id() TO authenticated, service_role;
GRANT EXECUTE ON FUNCTION public.admin_upsert_native_product(jsonb) TO authenticated, service_role;

REVOKE ALL ON FUNCTION public.quote_order_v1(jsonb, jsonb) FROM PUBLIC;
REVOKE ALL ON FUNCTION public.submit_order_v2(jsonb, jsonb) FROM PUBLIC;
REVOKE ALL ON FUNCTION public.submit_order_v3(jsonb, jsonb) FROM PUBLIC;
REVOKE ALL ON FUNCTION public.submit_consultation_v1(jsonb) FROM PUBLIC;
GRANT EXECUTE ON FUNCTION public.quote_order_v1(jsonb, jsonb) TO anon, authenticated, service_role;
GRANT EXECUTE ON FUNCTION public.submit_order_v2(jsonb, jsonb) TO anon, authenticated, service_role;
GRANT EXECUTE ON FUNCTION public.submit_order_v3(jsonb, jsonb) TO anon, authenticated, service_role;
GRANT EXECUTE ON FUNCTION public.submit_consultation_v1(jsonb) TO anon, authenticated, service_role;

REVOKE ALL ON FUNCTION public._discount_text_match(text, text, text) FROM PUBLIC, anon, authenticated;
REVOKE ALL ON FUNCTION public.set_discount_campaigns_updated_at() FROM PUBLIC, anon, authenticated;
