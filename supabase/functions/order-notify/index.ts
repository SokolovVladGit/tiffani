import { createClient } from "https://esm.sh/@supabase/supabase-js@2";

const CORS_HEADERS = {
  "Access-Control-Allow-Origin": "*",
  "Access-Control-Allow-Headers":
    "authorization, x-client-info, apikey, content-type",
};

// ---------------------------------------------------------------------------
// Types
// ---------------------------------------------------------------------------

interface OrderRequest {
  id: string;
  customer_name: string;
  phone: string;
  email: string | null;
  // Legacy readable fields.
  delivery_method: string | null;
  delivery_address: string | null;
  payment_method: string | null;
  // Canonical fulfillment fields.
  fulfillment_type: string | null;
  fulfillment_method_code: string | null;
  fulfillment_fee: number | null;
  pickup_store_id: string | null;
  delivery_zone_code: string | null;
  // Canonical payment field.
  payment_method_code: string | null;
  // Extras.
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

// ---------------------------------------------------------------------------
// Label maps (canonical code → human-readable Russian)
// ---------------------------------------------------------------------------

const FULFILLMENT_LABELS: Record<string, string> = {
  pickup_store: "Самовывоз из магазина",
  courier_tiraspol: "Доставка курьером по Тирасполю",
  courier_bender: "Доставка курьером по Бендерам",
  express_post: "Доставка экспресс-почтой",
  moldova_post: "Доставка почтой Молдовы",
};

const PAYMENT_LABELS: Record<string, string> = {
  cash: "Наличные",
  mobile_payment: "Мобильный платёж",
  bank_transfer: "Оплата по реквизитам банка",
  clever_installment: "Беспроцентная рассрочка по карте Клевер",
};

const PICKUP_STORE_LABELS: Record<string, string> = {
  store_central: "Тирасполь, ул. 25 Октября 94",
  store_balka: "Тирасполь, ул. Юности 18/1",
  store_bendery: "Бендеры, ул. Ленина 15, ТЦ «Пассаж» бутик №14",
};

// ---------------------------------------------------------------------------
// Handler
// ---------------------------------------------------------------------------

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
        "id, customer_name, phone, email, " +
        "delivery_method, delivery_address, payment_method, " +
        "fulfillment_type, fulfillment_method_code, fulfillment_fee, " +
        "pickup_store_id, delivery_zone_code, payment_method_code, " +
        "promo_code, loyalty_card, comment, " +
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

