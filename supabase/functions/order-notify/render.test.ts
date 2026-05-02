// ============================================================================
// Pure unit tests for order-notify rendering. Run with:
//
//   deno test --allow-none supabase/functions/order-notify/render.test.ts
//
// Or just:
//
//   deno test supabase/functions/order-notify/render.test.ts
//
// No Deno.serve, no Supabase, no network. Covers Phase 3 rendering rules.
// ============================================================================

import { assert, assertEquals, assertStringIncludes } from "jsr:@std/assert@1";
import {
  buildMessage,
  computeMoneyView,
  parseDiscountSnapshot,
  parsePromoMetadata,
  type OrderItem,
  type OrderRequest,
} from "./render.ts";

// ---------------------------------------------------------------------------
// Fixtures
// ---------------------------------------------------------------------------

function baseOrder(overrides: Partial<OrderRequest> = {}): OrderRequest {
  return {
    id: "abcdef0123456789-test",
    customer_name: "Тест Клиент",
    phone: "+10000000001",
    email: null,
    delivery_method: null,
    delivery_address: null,
    payment_method: null,
    fulfillment_type: "pickup",
    fulfillment_method_code: "pickup_store",
    fulfillment_fee: 0,
    pickup_store_id: "store_central",
    delivery_zone_code: null,
    payment_method_code: "cash",
    promo_code: null,
    loyalty_card: null,
    comment: null,
    total_items: 1,
    total_quantity: 1,
    total_price: 100,
    status: "new",
    source: "mobile_app",
    created_at: "2026-05-02T12:00:00Z",
    subtotal_amount: null,
    discount_amount: null,
    grand_total_amount: null,
    applied_promocode_code: null,
    applied_discount_snapshot: null,
    pricing_version: null,
    pricing_metadata: null,
    ...overrides,
  };
}

function baseItem(overrides: Partial<OrderItem> = {}): OrderItem {
  return {
    variant_id: "TST-V-A1",
    title: "Тестовый аромат",
    brand: "TST",
    price: 100,
    quantity: 1,
    line_total: 100,
    edition: null,
    modification: null,
    unit_price_amount: null,
    line_subtotal_amount: null,
    line_discount_amount: null,
    line_total_amount: null,
    applied_discount_snapshot: null,
    ...overrides,
  };
}

// ---------------------------------------------------------------------------
// computeMoneyView selection rules
// ---------------------------------------------------------------------------

Deno.test("computeMoneyView: legacy v2 falls back to total_price + fulfillment_fee", () => {
  const o = baseOrder({ total_price: 250, fulfillment_fee: 50 });
  const m = computeMoneyView(o);
  assertEquals(m.displaySubtotal, 250);
  assertEquals(m.displayDiscount, 0);
  assertEquals(m.displayDeliveryFee, 50);
  assertEquals(m.displayGrandTotal, 300);
  assertEquals(m.isDiscountAware, false);
});

Deno.test("computeMoneyView: v3 prefers persisted snapshot fields", () => {
  const o = baseOrder({
    total_price: 250,
    fulfillment_fee: 50,
    subtotal_amount: 250,
    discount_amount: 25,
    grand_total_amount: 275,
  });
  const m = computeMoneyView(o);
  assertEquals(m.displaySubtotal, 250);
  assertEquals(m.displayDiscount, 25);
  assertEquals(m.displayDeliveryFee, 50);
  assertEquals(m.displayGrandTotal, 275);
  assertEquals(m.isDiscountAware, true);
});

Deno.test("computeMoneyView: v3 with snapshot but missing grand_total derives correctly", () => {
  const o = baseOrder({
    total_price: 250,
    fulfillment_fee: 10,
    subtotal_amount: 250,
    discount_amount: 25,
    grand_total_amount: null,
  });
  const m = computeMoneyView(o);
  assertEquals(m.displayGrandTotal, 235);
});

Deno.test("computeMoneyView: handles all-null safely", () => {
  const o = baseOrder({
    total_price: 0,
    fulfillment_fee: null,
    subtotal_amount: null,
    discount_amount: null,
    grand_total_amount: null,
  });
  const m = computeMoneyView(o);
  assertEquals(m.displaySubtotal, 0);
  assertEquals(m.displayDeliveryFee, 0);
  assertEquals(m.displayGrandTotal, 0);
  assertEquals(m.isDiscountAware, false);
});

// ---------------------------------------------------------------------------
// parseDiscountSnapshot defensive parsing
// ---------------------------------------------------------------------------

