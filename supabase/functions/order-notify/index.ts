import { createClient } from "https://esm.sh/@supabase/supabase-js@2";

const CORS_HEADERS = {
  "Access-Control-Allow-Origin": "*",
  "Access-Control-Allow-Headers":
    "authorization, x-client-info, apikey, content-type",
};

interface OrderRequest {
  id: string;
  customer_name: string;
  phone: string;
  email: string | null;
  delivery_method: string | null;
  delivery_address: string | null;
  payment_method: string | null;
  promo_code: string | null;
  loyalty_card: string | null;
  comment: string | null;
  total_items: number;
  total_quantity: number;
  total_price: number;
  status: string;
  source: string;
  created_at: string;
}

interface OrderItem {
  variant_id: string;
  title: string | null;
  brand: string | null;
  price: number | null;
  quantity: number;
  line_total: number | null;
  edition: string | null;
  modification: string | null;
}

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
      .select(
        "id, customer_name, phone, email, delivery_method, delivery_address, " +
        "payment_method, promo_code, loyalty_card, comment, " +
        "total_items, total_quantity, total_price, status, source, created_at",
      )
      .eq("id", orderId)
      .single();

    if (orderErr || !order) {
      return json({ error: `Order not found: ${orderId}` }, 404);
    }

    const { data: items, error: itemsErr } = await client
      .from("order_request_items")
      .select(
        "variant_id, title, brand, price, quantity, line_total, edition, modification",
      )
      .eq("request_id", orderId)
      .order("id", { ascending: true });

    if (itemsErr) {
      return json({ error: `Failed to load items: ${itemsErr.message}` }, 500);
    }

    const message = buildMessage(order as OrderRequest, (items ?? []) as OrderItem[]);

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

function buildMessage(order: OrderRequest, items: OrderItem[]): string {
  const shortId = order.id.slice(0, 8).toUpperCase();
  const lines: string[] = [];

  lines.push(`🛒 <b>Новый заказ #${esc(shortId)}</b>`);
  lines.push("");
  lines.push(`👤 ${esc(order.customer_name)}`);
  lines.push(`📞 ${esc(order.phone)}`);
  lines.push(`📧 ${esc(order.email ?? "—")}`);
  lines.push("");
  lines.push(`🚚 ${esc(order.delivery_method ?? "—")}`);
  lines.push(`📍 ${esc(order.delivery_address ?? "—")}`);
  lines.push(`💳 ${esc(order.payment_method ?? "—")}`);
  lines.push("");
  lines.push(
    `📦 Позиций: ${order.total_items} · Кол-во: ${order.total_quantity}`,
  );
  lines.push(`💰 <b>Итого: ${formatPrice(order.total_price)}</b>`);

  if (items.length > 0) {
    lines.push("");
    lines.push("—— Состав ——");
    for (let i = 0; i < items.length; i++) {
      const it = items[i];
      const label = it.title ?? it.variant_id;
      const brand = it.brand ? ` (${esc(it.brand)})` : "";
      const mods: string[] = [];
      if (it.edition) mods.push(it.edition);
      if (it.modification) mods.push(it.modification);
      const modStr = mods.length > 0 ? ` [${esc(mods.join(", "))}]` : "";
      const total = formatPrice(it.line_total ?? (it.price ?? 0) * it.quantity);
      lines.push(
        `${i + 1}. ${esc(label)}${brand}${modStr} × ${it.quantity} — ${total}`,
      );
    }
  }

  if (order.promo_code || order.loyalty_card || order.comment) {
    lines.push("");
    if (order.promo_code) lines.push(`🏷 Промокод: ${esc(order.promo_code)}`);
    if (order.loyalty_card) {
      lines.push(`🃏 Карта клиента: ${esc(order.loyalty_card)}`);
    }
    if (order.comment) lines.push(`💬 ${esc(order.comment)}`);
  }

  return lines.join("\n");
}

function formatPrice(value: number | null): string {
  if (value == null) return "—";
  return `${value.toFixed(2)} ₽`;
}

function esc(text: string): string {
  return text
    .replace(/&/g, "&amp;")
    .replace(/</g, "&lt;")
    .replace(/>/g, "&gt;");
}

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
