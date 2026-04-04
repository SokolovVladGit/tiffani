-- ============================================================
-- Admin panel: auth gate + RLS policies for catalog management
--
-- Approach:
--   1. admin_users table whitelists Supabase Auth user IDs
--   2. is_admin() helper checks membership
--   3. RLS on products, product_variants, product_images:
--      - SELECT open to all roles (mobile app uses anon)
--      - INSERT/UPDATE/DELETE restricted to admin users
-- ============================================================

-- 1. Admin users registry
CREATE TABLE IF NOT EXISTS admin_users (
  id         uuid        PRIMARY KEY DEFAULT gen_random_uuid(),
  user_id    uuid        NOT NULL UNIQUE,
  email      text,
  created_at timestamptz NOT NULL DEFAULT now()
);

ALTER TABLE admin_users ENABLE ROW LEVEL SECURITY;

-- Admins can read the admin list
DROP POLICY IF EXISTS admin_users_select ON admin_users;
CREATE POLICY admin_users_select ON admin_users
  FOR SELECT TO authenticated
  USING (EXISTS (SELECT 1 FROM admin_users au WHERE au.user_id = auth.uid()));

-- 2. Helper function
CREATE OR REPLACE FUNCTION is_admin()
RETURNS boolean
LANGUAGE sql
SECURITY DEFINER
STABLE
AS $$
  SELECT EXISTS (SELECT 1 FROM admin_users WHERE user_id = auth.uid());
$$;

-- 3. Enable RLS on catalog tables (idempotent)
ALTER TABLE products ENABLE ROW LEVEL SECURITY;
ALTER TABLE product_variants ENABLE ROW LEVEL SECURITY;
ALTER TABLE product_images ENABLE ROW LEVEL SECURITY;

-- 4. Read access for all roles (preserves mobile app access)
DROP POLICY IF EXISTS products_select_all ON products;
CREATE POLICY products_select_all ON products
  FOR SELECT USING (true);

DROP POLICY IF EXISTS product_variants_select_all ON product_variants;
CREATE POLICY product_variants_select_all ON product_variants
  FOR SELECT USING (true);

DROP POLICY IF EXISTS product_images_select_all ON product_images;
CREATE POLICY product_images_select_all ON product_images
  FOR SELECT USING (true);

-- 5. Admin write access — products
DROP POLICY IF EXISTS products_admin_insert ON products;
CREATE POLICY products_admin_insert ON products
  FOR INSERT TO authenticated WITH CHECK (is_admin());

DROP POLICY IF EXISTS products_admin_update ON products;
CREATE POLICY products_admin_update ON products
  FOR UPDATE TO authenticated
  USING (is_admin()) WITH CHECK (is_admin());

DROP POLICY IF EXISTS products_admin_delete ON products;
CREATE POLICY products_admin_delete ON products
  FOR DELETE TO authenticated USING (is_admin());

-- 6. Admin write access — product_variants
DROP POLICY IF EXISTS product_variants_admin_insert ON product_variants;
CREATE POLICY product_variants_admin_insert ON product_variants
  FOR INSERT TO authenticated WITH CHECK (is_admin());

DROP POLICY IF EXISTS product_variants_admin_update ON product_variants;
CREATE POLICY product_variants_admin_update ON product_variants
  FOR UPDATE TO authenticated
  USING (is_admin()) WITH CHECK (is_admin());

DROP POLICY IF EXISTS product_variants_admin_delete ON product_variants;
CREATE POLICY product_variants_admin_delete ON product_variants
  FOR DELETE TO authenticated USING (is_admin());

-- 7. Admin write access — product_images
DROP POLICY IF EXISTS product_images_admin_insert ON product_images;
CREATE POLICY product_images_admin_insert ON product_images
  FOR INSERT TO authenticated WITH CHECK (is_admin());

DROP POLICY IF EXISTS product_images_admin_update ON product_images;
CREATE POLICY product_images_admin_update ON product_images
  FOR UPDATE TO authenticated
  USING (is_admin()) WITH CHECK (is_admin());

DROP POLICY IF EXISTS product_images_admin_delete ON product_images;
CREATE POLICY product_images_admin_delete ON product_images
  FOR DELETE TO authenticated USING (is_admin());

-- ============================================================
-- AFTER applying this migration, create the first admin user:
--
-- 1. Create a Supabase Auth user via dashboard or CLI
-- 2. Insert into admin_users:
--    INSERT INTO admin_users (user_id, email)
--    VALUES ('<auth-user-uuid>', 'admin@tiffani.md');
-- ============================================================