Deno.test("parseDiscountSnapshot: parses well-formed entries", () => {
  const raw = [
    {
      kind: "promocode",
      name: "TEST10",
      code: "TEST10",
      percent_off: 10,
      discount_amount: 10,
      campaign_id: "11111111-1111-1111-1111-111111111111",
    },
  ];
  const out = parseDiscountSnapshot(raw);
  assertEquals(out.length, 1);
  assertEquals(out[0].kind, "promocode");
  assertEquals(out[0].code, "TEST10");
  assertEquals(out[0].percentOff, 10);
});

Deno.test("parseDiscountSnapshot: tolerates malformed input without throwing", () => {
  // Mix of valid, garbage primitives, missing fields — must not throw.
  const raw = [
    { kind: "promocode" },
    null,
    "string",
    42,
    [],
    { kind: "automatic", percent_off: "20", discount_amount: "5", name: "Auto" },
    { kind: "weird-kind" },
  ];
  const out = parseDiscountSnapshot(raw);
  // Only object-shaped entries survive (4 of them).
  assertEquals(out.length, 4);
  // Numeric coercion from strings works.
  const auto = out.find((e) => e.name === "Auto");
  assert(auto, "auto entry expected");
  assertEquals(auto.percentOff, 20);
  assertEquals(auto.discountAmount, 5);
  // Unknown kind is bucketed as 'unknown'. The bare `{kind:"promocode"}` entry
  // (also all-null on the other fields) is correctly classified as 'promocode',
  // so search for the entry whose original kind string was unrecognized.
  // The bare `[]` (object-typed, kind missing) and `{ kind: "weird-kind" }`
  // both become 'unknown'. Both render to nothing in the identity block
  // because all human-facing fields are null.
  const unknownCount = out.filter((e) => e.kind === "unknown").length;
  assertEquals(unknownCount, 2, "two entries should be classified as 'unknown'");
});

Deno.test("parseDiscountSnapshot: non-array input returns empty array", () => {
  assertEquals(parseDiscountSnapshot(null), []);
  assertEquals(parseDiscountSnapshot(undefined), []);
  assertEquals(parseDiscountSnapshot({} as unknown), []);
  assertEquals(parseDiscountSnapshot("[]" as unknown), []);
});

// ---------------------------------------------------------------------------
// parsePromoMetadata
// ---------------------------------------------------------------------------

Deno.test("parsePromoMetadata: extracts promo subobject", () => {
  const md = { promo: { status: "applied", code: "TEST10", message: "OK" } };
  const p = parsePromoMetadata(md);
  assert(p, "promo expected");
  assertEquals(p.status, "applied");
  assertEquals(p.code, "TEST10");
});

Deno.test("parsePromoMetadata: returns null on unrelated input", () => {
  assertEquals(parsePromoMetadata(null), null);
  assertEquals(parsePromoMetadata({}), null);
  assertEquals(parsePromoMetadata({ promo: "string" }), null);
});

// ---------------------------------------------------------------------------
// buildMessage — fixture A: legacy v2 (no discount fields populated)
// ---------------------------------------------------------------------------

Deno.test("buildMessage A: legacy v2 keeps prior shape (no discount line)", () => {
  const order = baseOrder({
    total_price: 250,
    fulfillment_fee: 50,
    promo_code: "OLDPROMO",
  });
  const items = [baseItem({ price: 250, quantity: 1, line_total: 250 })];

  const msg = buildMessage(order, items);

  // Legacy plain money block (no 🎁 / 💰 lines).
  assertStringIncludes(msg, "Товары: 250 ₽");
  assertStringIncludes(msg, "Доставка: 50 ₽");
  assertStringIncludes(msg, "Итого к оплате: 300 ₽");

  // Legacy promo line preserved exactly.
  assertStringIncludes(msg, "🏷 Промокод: OLDPROMO");

  // Must NOT have any v3-only blocks.
  assert(!msg.includes("🎁 Скидка"), "legacy must not show discount line");
  assert(!msg.includes("Применённые скидки"), "legacy must not show identity block");
  assert(!msg.includes("💰"), "legacy must not show 💰 grand-total emoji");
});

// ---------------------------------------------------------------------------
// buildMessage — fixture B: v3 with promocode applied
// ---------------------------------------------------------------------------

