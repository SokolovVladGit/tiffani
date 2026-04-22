// consultation-notify
//
// Reads a consultation_requests row by id and posts a short Telegram
// notification to the manager chat. DB is authoritative for the message.
// Shape and conventions are adapted from `order-notify`, but intentionally
// isolated: order-notify is left untouched.

import { createClient } from "https://esm.sh/@supabase/supabase-js@2";

const CORS_HEADERS = {
  "Access-Control-Allow-Origin": "*",
  "Access-Control-Allow-Headers":
    "authorization, x-client-info, apikey, content-type",
};

// ---------------------------------------------------------------------------
// Types
// ---------------------------------------------------------------------------

interface ConsultationRequest {
  id: string;
  customer_name: string;
  phone: string;
  status: string;
  source: string;
  created_at: string;
}

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

  let consultationId: string;
  try {
    const body = await req.json();
    consultationId = body?.consultation_id;
    if (!consultationId) {
      throw new Error("consultation_id is required");
    }
  } catch (e) {
    return json({ error: (e as Error).message }, 400);
  }

  const client = createClient(supabaseUrl, serviceKey, {
    auth: { persistSession: false },
  });

  try {
    const { data: row, error: selErr } = await client
      .from("consultation_requests")
      .select("id, customer_name, phone, status, source, created_at")
      .eq("id", consultationId)
      .single();

    if (selErr || !row) {
      return json(
        { error: `Consultation not found: ${consultationId}` },
        404,
      );
    }

    const message = buildMessage(row as ConsultationRequest);

    const sent = await sendTelegram(botToken, chatId, message);
    if (!sent.ok) {
      console.error("Telegram API error:", JSON.stringify(sent));
      return json({ error: "Telegram send failed", details: sent }, 502);
    }

    return json({ success: true, consultation_id: consultationId });
  } catch (e) {
    console.error("consultation-notify error:", e);
    return json({ error: (e as Error).message }, 500);
  }
});

// ---------------------------------------------------------------------------
// Message builder
// ---------------------------------------------------------------------------

function buildMessage(row: ConsultationRequest): string {
  const shortId = row.id.slice(0, 8).toUpperCase();
  const stamp = formatCreatedAt(row.created_at);
  const sourceLabel = humanizeSource(row.source);

  const L: string[] = [];

  // Header: one tasteful marker, then a thin meta line with id + time.
  L.push(`✦ <b>Новая заявка на консультацию</b>`);
  L.push(`<code>#${esc(shortId)}</code> · ${esc(stamp)}`);
  L.push("");

  // Client block: explicit field labels make the message scannable at a
  // glance — the manager should be able to copy phone / name without
  // parsing positional lines.
  L.push("<b>Клиент</b>");
  L.push(`Имя: ${esc(row.customer_name)}`);
  L.push(`Телефон: ${esc(row.phone)}`);
  L.push("");

  // Source as plain humanized text. Status is intentionally omitted from
  // the notification: it is always "new" at notify-time and adds noise.
  L.push(`Источник: ${esc(sourceLabel)}`);

  return L.join("\n");
}

// ---------------------------------------------------------------------------
// Humanizers (deterministic, no I/O)
// ---------------------------------------------------------------------------

const SOURCE_LABELS: Record<string, string> = {
  mobile_app: "мобильное приложение",
  web: "сайт",
  sql_editor: "админ-панель",
};

function humanizeSource(raw: string): string {
  return SOURCE_LABELS[raw] ?? raw;
}

// ---------------------------------------------------------------------------
// Helpers
// ---------------------------------------------------------------------------

function formatCreatedAt(raw: string): string {
  // Deterministic, locale-free, timezone-stable rendering. We intentionally
  // do not depend on Intl / locale data (Edge Functions runtime can vary)
  // and we keep the output in UTC to avoid a broader timezone refactor.
  try {
    const d = new Date(raw);
    if (Number.isNaN(d.getTime())) return raw;

    const dd = String(d.getUTCDate()).padStart(2, "0");
    const mm = String(d.getUTCMonth() + 1).padStart(2, "0");
    const yyyy = String(d.getUTCFullYear());
    const hh = String(d.getUTCHours()).padStart(2, "0");
    const mi = String(d.getUTCMinutes()).padStart(2, "0");

    return `${dd}.${mm}.${yyyy}, ${hh}:${mi} UTC`;
  } catch {
    return raw;
  }
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
