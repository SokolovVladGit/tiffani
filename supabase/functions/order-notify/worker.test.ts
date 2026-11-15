import { assert, assertEquals } from "jsr:@std/assert@1";
import { buildMessage, type OrderItem, type OrderRequest } from "./render.ts";
import {
  MAX_NOTIFY_ATTEMPTS,
  bearerMatches,
  classifyTelegramHttp,
  dispatchLimit,
  failureIsTerminal,
  orderMissingFailure,
  transportFailure,
} from "./worker.ts";

const SECRET = "0123456789abcdef0123456789abcdef";

function order(overrides: Partial<OrderRequest> = {}): OrderRequest {
  return {
    id: "abcdef01-2345-6789-abcd-ef0123456789",
    customer_name: "Анна",
    phone: "+373 00",
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
    total_quantity: 2,
    total_price: 90,
    status: "new",
    source: "mobile_app",
    created_at: "2026-11-15T12:00:00Z",
    subtotal_amount: 100,
    discount_amount: 10,
    grand_total_amount: 90,
    applied_promocode_code: "SALE",
    applied_discount_snapshot: null,
    pricing_version: "v1",
    pricing_metadata: null,
    ...overrides,
  };
}

function item(): OrderItem {
  return {
    variant_id: "v1",
    title: "Крем",
    brand: "T",
    price: 50,
    quantity: 2,
    line_total: 100,
    edition: null,
    modification: null,
    unit_price_amount: 50,
    line_subtotal_amount: 100,
    line_discount_amount: 10,
    line_total_amount: 90,
    applied_discount_snapshot: null,
  };
}

Deno.test("worker rejects a missing, short, or wrong secret", () => {
  assertEquals(bearerMatches(null, SECRET), false);
  assertEquals(bearerMatches(`Bearer ${SECRET}`, undefined), false);
  assertEquals(bearerMatches(`Bearer ${SECRET}`, "short-secret"), false);
  assertEquals(bearerMatches("Bearer wrong-secret-wrong-secret-wrong", SECRET), false);
  assertEquals(bearerMatches(SECRET, SECRET), false);
});

Deno.test("worker accepts only the bearer secret", () => {
  assertEquals(bearerMatches(`Bearer ${SECRET}`, SECRET), true);
});

Deno.test("a client order id does not select a job", () => {
  const limit = dispatchLimit({
    order_id: "abcdef01-2345-6789-abcd-ef0123456789",
    limit: 3,
  });
  assertEquals(limit, 3);
  assertEquals(dispatchLimit({ order_id: "anything" }), 5);
  assertEquals(dispatchLimit({ limit: 99 }), 10);
  assertEquals(dispatchLimit(null), 5);
});

Deno.test("telegram failures are classified and retries are bounded", () => {
  assertEquals(classifyTelegramHttp(429).retryable, true);
  assertEquals(classifyTelegramHttp(500).retryable, true);
  assertEquals(classifyTelegramHttp(0).retryable, true);
  assertEquals(classifyTelegramHttp(400).retryable, false);
  assertEquals(classifyTelegramHttp(401).retryable, false);
  assertEquals(transportFailure().retryable, true);
  assertEquals(orderMissingFailure().retryable, false);

  assertEquals(failureIsTerminal(MAX_NOTIFY_ATTEMPTS, transportFailure()), true);
  assertEquals(failureIsTerminal(MAX_NOTIFY_ATTEMPTS - 1, transportFailure()), false);
  assertEquals(failureIsTerminal(1, orderMissingFailure()), true);
  assert(MAX_NOTIFY_ATTEMPTS === 5);
});

Deno.test("guest and authenticated snapshots render the same order fields", () => {
  const lines = item();
  const guest = buildMessage(order(), [lines]);
  const signedIn = buildMessage(order({ email: "a@b.co" }), [lines]);

  for (const message of [guest, signedIn]) {
    assert(message.includes("ABCDEF01"));
    assert(message.includes("Анна"));
    assert(message.includes("+373 00"));
    assert(message.includes("Крем"));
    assert(message.includes("×2"));
    assert(message.includes("90 ₽"));
  }
  assert(!guest.includes("Email:"));
  assert(signedIn.includes("Email: a@b.co"));
});

Deno.test("customer text is escaped before it reaches Telegram", () => {
  const message = buildMessage(
    order({
      customer_name: "<b>Анна</b>",
      phone: "1<2",
      delivery_address: "ул. A & B",
      fulfillment_type: "delivery",
      fulfillment_method_code: "courier_tiraspol",
      pickup_store_id: null,
    }),
    [{ ...item(), title: "<script>" }],
  );
  assert(message.includes("&lt;b&gt;Анна&lt;/b&gt;"));
  assert(message.includes("1&lt;2"));
  assert(message.includes("A &amp; B"));
  assert(message.includes("&lt;script&gt;"));
  assert(!message.includes("<script>"));
});
