import { assert, assertEquals } from "jsr:@std/assert@1";

const migrationUrl = new URL(
  "../../deploy/migrations/20261115163000_order_notification_outbox.sql",
  import.meta.url,
);

Deno.test("order notification outbox is one job per new order", async () => {
  const sql = await Deno.readTextFile(migrationUrl);

  assert(sql.includes("CREATE TABLE private.order_notification_jobs"));
  assert(sql.includes("order_id              uuid        NOT NULL UNIQUE"));
  assert(sql.includes("AFTER INSERT ON public.order_requests"));
  assert(sql.includes("VALUES (NEW.id)"));
  assert(sql.includes("ON CONFLICT (order_id) DO NOTHING"));
  assert(sql.includes("status IN ('pending', 'processing', 'sent', 'dead')"));
  assert(sql.includes("attempts"));
  assert(sql.includes("max_attempts          integer     NOT NULL DEFAULT 5"));
  assert(sql.includes("last_error"));
  assert(sql.includes("created_at"));
  assert(sql.includes("updated_at"));
  assert(sql.includes("sent_at"));
  assert(sql.includes("telegram_message_id"));
  assertEquals(sql.includes("user_id"), false);
  assertEquals(sql.includes("INSERT INTO private.order_notification_jobs (order_id)\n  SELECT"), false);
  assertEquals(sql.includes("DELETE FROM public.order_requests"), false);
  assertEquals(sql.includes("UPDATE public.order_requests"), false);
});

Deno.test("claim is locked, bounded, and hidden from the client roles", async () => {
  const sql = await Deno.readTextFile(migrationUrl);

  assert(sql.includes("FOR UPDATE SKIP LOCKED"));
  assert(sql.includes("j.attempts < j.max_attempts"));
  assert(sql.includes("locked_until <= now()"));
  assert(sql.includes("last_error = 'lease_expired'"));
  assert(sql.includes("ENABLE ROW LEVEL SECURITY"));
  assert(sql.includes("REVOKE ALL ON TABLE private.order_notification_jobs FROM PUBLIC, anon, authenticated"));
  assert(sql.includes("REVOKE ALL ON FUNCTION public.claim_order_notification_jobs(integer) FROM PUBLIC, anon, authenticated"));
  assert(sql.includes("GRANT EXECUTE ON FUNCTION public.claim_order_notification_jobs(integer) TO service_role"));
  assert(sql.includes("GRANT EXECUTE ON FUNCTION public.complete_order_notification_job(uuid, bigint) TO service_role"));
  assert(sql.includes("GRANT EXECUTE ON FUNCTION public.fail_order_notification_job(uuid, text, boolean) TO service_role"));
  assert(sql.includes("least(power(2, j.attempts)::int, 60)"));
});
