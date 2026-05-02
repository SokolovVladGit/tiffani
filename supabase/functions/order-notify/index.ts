import { createClient } from "https://esm.sh/@supabase/supabase-js@2";
import {
  buildMessage,
  type OrderItem,
  type OrderRequest,
} from "./render.ts";

// ============================================================================
// order-notify Edge Function — Phase 3 (discount-aware).
//
// The handler is intentionally thin: validate input, fetch the order +
// items including Phase 1 snapshot columns, hand off to the pure render
// module, and POST the resulting HTML to Telegram.
//
// Old v2 orders (pre-Phase 1 columns are NULL) keep the prior message
// shape exactly. v3 orders with discount_amount > 0 get a discount-aware
// money block + "Применённые скидки" identity block. See render.ts.
//
// Telegram is never source of truth: this function ONLY renders persisted
// order snapshot fields and never recomputes which discounts apply.
// ============================================================================

const CORS_HEADERS = {
  "Access-Control-Allow-Origin": "*",
  "Access-Control-Allow-Headers":
    "authorization, x-client-info, apikey, content-type",
};

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
  // Phase 1 additive snapshot columns (NULL on old v2 orders).
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
  // Phase 1 additive per-line snapshot columns (NULL on old v2 orders).
  "unit_price_amount",
  "line_subtotal_amount",
  "line_discount_amount",
  "line_total_amount",
  "applied_discount_snapshot",
].join(", ");

Deno.serve(async (req) => {
  if (req.method === "OPTIONS") {
    return json("ok", 200);
  }

  const supabaseUrl = Deno.env.get("SUPABASE_URL");
  const serviceKey = Deno.env.get("SUPABASE_SERVICE_ROLE_KEY");
  const botToken = Deno.env.get("TELEGRAM_BOT_TOKEN");
  const chatId = Deno.env.get("TELEGRAM_CHAT_ID");

  if (!supabaseUrl || !serviceKey) {
    return json({ error: "Missing Supabase credentials" }, 500);
  }
  if (!botToken || !chatId) {
    return json({ error: "Missing Telegram credentials" }, 500);
  }

  let orderId: string;
  try {
    const body = await req.json();
    orderId = body?.order_id;
    if (!orderId) throw new Error("order_id is required");
  } catch (e) {
    return json({ error: (e as Error).message }, 400);
  }

  const client = createClient(supabaseUrl, serviceKey, {
    auth: { persistSession: false },
  });

  try {
    const { data: order, error: orderErr } = await client
      .from("order_requests")
      .select(ORDER_SELECT)
      .eq("id", orderId)
      .single();

    if (orderErr || !order) {
      return json({ error: `Order not found: ${orderId}` }, 404);
    }

    const { data: items, error: itemsErr } = await client
      .from("order_request_items")
      .select(ITEM_SELECT)
      .eq("request_id", orderId)
      .order("id", { ascending: true });

    if (itemsErr) {
      return json({ error: `Failed to load items: ${itemsErr.message}` }, 500);
    }

    const message = buildMessage(
      order as unknown as OrderRequest,
      (items ?? []) as unknown as OrderItem[],
    );

    const sent = await sendTelegram(botToken, chatId, message);
    if (!sent.ok) {
      console.error("Telegram API error:", JSON.stringify(sent));
      return json({ error: "Telegram send failed", details: sent }, 502);
    }

    return json({ success: true, order_id: orderId });
  } catch (e) {
    console.error("order-notify error:", e);
    return json({ error: (e as Error).message }, 500);
  }
});

async function sendTelegram(
  botToken: string,
  chatId: string,
  text: string,
): Promise<{ ok: boolean; description?: string }> {
  const url = `https://api.telegram.org/bot${botToken}/sendMessage`;
  const res = await fetch(url, {
    method: "POST",
    headers: { "Content-Type": "application/json" },
    body: JSON.stringify({
      chat_id: chatId,
      text,
      parse_mode: "HTML",
    }),
  });
  return res.json();
}

function json(body: unknown, status = 200): Response {
  return new Response(JSON.stringify(body), {
    status,
    headers: { "Content-Type": "application/json", ...CORS_HEADERS },
  });
}
