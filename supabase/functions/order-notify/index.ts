import { createClient, type SupabaseClient } from "https://esm.sh/@supabase/supabase-js@2";
import {
  buildMessage,
  type OrderItem,
  type OrderRequest,
} from "./render.ts";
import {
  bearerMatches,
  classifyTelegramHttp,
  dispatchLimit,
  orderMissingFailure,
  transportFailure,
  WORKER_SECRET_NAME,
  type DeliveryFailure,
} from "./worker.ts";

// Server-side worker. pg_net calls this with ORDER_NOTIFY_WORKER_SECRET.
// verify_jwt is false because that caller has no user JWT. The secret is
// checked before any order row is read. The body cannot choose an order.

const ORDER_SELECT = [
  "id",
  "customer_name",
  "phone",
  "email",
  "delivery_method",
  "delivery_address",
  "payment_method",
  "fulfillment_type",
  "fulfillment_method_code",
  "fulfillment_fee",
  "pickup_store_id",
  "delivery_zone_code",
  "payment_method_code",
  "promo_code",
  "loyalty_card",
  "comment",
  "total_items",
  "total_quantity",
  "total_price",
  "status",
  "source",
  "created_at",
  "subtotal_amount",
  "discount_amount",
  "grand_total_amount",
  "applied_promocode_code",
  "applied_discount_snapshot",
  "pricing_version",
  "pricing_metadata",
].join(", ");

const ITEM_SELECT = [
  "variant_id",
  "title",
  "brand",
  "price",
  "quantity",
  "line_total",
  "edition",
  "modification",
  "unit_price_amount",
  "line_subtotal_amount",
  "line_discount_amount",
  "line_total_amount",
  "applied_discount_snapshot",
].join(", ");

type ClaimedJob = {
  job_id: string;
  order_id: string;
  attempts: number;
};

type QueryResult = { data: unknown; error: { message?: string } | null };

type OrderQuery = {
  eq(column: string, value: string): {
    maybeSingle(): Promise<QueryResult>;
    order(column: string, options: { ascending: boolean }): Promise<QueryResult>;
  };
};

// Untyped supabase-js treats unknown RPCs as no-arg. These three functions
// are created by the outbox migration and are not in a generated Database type.
type WorkerDb = {
  rpc(fn: string, args?: Record<string, unknown>): Promise<QueryResult>;
  from(relation: string): { select(columns: string): OrderQuery };
};

function workerDb(url: string, key: string): WorkerDb {
  const client: SupabaseClient = createClient(url, key, {
    auth: { persistSession: false },
  });
  return client as unknown as WorkerDb;
}

Deno.serve(async (req) => {
  if (req.method !== "POST") {
    return json({ error: "method_not_allowed" }, 405);
  }

  const secret = Deno.env.get(WORKER_SECRET_NAME);
  if (!bearerMatches(req.headers.get("Authorization"), secret)) {
    return json({ error: "unauthorized" }, 401);
  }

  const supabaseUrl = Deno.env.get("SUPABASE_URL");
  const serviceKey = Deno.env.get("SUPABASE_SERVICE_ROLE_KEY");
  const botToken = Deno.env.get("TELEGRAM_BOT_TOKEN");
  const chatId = Deno.env.get("TELEGRAM_CHAT_ID");
  if (!supabaseUrl || !serviceKey || !botToken || !chatId) {
    return json({ error: "worker_not_configured" }, 500);
  }

  let limit = 5;
  try {
    const text = await req.text();
    limit = dispatchLimit(text.trim() === "" ? null : JSON.parse(text));
  } catch {
    return json({ error: "bad_request" }, 400);
  }

  const client = workerDb(supabaseUrl, serviceKey);

  const { data: claimed, error: claimError } = await client.rpc(
    "claim_order_notification_jobs",
    { p_limit: limit },
  );
  if (claimError) {
    console.error("order-notify claim failed");
    return json({ error: "claim_failed" }, 500);
  }

  const jobs = (claimed ?? []) as ClaimedJob[];
  let sent = 0;
  let failed = 0;

  for (const job of jobs) {
    const outcome = await deliverJob(client, botToken, chatId, job);
    if (outcome === "sent") sent += 1;
    else failed += 1;
  }

  return json({ claimed: jobs.length, sent, failed });
});

async function deliverJob(
  client: WorkerDb,
  botToken: string,
  chatId: string,
  job: ClaimedJob,
): Promise<"sent" | "failed"> {
  const { data: order, error: orderErr } = await client
    .from("order_requests")
    .select(ORDER_SELECT)
    .eq("id", job.order_id)
    .maybeSingle();

  if (orderErr || !order) {
    await markFailed(client, job.job_id, orderMissingFailure());
    return "failed";
  }

  const { data: items, error: itemsErr } = await client
    .from("order_request_items")
    .select(ITEM_SELECT)
    .eq("request_id", job.order_id)
    .order("id", { ascending: true });

  if (itemsErr) {
    await markFailed(client, job.job_id, transportFailure());
    return "failed";
  }

  const message = buildMessage(
    order as unknown as OrderRequest,
    (items ?? []) as unknown as OrderItem[],
  );

  let telegram: { ok?: boolean; result?: { message_id?: number } };
  let status = 0;
  try {
    const response = await sendTelegram(botToken, chatId, message);
    status = response.status;
    telegram = response.body;
  } catch {
    await markFailed(client, job.job_id, transportFailure());
    return "failed";
  }

  if (!telegram.ok) {
    await markFailed(client, job.job_id, classifyTelegramHttp(status));
    return "failed";
  }

  const messageId = telegram.result?.message_id ?? null;
  const { error } = await client.rpc("complete_order_notification_job", {
    p_job_id: job.job_id,
    p_message_id: messageId,
  });
  if (error) {
    console.error("order-notify complete failed", job.job_id);
    return "failed";
  }
  return "sent";
}

async function markFailed(
  client: WorkerDb,
  jobId: string,
  failure: DeliveryFailure,
): Promise<void> {
  const { error } = await client.rpc("fail_order_notification_job", {
    p_job_id: jobId,
    p_error: failure.code,
    p_retryable: failure.retryable,
  });
  if (error) console.error("order-notify fail record failed", jobId);
}

async function sendTelegram(
  botToken: string,
  chatId: string,
  text: string,
): Promise<{ status: number; body: { ok?: boolean; result?: { message_id?: number } } }> {
  const response = await fetch(
    `https://api.telegram.org/bot${botToken}/sendMessage`,
    {
      method: "POST",
      headers: { "Content-Type": "application/json" },
      signal: AbortSignal.timeout(10_000),
      body: JSON.stringify({
        chat_id: chatId,
        text,
        parse_mode: "HTML",
      }),
    },
  );
  const body = await response.json();
  return { status: response.status, body };
}

function json(body: unknown, status = 200): Response {
  return new Response(JSON.stringify(body), {
    status,
    headers: { "Content-Type": "application/json" },
  });
}
