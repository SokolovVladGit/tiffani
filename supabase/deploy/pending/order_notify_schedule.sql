-- Manual schedule. Not a migration. Do not apply until:
--   1. 20261115163000_order_notification_outbox.sql is applied
--   2. order-notify is deployed
--   3. pg_cron and pg_net are enabled in the dashboard
--   4. vault secret ORDER_NOTIFY_WORKER_SECRET exists and is at least 32 characters
--
-- The secret is read from vault on every run. It is not written into this file.

DO $$
DECLARE
  v_secret text;
BEGIN
  IF NOT EXISTS (SELECT 1 FROM pg_extension WHERE extname = 'pg_cron') THEN
    RAISE EXCEPTION 'enable pg_cron in the dashboard before scheduling order-notify';
  END IF;
  IF NOT EXISTS (SELECT 1 FROM pg_extension WHERE extname = 'pg_net') THEN
    RAISE EXCEPTION 'enable pg_net in the dashboard before scheduling order-notify';
  END IF;

  SELECT decrypted_secret
  INTO v_secret
  FROM vault.decrypted_secrets
  WHERE name = 'ORDER_NOTIFY_WORKER_SECRET'
  LIMIT 1;

  IF v_secret IS NULL OR length(v_secret) < 32 THEN
    RAISE EXCEPTION 'vault secret ORDER_NOTIFY_WORKER_SECRET is missing or shorter than 32 characters';
  END IF;
END $$;

DO $$
BEGIN
  PERFORM cron.unschedule('order-notify-dispatch');
EXCEPTION
  WHEN undefined_function OR invalid_parameter_value THEN
    NULL;
  WHEN OTHERS THEN
    IF SQLERRM ILIKE '%could not find%' OR SQLERRM ILIKE '%job%' THEN
      NULL;
    ELSE
      RAISE;
    END IF;
END $$;

SELECT cron.schedule(
  'order-notify-dispatch',
  '* * * * *',
  $cron$
  SELECT net.http_post(
    url := 'https://mnjxcoyvomgbdtwdhejq.supabase.co/functions/v1/order-notify',
    headers := jsonb_build_object(
      'Content-Type', 'application/json',
      'Authorization', 'Bearer ' || (
        SELECT decrypted_secret
        FROM vault.decrypted_secrets
        WHERE name = 'ORDER_NOTIFY_WORKER_SECRET'
        LIMIT 1
      )
    ),
    body := '{"limit":5}'::jsonb,
    timeout_milliseconds := 90000
  );
  $cron$
);
