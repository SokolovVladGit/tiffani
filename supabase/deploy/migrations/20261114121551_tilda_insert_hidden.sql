-- TIFFANI: new Tilda products stay hidden until an admin approves them.
--
-- INSERT only. An existing row is not rewritten, so a later YML upsert
-- cannot change app_is_visible. Native products (tilda_uid IS NULL) keep
-- the column default.
--
-- Does not delete products, variants, or images.
-- Does not schedule cron.
-- Do not apply until this file has been reviewed. The hosted project
-- still has the column default of true.

BEGIN;

CREATE OR REPLACE FUNCTION public.hide_new_tilda_product()
RETURNS trigger
LANGUAGE plpgsql
SET search_path = pg_catalog
AS $$
BEGIN
  IF NEW.tilda_uid IS NOT NULL THEN
    NEW.app_is_visible := false;
  END IF;
  RETURN NEW;
END;
$$;

DROP TRIGGER IF EXISTS products_hide_new_tilda ON public.products;

CREATE TRIGGER products_hide_new_tilda
  BEFORE INSERT ON public.products
  FOR EACH ROW
  EXECUTE FUNCTION public.hide_new_tilda_product();

COMMENT ON FUNCTION public.hide_new_tilda_product() IS
  'Forces app_is_visible false when a Tilda product is inserted. '
  'Updates, including admin_set_product_visibility, are not affected.';

COMMIT;

-- Verification after a human applies this file. These statements are
-- comments; they do not run with the migration.
--
-- New Tilda row:
--   INSERT INTO public.products (tilda_uid, title)
--   VALUES ('visibility-probe', 'probe')
--   RETURNING app_is_visible;  -- false
-- Then remove that probe row in the same session.
--
-- Existing visibility is unchanged by a title upsert:
--   SELECT id, app_is_visible FROM public.products WHERE tilda_uid = '<existing>';
--
-- Admin approval still works for a Tilda id:
--   SELECT public.admin_set_product_visibility('<product-uuid>'::uuid, true);
