-- TIFFANI catalog schedule placeholder.
-- This file is not a migration and must not be applied.
-- pg_cron is not installed on the hosted project. Installing a schedule
-- before product_images.source exists and before catalog-gallery-recover
-- is deployed would either fail or scrape on a schema the app cannot use.

DO $$
BEGIN
  RAISE EXCEPTION
    'catalog schedule is not ready: apply product_images.source, deploy the compatible functions, then install cron in a separate reviewed step';
END $$;
