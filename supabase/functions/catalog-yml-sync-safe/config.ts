/**
 * Configuration loader for the safe YML sync function.
 *
 * v1 invariants this config enforces or supports:
 *   - The function MUST never deactivate products. There is no flag
 *     in this config that toggles deactivation; deactivation is
 *     architecturally absent from the call path.
 *   - Dry-run is the default at the request layer (see index.ts);
 *     this config does not provide a way to invert that default.
 */

export interface SafeSyncConfig {
  /** Full URL of the Tilda YML catalog export. Required. */
  tildaYmlUrl: string;
  /** HTTP timeout for the YML fetch, in milliseconds. */
  requestTimeoutMs: number;
  /** User-Agent header used for the YML fetch. */
  userAgent: string;
  /**
   * Whether the dry-run path should compute and return the
   * `missing_candidates` summary. Default: enabled.
   */
  reportMissing: boolean;
  /**
   * Maximum number of UID samples returned in
   * `missing_candidates.sample`. Capped to keep responses small.
   */
  missingSampleLimit: number;
}

/**
 * Reads safe-sync configuration from environment variables.
 *
 * Required:
 *   TILDA_YML_URL                  — full URL to the Tilda YML feed.
 *
 * Optional:
 *   SYNC_REQUEST_TIMEOUT_MS        — HTTP timeout (default: 30000).
 *   SYNC_USER_AGENT                — UA header (default: TiffaniCatalogYmlSyncSafe/1.0).
 *   SAFE_SYNC_REPORT_MISSING       — "false"/"0" disables missing-candidates report.
 *   SAFE_SYNC_MISSING_SAMPLE_LIMIT — sample size cap (default: 20, max: 100).
 *
 * Throws when required configuration is absent so the caller can
 * fail-fast with a 500 response before any state changes.
 */
export function loadSafeSyncConfig(): SafeSyncConfig {
  const tildaYmlUrl = Deno.env.get("TILDA_YML_URL");
  if (!tildaYmlUrl) {
    throw new Error("TILDA_YML_URL environment variable is required");
  }

  const reportRaw = Deno.env.get("SAFE_SYNC_REPORT_MISSING");
  const reportMissing = !(reportRaw === "false" || reportRaw === "0");

  return {
    tildaYmlUrl,
    requestTimeoutMs: safeInt(Deno.env.get("SYNC_REQUEST_TIMEOUT_MS"), 30_000),
    userAgent:
      Deno.env.get("SYNC_USER_AGENT") ?? "TiffaniCatalogYmlSyncSafe/1.0",
    reportMissing,
    missingSampleLimit: clamp(
      safeInt(Deno.env.get("SAFE_SYNC_MISSING_SAMPLE_LIMIT"), 20),
      1,
      100,
    ),
  };
}

function safeInt(raw: string | undefined, fallback: number): number {
  if (!raw) return fallback;
  const n = parseInt(raw, 10);
  return Number.isFinite(n) && n > 0 ? n : fallback;
}

function clamp(n: number, min: number, max: number): number {
  if (n < min) return min;
  if (n > max) return max;
  return n;
}
