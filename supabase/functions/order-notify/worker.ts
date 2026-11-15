// Pure decisions for the order-notify worker. No Deno.serve, no network.

export const MAX_NOTIFY_ATTEMPTS = 5;
export const WORKER_SECRET_NAME = "ORDER_NOTIFY_WORKER_SECRET";

export function bearerMatches(header: string | null, secret: string | undefined): boolean {
  if (!secret || secret.length < 32) return false;
  const expected = `Bearer ${secret}`;
  const presented = header ?? "";
  const length = Math.max(presented.length, expected.length);
  let diff = presented.length === expected.length ? 0 : 1;
  for (let i = 0; i < length; i++) {
    diff |= presented.charCodeAt(i) ^ expected.charCodeAt(i);
  }
  return diff === 0;
}

/** The request body never selects an order. A supplied order_id is ignored. */
export function dispatchLimit(body: unknown): number {
  if (body === null || typeof body !== "object" || Array.isArray(body)) return 5;
  const raw = (body as { limit?: unknown }).limit;
  const parsed = typeof raw === "number" ? raw : Number.NaN;
  if (!Number.isFinite(parsed)) return 5;
  return Math.min(10, Math.max(1, Math.floor(parsed)));
}

export type DeliveryFailure = {
  retryable: boolean;
  code: string;
};

export function classifyTelegramHttp(status: number): DeliveryFailure {
  if (status === 429 || status >= 500 || status === 0) {
    return { retryable: true, code: `telegram_http_${status}` };
  }
  return { retryable: false, code: `telegram_http_${status}` };
}

export function transportFailure(): DeliveryFailure {
  return { retryable: true, code: "telegram_transport" };
}

export function orderMissingFailure(): DeliveryFailure {
  return { retryable: false, code: "order_missing" };
}

export function failureIsTerminal(attempts: number, failure: DeliveryFailure): boolean {
  if (!failure.retryable) return true;
  return attempts >= MAX_NOTIFY_ATTEMPTS;
}
