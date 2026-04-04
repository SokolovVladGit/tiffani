-- ============================================================
-- PARKED — Tilda auto-sync is disabled.
-- Catalog management moved to admin panel (2026-04-04).
--
-- If this migration was already applied, disable with:
--   SELECT cron.unschedule('catalog-sync-every-10min');
--
-- The migration below is kept for reference / future re-enablement.
-- ============================================================
-- Cron scheduler for catalog-sync Edge Function
-- Requires pg_cron + pg_net extensions (available on all Supabase plans)
-- ============================================================

CREATE EXTENSION IF NOT EXISTS pg_cron;
CREATE EXTENSION IF NOT EXISTS pg_net;

-- ============================================================
-- BEFORE RUNNING THIS MIGRATION, configure database secrets:
--
--   ALTER DATABASE postgres
--     SET app.settings.service_role_key = '<your-service-role-key>';
--
--   ALTER DATABASE postgres
--     SET app.settings.supabase_url = 'https://<project-ref>.supabase.co';
--
-- These are read at cron execution time, NOT at migration time.
-- If not set, the cron job will fire but the HTTP call will fail
-- with an auth error (safe — no data corruption).
-- ============================================================

SELECT cron.schedule(
  'catalog-sync-every-10min',
  '*/10 * * * *',
  $$
  SELECT net.http_post(
    url    := current_setting('app.settings.supabase_url', true)
              || '/functions/v1/catalog-sync',
    headers := jsonb_build_object(
      'Authorization', 'Bearer ' || current_setting('app.settings.service_role_key', true),
      'Content-Type',  'application/json'
    ),
    body   := '{"source":"cron"}'::jsonb
  );
  $$
);

-- ============================================================
-- Management commands (run manually as needed):
--
-- View scheduled jobs:
--   SELECT * FROM cron.job;
--
-- View recent executions:
--   SELECT * FROM cron.job_run_details ORDER BY start_time DESC LIMIT 20;
--
-- Pause sync:
--   SELECT cron.unschedule('catalog-sync-every-10min');
--
-- Resume sync:
--   (Re-run the SELECT cron.schedule(...) above)
--
-- Change interval to every 30 minutes:
--   SELECT cron.alter_job(
--     job_id := (SELECT jobid FROM cron.job WHERE jobname = 'catalog-sync-every-10min'),
--     schedule := '*/30 * * * *'
--   );
-- ============================================================
