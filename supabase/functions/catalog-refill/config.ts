export interface RefillConfig {
  tildaYmlUrl: string;
  requestTimeoutMs: number;
  userAgent: string;
  probeConcurrency: number;
  tproductBaseUrl: string;
  sampleLimitPerBucket: number;
  maxUidsPerRequest: number;
}

/**
 * Reads refill dry-run configuration from environment variables.
 *
 * Required:
 *   TILDA_YML_URL — full URL to the Tilda YML catalog export.
 *
 * Optional:
 *   REFILL_TIMEOUT_MS            — HTTP timeout per request (default: 20000)
 *   REFILL_USER_AGENT            — UA header (default: TiffaniCatalogRefill/0.1)
 *   REFILL_PROBE_CONCURRENCY     — max concurrent /tproduct probes (default: 3)
 *   REFILL_TPRODUCT_BASE_URL     — probe origin (default: https://tiffani.md)
 *   REFILL_SAMPLE_LIMIT          — rows per bucket in response samples (default: 20)
 *   REFILL_MAX_UIDS              — max UIDs accepted per request (default: 2000)
 */
export function loadRefillConfig(): RefillConfig {
  const tildaYmlUrl = Deno.env.get("TILDA_YML_URL");
  if (!tildaYmlUrl) {
    throw new Error("TILDA_YML_URL environment variable is required");
  }

  return {
    tildaYmlUrl,
    requestTimeoutMs: safeInt(Deno.env.get("REFILL_TIMEOUT_MS"), 20_000),
    userAgent:
      Deno.env.get("REFILL_USER_AGENT") ?? "TiffaniCatalogRefill/0.1",
    probeConcurrency: safeInt(Deno.env.get("REFILL_PROBE_CONCURRENCY"), 3),
    tproductBaseUrl:
      Deno.env.get("REFILL_TPRODUCT_BASE_URL") ?? "https://tiffani.md",
    sampleLimitPerBucket: safeInt(Deno.env.get("REFILL_SAMPLE_LIMIT"), 20),
    maxUidsPerRequest: safeInt(Deno.env.get("REFILL_MAX_UIDS"), 2000),
  };
}

function safeInt(raw: string | undefined, fallback: number): number {
  if (!raw) return fallback;
  const n = parseInt(raw, 10);
  return Number.isFinite(n) && n > 0 ? n : fallback;
}