Deno.test("buildMessage B: v3 promocode applied — money + identity blocks", () => {
  const order = baseOrder({
    total_price: 100,
    fulfillment_fee: 10,
    promo_code: "test10",
    subtotal_amount: 100,
    discount_amount: 10,
    grand_total_amount: 100,
    applied_promocode_code: "TEST10",
    applied_discount_snapshot: [
      {
        kind: "promocode",
        name: "TEST10",
        code: "TEST10",
        percent_off: 10,
        discount_amount: 10,
        campaign_id: "11111111-1111-1111-1111-111111111111",
      },
    ],
    pricing_version: "discount_v1",
    pricing_metadata: { promo: { status: "applied", code: "test10" } },
  });
  const items = [
    baseItem({
      price: 100,
      quantity: 1,
      line_total: 100,
      unit_price_amount: 100,
      line_subtotal_amount: 100,
      line_discount_amount: 10,
      line_total_amount: 90,
    }),
  ];

  const msg = buildMessage(order, items);

  assertStringIncludes(msg, "🎁 Применённые скидки");
  assertStringIncludes(msg, "🏷 Промокод применён: TEST10 (-10%)");
  assertStringIncludes(msg, "🧾 Товары: 100 ₽");
  assertStringIncludes(msg, "🎁 Скидка: -10 ₽");
  assertStringIncludes(msg, "🚚 Доставка: 10 ₽");
  assertStringIncludes(msg, "💰 <b>Итого к оплате: 100 ₽</b>");

  // Bottom 🏷 Промокод line is suppressed in discount-aware mode (avoid
  // duplication with the identity block above).
  assert(!msg.includes("🏷 Промокод: test10"));
});

// ---------------------------------------------------------------------------
// buildMessage — fixture C: v3 with promo provided but automatic won
// ---------------------------------------------------------------------------

Deno.test("buildMessage C: v3 not_best_discount — promo shown as 'не применён'", () => {
  const order = baseOrder({
    total_price: 100,
    fulfillment_fee: 0,
    promo_code: "GPROMO10",
    subtotal_amount: 100,
    discount_amount: 20,
    grand_total_amount: 80,
    applied_promocode_code: null,
    applied_discount_snapshot: [
      {
        kind: "automatic",
        name: "Brand A 20%",
        code: null,
        percent_off: 20,
        discount_amount: 20,
        campaign_id: "22222222-2222-2222-2222-222222222222",
      },
    ],
    pricing_version: "discount_v1",
    pricing_metadata: { promo: { status: "not_best_discount", code: "GPROMO10" } },
  });
  const items = [
    baseItem({
      price: 100,
      quantity: 1,
      line_total: 100,
      unit_price_amount: 100,
      line_subtotal_amount: 100,
      line_discount_amount: 20,
      line_total_amount: 80,
    }),
  ];

  const msg = buildMessage(order, items);

  assertStringIncludes(msg, "🎯 Brand A 20% (-20%)");
  assertStringIncludes(
    msg,
    "🏷 Промокод указан: GPROMO10 (не применён — автоматическая скидка выгоднее)",
  );
  assertStringIncludes(msg, "🎁 Скидка: -20 ₽");
  assertStringIncludes(msg, "💰 <b>Итого к оплате: 80 ₽</b>");
});

// ---------------------------------------------------------------------------
// buildMessage — fixture D: malformed snapshot doesn't crash and degrades
// gracefully (no identity block, money block still rendered correctly).
// ---------------------------------------------------------------------------

Deno.test("buildMessage D: malformed applied_discount_snapshot does not crash", () => {
  const order = baseOrder({
    total_price: 100,
    fulfillment_fee: 5,
    subtotal_amount: 100,
    discount_amount: 10,
    grand_total_amount: 95,
    applied_promocode_code: null,
    // Garbage shapes — none of these are valid campaign objects.
    applied_discount_snapshot: ["nope", 42, null, { foo: "bar" }],
    pricing_version: "discount_v1",
    pricing_metadata: "not-an-object" as unknown,
  });
  const items = [baseItem()];

  // Must not throw.
  const msg = buildMessage(order, items);

  // Money block still renders correctly from scalars.
  assertStringIncludes(msg, "🎁 Скидка: -10 ₽");
  assertStringIncludes(msg, "💰 <b>Итого к оплате: 95 ₽</b>");

  // No identity bullet survives (the only shaped entry has no name/code/percent).
  // It's acceptable for the header to render with a single "unknown" bullet
  // OR to be omitted entirely — assert only that no thrown/garbled emoji output.
  assert(!msg.includes("undefined"), "no 'undefined' substrings in output");
  assert(!msg.includes("null"), "no 'null' substrings in output");
});

// ---------------------------------------------------------------------------
// HTML safety — ensure user-supplied promo strings are escaped.
// ---------------------------------------------------------------------------

Deno.test("buildMessage: escapes HTML in promo and customer fields", () => {
  const order = baseOrder({
    customer_name: "<script>",
    promo_code: "A&B<C",
  });
  const items = [baseItem()];

  const msg = buildMessage(order, items);
  assertStringIncludes(msg, "&lt;script&gt;");
  assertStringIncludes(msg, "A&amp;B&lt;C");
});
