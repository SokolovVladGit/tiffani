import type { RefillConfig } from "./config.ts";
import { parseVarProduct, type VarProductMinimal } from "./parse-var-product.ts";

export type ProbeStatus = "ok" | "not_found" | "fetch_error" | "parse_error";

export interface ProbeResult {
  status: ProbeStatus;
  http_status?: number;
  message?: string;
  product?: VarProductMinimal;
}

export interface ProbeDeps {
  fetchImpl?: typeof fetch;
}

/**
 * Single GET probe against /tproduct/<uid>.
 *
 * Policy:
 *  - Only a classification probe. Never extract content beyond
 *    the minimal identity fields returned by parseVarProduct().
 *  - 404 → not_found (UID is gone on Tilda).
 *  - 200 + parseable var product → ok (UID exists; needs manual review).
 *  - 200 + unparseable body → parse_error.
 *  - Anything else → fetch_error.
 */
export async function probeTproduct(
  uid: string,
  config: RefillConfig,
  deps: ProbeDeps = {},
): Promise<ProbeResult> {
  const fetchImpl = deps.fetchImpl ?? fetch;
  const base = config.tproductBaseUrl.replace(/\/+$/, "");
  const url = `${base}/tproduct/${encodeURIComponent(uid)}`;

  const controller = new AbortController();
  const timer = setTimeout(() => controller.abort(), config.requestTimeoutMs);

  try {
    const res = await fetchImpl(url, {
      method: "GET",
      headers: {
        "User-Agent": config.userAgent,
        Accept: "text/html",
      },
      redirect: "follow",
      signal: controller.signal,
    });

    if (res.status === 404) {
      return { status: "not_found", http_status: 404 };
    }
    if (!res.ok) {
      return {
        status: "fetch_error",
        http_status: res.status,
        message: `HTTP ${res.status}`,
      };
    }

    const body = await res.text();
    const parsed = parseVarProduct(body);
    if (!parsed) {
      return {
        status: "parse_error",
        http_status: res.status,
        message: "var product not found or malformed",
      };
    }

    return { status: "ok", http_status: res.status, product: parsed };
  } catch (e) {
    const msg = e instanceof Error ? e.message : String(e);
    return { status: "fetch_error", message: msg };
  } finally {
    clearTimeout(timer);
  }
}
