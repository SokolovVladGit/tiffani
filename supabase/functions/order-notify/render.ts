// ============================================================================
// order-notify rendering — pure module (no Deno / no Supabase imports).
//
// All formatting, totals selection, discount-snapshot parsing and HTML
// escaping live here so they can be unit-tested with `deno test` and reused
// without spinning up the Deno.serve handler.
//
// Phase 3 contract:
//   - Old v2 orders (no Phase 1 snapshot columns populated) keep the
//     existing message shape exactly.
//   - v3 / discount-aware orders (discount_amount > 0) get a clear money
//     block (subtotal / discount / delivery / grand total) and a
//     discount-identity block above totals.
//   - Telegram is never source of truth: this module ONLY renders persisted
//     order snapshot fields. No call into discount_campaigns / quote_order_v1.
// ============================================================================

// ---------------------------------------------------------------------------
// Types — superset of the v2 shape with additive Phase 1 columns.
// All Phase 1 columns are nullable for v2 backward compatibility.
// ---------------------------------------------------------------------------

export interface OrderRequest {
  id: string;
  customer_name: string;
  phone: string;
  email: string | null;

  delivery_method: string | null;
  delivery_address: string | null;
  payment_method: string | null;

  fulfillment_type: string | null;
  fulfillment_method_code: string | null;
  fulfillment_fee: number | null;
  pickup_store_id: string | null;
  delivery_zone_code: string | null;

  payment_method_code: string | null;

  promo_code: string | null;
  loyalty_card: string | null;
  comment: string | null;

  total_items: number;
  total_quantity: number;
  total_price: number;
  status: string;
  source: string;
  created_at: string;

  // Phase 1 additive snapshot columns (null for old v2 orders).
  subtotal_amount: number | null;
  discount_amount: number | null;
  grand_total_amount: number | null;
  applied_promocode_code: string | null;
  applied_discount_snapshot: unknown;
  pricing_version: string | null;
  pricing_metadata: unknown;
}

export interface OrderItem {
  variant_id: string;
  title: string | null;
  brand: string | null;
  price: number | null;
  quantity: number;
  line_total: number | null;
  edition: string | null;
  modification: string | null;

