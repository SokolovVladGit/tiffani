export interface SyncConfig {
  tildaYmlUrl: string;
  requestTimeoutMs: number;
  userAgent: string;
  galleryEnabled: boolean;
  galleryBatchSize: number;
  galleryConcurrency: number;
}

/**
 * Reads sync configuration from environment variables.
 *
 * Required:
 *   TILDA_YML_URL — full URL to the Tilda YML export
 *
 * Optional:
 *   SYNC_REQUEST_TIMEOUT_MS    — HTTP timeout per request (default: 30000)
 *   SYNC_USER_AGENT            — User-Agent header (default: TiffaniCatalogSync/1.0)
 *   ENABLE_GALLERY_ENRICHMENT  — set to "true" to enable gallery scraping (default: disabled)
 *   SYNC_GALLERY_BATCH_SIZE    — max products to enrich per run (default: 20)
 *   SYNC_GALLERY_CONCURRENCY   — parallel gallery fetches (default: 3)
 */
export function loadConfig(): SyncConfig {
  const tildaYmlUrl = Deno.env.get("TILDA_YML_URL");
  if (!tildaYmlUrl) {
    throw new Error("TILDA_YML_URL environment variable is required");
  }

  const galleryRaw = Deno.env.get("ENABLE_GALLERY_ENRICHMENT");
  const galleryEnabled = galleryRaw === "true" || galleryRaw === "1";

  return {
    tildaYmlUrl,
    requestTimeoutMs: safeInt(Deno.env.get("SYNC_REQUEST_TIMEOUT_MS"), 30_000),
    userAgent: Deno.env.get("SYNC_USER_AGENT") ?? "TiffaniCatalogSync/1.0",
    galleryEnabled,
    galleryBatchSize: safeInt(Deno.env.get("SYNC_GALLERY_BATCH_SIZE"), 20),
    galleryConcurrency: safeInt(Deno.env.get("SYNC_GALLERY_CONCURRENCY"), 3),
  };
}

function safeInt(raw: string | undefined, fallback: number): number {
  if (!raw) return fallback;
  const n = parseInt(raw, 10);
  return Number.isFinite(n) && n > 0 ? n : fallback;
}
