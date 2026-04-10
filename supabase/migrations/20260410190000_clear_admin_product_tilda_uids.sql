-- ============================================================
-- Clear tilda_uid for admin-created products.
--
-- The backfill (20260404120000) set tilda_uid = id::text for
-- legacy products, giving them UUID-format tilda_uids.  This
-- makes the sync deactivation step treat them as Tilda-sourced
-- — which they are not.
--
-- After this migration:
--   Admin products: tilda_uid = NULL → excluded from sync
--   Tilda products: tilda_uid = numeric Tilda ID → managed by sync
-- ============================================================

UPDATE products
   SET tilda_uid = NULL
 WHERE tilda_uid LIKE '%-%';