  // Phase 1 additive snapshot columns (null for old v2 orders).
  unit_price_amount: number | null;
  line_subtotal_amount: number | null;
  line_discount_amount: number | null;
  line_total_amount: number | null;
  applied_discount_snapshot: unknown;
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
// Pricing snapshot model.
//
// Selection rules (per Phase 3 spec):
//   displaySubtotal     = order.subtotal_amount    ?? order.total_price ?? 0
//   displayDiscount     = order.discount_amount    ?? 0
//   displayDeliveryFee  = order.fulfillment_fee    ?? 0
//   displayGrandTotal   = order.grand_total_amount
//                         ?? displaySubtotal - displayDiscount + displayDeliveryFee
//
// For old v2 orders this collapses to the prior behavior:
//   total_price + fulfillment_fee
// ---------------------------------------------------------------------------

export interface MoneyView {
  displaySubtotal: number;
  displayDiscount: number;
  displayDeliveryFee: number;
  displayGrandTotal: number;
  isDiscountAware: boolean;
}

export function computeMoneyView(order: OrderRequest): MoneyView {
  const displaySubtotal =
    order.subtotal_amount ?? order.total_price ?? 0;
  const displayDiscount = order.discount_amount ?? 0;
  const displayDeliveryFee = order.fulfillment_fee ?? 0;
  const displayGrandTotal =
    order.grand_total_amount ??
    displaySubtotal - displayDiscount + displayDeliveryFee;

  return {
    displaySubtotal,
    displayDiscount,
    displayDeliveryFee,
    displayGrandTotal,
    isDiscountAware: displayDiscount > 0,
  };
}

// ---------------------------------------------------------------------------
// applied_discount_snapshot parsing.
//
// Snapshot is a jsonb array of campaign objects produced by quote_order_v1
// and persisted by submit_order_v3. Each entry is best-effort:
//   { kind: 'automatic'|'promocode', name, code?, percent_off, discount_amount, campaign_id }
//
// This parser is defensive: anything that is not the expected shape is
// silently dropped. It never throws.
// ---------------------------------------------------------------------------

export interface AppliedDiscountEntry {
  kind: "automatic" | "promocode" | "unknown";
  name: string | null;
  code: string | null;
  percentOff: number | null;
  discountAmount: number | null;
  campaignId: string | null;
}

export function parseDiscountSnapshot(raw: unknown): AppliedDiscountEntry[] {
  if (!Array.isArray(raw)) return [];
  const out: AppliedDiscountEntry[] = [];
  for (const item of raw) {
    if (!item || typeof item !== "object") continue;
    const o = item as Record<string, unknown>;

    const kindRaw = typeof o.kind === "string" ? o.kind : "";
    const kind: AppliedDiscountEntry["kind"] =
      kindRaw === "automatic" || kindRaw === "promocode" ? kindRaw : "unknown";

    out.push({
      kind,
      name: typeof o.name === "string" ? o.name : null,
      code: typeof o.code === "string" ? o.code : null,
      percentOff: toNumberOrNull(o.percent_off),
      discountAmount: toNumberOrNull(o.discount_amount),
      campaignId: typeof o.campaign_id === "string" ? o.campaign_id : null,
    });
  }
  return out;
}

interface PromoMetadata {
  status: string | null;
  code: string | null;
  message: string | null;
}

export function parsePromoMetadata(raw: unknown): PromoMetadata | null {
  if (!raw || typeof raw !== "object") return null;
  const md = raw as Record<string, unknown>;
  const promo = md.promo;
  if (!promo || typeof promo !== "object") return null;
  const p = promo as Record<string, unknown>;
  return {
    status: typeof p.status === "string" ? p.status : null,
    code: typeof p.code === "string" ? p.code : null,
    message: typeof p.message === "string" ? p.message : null,
  };
}

// ---------------------------------------------------------------------------
// Discount identity block — composed of:
//   - one line per campaign that actually contributed (deduped),
//   - optional "promo provided but not applied" line when the user typed a
//     code that lost or did not apply (only emitted in discount-aware mode
//     to avoid noise on legacy orders).
// ---------------------------------------------------------------------------

export function renderDiscountIdentityLines(
  order: OrderRequest,
  snapshotEntries: AppliedDiscountEntry[],
  promoMeta: PromoMetadata | null,
): string[] {
  const lines: string[] = [];
  const seen = new Set<string>();
  const promocodes: AppliedDiscountEntry[] = [];
  const automatics: AppliedDiscountEntry[] = [];

  for (const e of snapshotEntries) {
    if (e.discountAmount != null && e.discountAmount <= 0) continue;
    const key = (e.campaignId ?? "") + "|" + (e.code ?? "") + "|" + (e.name ?? "");
    if (seen.has(key)) continue;
    seen.add(key);
    if (e.kind === "promocode") {
      promocodes.push(e);
    } else {
      automatics.push(e);
    }
  }

  if (promocodes.length === 0 && automatics.length === 0) return lines;

  lines.push("<b>🎁 Применённые скидки</b>");

  for (const p of promocodes) {
    const code = p.code ?? order.applied_promocode_code ?? "";
    const pct = p.percentOff != null ? ` (-${formatPercent(p.percentOff)}%)` : "";
    lines.push(`• 🏷 Промокод применён: ${esc(code)}${pct}`);
  }
  for (const a of automatics) {
    const label = a.name ?? a.code ?? "Автоматическая скидка";
    const pct = a.percentOff != null ? ` (-${formatPercent(a.percentOff)}%)` : "";
    lines.push(`• 🎯 ${esc(label)}${pct}`);
  }

  // Promo provided but did NOT win (only relevant when an actual discount
  // landed on the order — otherwise the legacy 🏷 Промокод line below the
  // totals still serves the operator).
  if (order.promo_code && !order.applied_promocode_code) {
    const status = promoMeta?.status ?? null;
    const note =
      status === "not_best_discount"
        ? "не применён — автоматическая скидка выгоднее"
        : status && status !== "applied" && status !== "not_provided"
          ? `не применён — ${humanizePromoStatus(status)}`
          : "не применён";
    lines.push(`🏷 Промокод указан: ${esc(order.promo_code)} (${note})`);
  }

  return lines;
}

function humanizePromoStatus(status: string): string {
  switch (status) {
    case "not_found": return "код не найден";
    case "inactive": return "код отключён";
    case "expired": return "срок действия истёк";
    case "limit_reached": return "лимит использований исчерпан";
    case "min_order_not_met": return "сумма заказа меньше минимальной";
    case "no_matching_items": return "нет подходящих товаров";
    default: return status;
  }
}

// ---------------------------------------------------------------------------
// Money block lines — discount-aware vs legacy.
// ---------------------------------------------------------------------------

function renderMoneyBlockLines(money: MoneyView): string[] {
  if (money.isDiscountAware) {
    return [
      `🧾 Товары: ${fmtPrice(money.displaySubtotal)}`,
      `🎁 Скидка: -${fmtPrice(money.displayDiscount)}`,
      `🚚 Доставка: ${fmtPrice(money.displayDeliveryFee)}`,
      `💰 <b>Итого к оплате: ${fmtPrice(money.displayGrandTotal)}</b>`,
    ];
  }
  return [
    `Товары: ${fmtPrice(money.displaySubtotal)}`,
    `Доставка: ${fmtPrice(money.displayDeliveryFee)}`,
    `<b>Итого к оплате: ${fmtPrice(money.displayGrandTotal)}</b>`,
  ];
}

// ---------------------------------------------------------------------------
// Top-level message builder. Old v2 path is byte-comparable to the prior
// implementation when discount_amount = 0 / not present.
// ---------------------------------------------------------------------------

export function buildMessage(order: OrderRequest, items: OrderItem[]): string {
  const shortId = order.id.slice(0, 8).toUpperCase();
  const L: string[] = [];

  L.push(`🛒 <b>Новый заказ #${esc(shortId)}</b>`);

  L.push("");
  L.push("<b>👤 Клиент</b>");
  L.push(`Имя: ${esc(order.customer_name)}`);
  L.push(`Телефон: ${esc(order.phone)}`);
  if (order.email) {
    L.push(`Email: ${esc(order.email)}`);
  }

  const isPickup = resolveIsPickup(order);
  const fulfillmentLabel = resolveFulfillmentLabel(order);

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

  const paymentLabel = resolvePaymentLabel(order);
  L.push("");
  L.push("<b>💳 Оплата</b>");
  L.push(`Способ: ${esc(paymentLabel)}`);

  if (items.length > 0) {
    L.push("");
    L.push("<b>📦 Состав заказа</b>");
    for (let i = 0; i < items.length; i++) {
      const it = items[i];
      const title = it.title ?? it.variant_id;
      const titleLower = title.toLowerCase();

      // v2 contract preserved: line_total is pre-discount line subtotal.
      // We display the same number here as before for shape stability.
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

  // ---- Totals + (when applicable) discount identity block --------------
  const money = computeMoneyView(order);

  L.push("");
  L.push("<b>📊 Итого</b>");
  L.push(`Позиций: ${order.total_items}`);
  L.push(`Количество товаров: ${order.total_quantity}`);

  if (money.isDiscountAware) {
    const snapshotEntries = parseDiscountSnapshot(order.applied_discount_snapshot);
    const promoMeta = parsePromoMetadata(order.pricing_metadata);
    const identityLines = renderDiscountIdentityLines(order, snapshotEntries, promoMeta);
    if (identityLines.length > 0) {
      for (const ln of identityLines) L.push(ln);
    }
  }

  for (const ln of renderMoneyBlockLines(money)) L.push(ln);

  // ---- Optional extras ------------------------------------------------
  // In discount-aware mode we already rendered promo identity above the
  // money block, so the bottom 🏷 Промокод line is suppressed to avoid
  // duplication. Loyalty card is independent and always shown if present.
  const extras: string[] = [];
  if (!money.isDiscountAware && order.promo_code) {
    extras.push(`🏷 Промокод: ${esc(order.promo_code)}`);
  }
  if (order.loyalty_card) {
    extras.push(`💳 Карта клиента: ${esc(order.loyalty_card)}`);
  }
  if (extras.length > 0) {
    L.push("");
    for (const ln of extras) L.push(ln);
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
// Generic helpers
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
  raw = raw.replace(/^Объ[её]м\s*:\s*/i, "").trim();
  raw = raw.replace(/(\d)\s*(мл|г|ml|шт)\b/gi, "$1 $2");
  return raw || null;
}

export function fmtPrice(value: number | null): string {
  if (value == null) return "0 ₽";
  if (value === Math.floor(value)) return `${value} ₽`;
  return `${value.toFixed(2)} ₽`;
}

export function esc(text: string): string {
  return text
    .replace(/&/g, "&amp;")
    .replace(/</g, "&lt;")
    .replace(/>/g, "&gt;");
}

function formatPercent(value: number): string {
  if (value === Math.floor(value)) return `${value}`;
  return value.toFixed(2).replace(/\.?0+$/, "");
}

function toNumberOrNull(v: unknown): number | null {
  if (typeof v === "number" && Number.isFinite(v)) return v;
  if (typeof v === "string") {
    const trimmed = v.trim();
    if (trimmed === "") return null;
    const n = Number(trimmed);
    return Number.isFinite(n) ? n : null;
  }
  return null;
}