    const message = buildMessage(
      order as OrderRequest,
      (items ?? []) as OrderItem[],
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

// ---------------------------------------------------------------------------
// Message builder
// ---------------------------------------------------------------------------

function buildMessage(order: OrderRequest, items: OrderItem[]): string {
  const shortId = order.id.slice(0, 8).toUpperCase();
  const L: string[] = [];

  // --- Header ---
  L.push(`🛒 <b>Новый заказ #${esc(shortId)}</b>`);

  // --- Customer ---
  L.push("");
  L.push("<b>👤 Клиент</b>");
  L.push(`Имя: ${esc(order.customer_name)}`);
  L.push(`Телефон: ${esc(order.phone)}`);
  if (order.email) {
    L.push(`Email: ${esc(order.email)}`);
  }

  // --- Fulfillment ---
  const isPickup = resolveIsPickup(order);
  const fulfillmentLabel = resolveFulfillmentLabel(order);
  const fee = order.fulfillment_fee ?? 0;

  L.push("");
  L.push("<b>🚚 Получение</b>");
  L.push(`Способ: ${esc(fulfillmentLabel)}`);

  if (isPickup) {
    const storeLabel = resolvePickupStoreLabel(order);
    if (storeLabel) {
      L.push(`Магазин: ${esc(storeLabel)}`);
    }
  } else {
    if (order.delivery_address) {
      L.push(`Адрес: ${esc(order.delivery_address)}`);
    }
  }

  // --- Payment ---
  const paymentLabel = resolvePaymentLabel(order);
  L.push("");
  L.push("<b>💳 Оплата</b>");
  L.push(`Способ: ${esc(paymentLabel)}`);

  // --- Items ---
  if (items.length > 0) {
    L.push("");
    L.push("<b>📦 Состав заказа</b>");
    for (let i = 0; i < items.length; i++) {
      const it = items[i];
      const title = it.title ?? it.variant_id;
      const titleLower = title.toLowerCase();
      const lineTotal = fmtPrice(
        it.line_total ?? (it.price ?? 0) * it.quantity,
      );

      let line = `${i + 1}. ${esc(title)}`;

      if (it.brand && !titleLower.includes(it.brand.toLowerCase())) {
        line += `\n    Бренд: ${esc(it.brand)}`;
      }

      const variant = normalizeVariant(it.edition, it.modification);
      if (variant && !titleLower.includes(variant.toLowerCase())) {
        line += `\n    Объём: ${esc(variant)}`;
      }

      line += `\n    ×${it.quantity} — ${lineTotal}`;
      L.push(line);
    }
  }

  // --- Totals ---
  const totalGoods = order.total_price ?? 0;
  const grandTotal = totalGoods + fee;

  L.push("");
  L.push("<b>📊 Итого</b>");
  L.push(`Позиций: ${order.total_items}`);
  L.push(`Количество товаров: ${order.total_quantity}`);
  L.push(`Товары: ${fmtPrice(totalGoods)}`);
  L.push(`Доставка: ${fmtPrice(fee)}`);
  L.push(`<b>Итого к оплате: ${fmtPrice(grandTotal)}</b>`);

  // --- Optional extras ---
  if (order.promo_code || order.loyalty_card) {
    L.push("");
    if (order.promo_code) {
      L.push(`🏷 Промокод: ${esc(order.promo_code)}`);
    }
    if (order.loyalty_card) {
      L.push(`💳 Карта клиента: ${esc(order.loyalty_card)}`);
    }
  }

  if (order.comment) {
    L.push("");
    L.push(`💬 Комментарий:\n${esc(order.comment)}`);
  }

  return L.join("\n");
}

// ---------------------------------------------------------------------------
// Resolvers (canonical first, legacy fallback)
// ---------------------------------------------------------------------------

function resolveIsPickup(order: OrderRequest): boolean {
  if (order.fulfillment_type) {
    return order.fulfillment_type === "pickup";
  }
  if (order.delivery_method) {
    const dm = order.delivery_method.toLowerCase();
    return dm.includes("самовывоз");
  }
  return false;
}

function resolveFulfillmentLabel(order: OrderRequest): string {
  if (order.fulfillment_method_code) {
    return (
      FULFILLMENT_LABELS[order.fulfillment_method_code] ??
      order.fulfillment_method_code
    );
  }
  return order.delivery_method ?? "Не указан";
}

function resolvePickupStoreLabel(order: OrderRequest): string | null {
  if (order.pickup_store_id) {
    const known = PICKUP_STORE_LABELS[order.pickup_store_id];
    if (known) return known;
    return order.pickup_store_id;
  }
  return order.delivery_address ?? null;
}

function resolvePaymentLabel(order: OrderRequest): string {
  if (order.payment_method_code) {
    return (
      PAYMENT_LABELS[order.payment_method_code] ??
      order.payment_method_code
    );
  }
  return order.payment_method ?? "Не указан";
}

// ---------------------------------------------------------------------------
// Helpers
// ---------------------------------------------------------------------------

function normalizeVariant(
  edition: string | null,
  modification: string | null,
): string | null {
  const parts: string[] = [];
  if (edition) parts.push(edition.trim());
  if (modification) parts.push(modification.trim());
  if (parts.length === 0) return null;

  let raw = parts.join(", ");
  // Strip redundant leading labels like "Объем:" / "Объём:" already in data.
  raw = raw.replace(/^Объ[её]м\s*:\s*/i, "").trim();
  // Normalize spacing around units: "30мл" → "30 мл", "100 мл" stays.
  raw = raw.replace(/(\d)\s*(мл|г|ml|шт)\b/gi, "$1 $2");
  return raw || null;
}

function fmtPrice(value: number | null): string {
  if (value == null) return "0 ₽";
  if (value === Math.floor(value)) return `${value} ₽`;
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
