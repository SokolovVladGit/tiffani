import { createClient } from "https://esm.sh/@supabase/supabase-js@2";
import { parseTildaYml } from "../catalog-sync/yml-parser.ts";
import { upsertCatalogSlice } from "../catalog-sync/sync-engine.ts";
import type { TildaCatalog } from "../catalog-sync/types.ts";

import { loadSafeSyncConfig } from "./config.ts";
import {
  computeMissingCandidates,
  type MissingCandidatesResult,
} from "./missing-candidates.ts";
import {
  createSafeSyncRun,
  finalizeSafeSyncRun,
  persistSafeSyncErrors,
  type SafeSyncRunStatus,
} from "./run-logger.ts";

/**
 * catalog-yml-sync-safe — v1 safe automatic Tilda YML sync.
 *
 * Contract:
 *   POST /functions/v1/catalog-yml-sync-safe
 *   body:
 *     { "dry_run": true,  "source": "manual" }   // default; no writes
 *     { "dry_run": false, "source": "cron"   }   // live; upsert-only
 *
 * Safety guarantees (enforced structurally in tests):
 *   - Never imports `syncCatalog`.
 *   - Never references `deactivateMissingProducts`.
 *   - Never writes `is_active: false`.
 *   - Never deletes/updates products outside the
 *     `upsertCatalogSlice` upsert path (which itself is structurally
 *     guarded against deactivation).
 *   - Admin-curated products with `tilda_uid IS NULL` are unreachable
 *     by `ON CONFLICT (tilda_uid)` and therefore untouched.
 *   - Missing-candidates path is read-only by construction.
 *
 * Observability:
 *   - Every invocation creates one `catalog_sync_runs` row with
 *     `source_type = 'yml_safe_sync'`.
 *   - Per-row errors land in `catalog_sync_run_errors`.
 *   - Run metadata pins `no_deactivation: true` for monitoring.
 */

const CORS_HEADERS = {
  "Access-Control-Allow-Origin": "*",
  "Access-Control-Allow-Headers":
    "authorization, x-client-info, apikey, content-type",
  "Access-Control-Allow-Methods": "POST, OPTIONS",
};

interface RequestBody {
  dry_run?: unknown;
  source?: unknown;
}

Deno.serve(async (req) => {
  const startedAt = Date.now();

  if (req.method === "OPTIONS") {
    return new Response("ok", { status: 200, headers: CORS_HEADERS });
  }
  if (req.method !== "POST") {
    return jsonResponse({ error: "method not allowed" }, 405);
  }

  let body: RequestBody = {};
  try {
    const text = await req.text();
    if (text.trim().length > 0) {
      body = JSON.parse(text) as RequestBody;
      if (typeof body !== "object" || body === null) body = {};
    }
  } catch (e) {
    return jsonResponse(
      {
        error: "invalid JSON body",
        details: e instanceof Error ? e.message : String(e),
      },
      400,
    );
  }

  // Strict opt-in for live mode: any value other than the literal
  // boolean `false` keeps us in dry-run. Defaults to dry-run.
  const dryRun = body.dry_run !== false;
  const source = typeof body.source === "string" && body.source.length > 0
    ? body.source
    : "manual";

  let config;
  try {
    config = loadSafeSyncConfig();
  } catch (e) {
    return jsonResponse(
      { error: e instanceof Error ? e.message : String(e) },
      500,
    );
  }

  const supabaseUrl = Deno.env.get("SUPABASE_URL");
  const supabaseKey = Deno.env.get("SUPABASE_SERVICE_ROLE_KEY");
  if (!supabaseUrl || !supabaseKey) {
    return jsonResponse(
      { error: "Missing SUPABASE_URL / SUPABASE_SERVICE_ROLE_KEY env vars" },
      500,
    );
  }

  const client = createClient(supabaseUrl, supabaseKey, {
    auth: { persistSession: false },
  });

  const initialStatus: SafeSyncRunStatus = dryRun ? "dry_run" : "running";
  const runId = await createSafeSyncRun(client, initialStatus, {
    source,
    dry_run: dryRun,
    no_deactivation: true,
  });

  let catalog: TildaCatalog;
  let ymlSizeBytes = 0;
  try {
    const ymlResp = await fetch(config.tildaYmlUrl, {
      headers: { "User-Agent": config.userAgent },
      signal: AbortSignal.timeout(config.requestTimeoutMs),
    });
    if (!ymlResp.ok) {
      throw new Error(`YML fetch failed: HTTP ${ymlResp.status}`);
    }
    const ymlText = await ymlResp.text();
    ymlSizeBytes = ymlText.length;
    catalog = parseTildaYml(ymlText);
  } catch (e) {
    const message = e instanceof Error ? e.message : String(e);
    await persistSafeSyncErrors(client, runId, [
      { stage: "fetch_or_parse_yml", external_key: "", message },
    ]);
    await finalizeSafeSyncRun(client, runId, {
      status: "failed",
      error_count: 1,
      metadata: {
        source,
        dry_run: dryRun,
        no_deactivation: true,
        duration_ms: Date.now() - startedAt,
        fatal_error: message,
      },
    });
    return jsonResponse(
      {
        run_id: runId,
        mode: dryRun ? "dry_run" : "live",
        status: "failed",
        error: message,
      },
      502,
    );
  }

  const ymlMetrics = computeYmlMetrics(catalog, ymlSizeBytes);

  // Missing-candidates is read-only and runs in both modes (when
  // enabled). Failure is non-fatal — we log and proceed.
  let missing: MissingCandidatesResult | null = null;
  let missingError: string | null = null;
  if (config.reportMissing) {
    try {
      missing = await computeMissingCandidates(
        client,
        catalog,
        config.missingSampleLimit,
      );
    } catch (e) {
      missingError = e instanceof Error ? e.message : String(e);
      await persistSafeSyncErrors(client, runId, [
        {
          stage: "missing_candidates",
          external_key: "",
          message: missingError,
        },
      ]);
    }
  }

  if (dryRun) {
    await finalizeSafeSyncRun(client, runId, {
      status: "dry_run_completed",
      products_seen: ymlMetrics.groups_count,
      variants_seen: ymlMetrics.offers_count,
      images_seen: ymlMetrics.images_in_yml,
      error_count: missingError ? 1 : 0,
      metadata: {
        source,
        dry_run: true,
        no_deactivation: true,
        duration_ms: Date.now() - startedAt,
        yml: ymlMetrics,
        missing_candidates: missing,
        missing_candidates_error: missingError,
      },
    });

    return jsonResponse({
      mode: "dry_run",
      run_id: runId,
      status: "dry_run_completed",
      duration_ms: Date.now() - startedAt,
      yml: ymlMetrics,
      products_seen: ymlMetrics.groups_count,
      products_upserted: 0,
      variants_seen: ymlMetrics.offers_count,
      variants_upserted: 0,
      images_seen: ymlMetrics.images_in_yml,
      images_upserted: 0,
      error_count: missingError ? 1 : 0,
      error_sample: missingError
        ? [{ stage: "missing_candidates", msg: missingError }]
        : [],
      missing_candidates: missing,
      verdict: missingError ? "missing_candidates_failed" : "safe_to_proceed_to_live",
    });
  }

  // -------------------- LIVE UPSERT --------------------

  try {
    const { stats, errors } = await upsertCatalogSlice(
      client,
      catalog,
      runId ?? crypto.randomUUID(),
    );

    const finalStatus: SafeSyncRunStatus = errors.length > 0 || missingError
      ? "completed_with_errors"
      : "completed";

    const persistableErrors = errors.map((e) => ({
      stage: `safe_sync.${e.stage}`,
      external_key: e.external_key,
      message: e.message,
      details: e.details,
    }));
    await persistSafeSyncErrors(client, runId, persistableErrors);

    await finalizeSafeSyncRun(client, runId, {
      status: finalStatus,
      products_seen: stats.products_seen,
      variants_seen: stats.variants_seen,
      images_seen: stats.images_seen,
      products_upserted: stats.products_upserted,
      variants_upserted: stats.variants_upserted,
      images_upserted: stats.images_upserted,
      error_count: errors.length + (missingError ? 1 : 0),
      metadata: {
        source,
        dry_run: false,
        no_deactivation: true,
        duration_ms: Date.now() - startedAt,
        yml: ymlMetrics,
        missing_candidates: missing,
        missing_candidates_error: missingError,
      },
    });

    return jsonResponse({
      mode: "live",
      run_id: runId,
      status: finalStatus,
      duration_ms: Date.now() - startedAt,
      yml: ymlMetrics,
      products_seen: stats.products_seen,
      products_upserted: stats.products_upserted,
      variants_seen: stats.variants_seen,
      variants_upserted: stats.variants_upserted,
      images_seen: stats.images_seen,
      images_upserted: stats.images_upserted,
      error_count: errors.length + (missingError ? 1 : 0),
      error_sample: errors.slice(0, 5).map((e) => ({
        stage: `safe_sync.${e.stage}`,
        key: e.external_key,
        msg: e.message,
      })),
      missing_candidates: missing,
    });
  } catch (e) {
    const message = e instanceof Error ? e.message : String(e);
    await persistSafeSyncErrors(client, runId, [
      { stage: "safe_sync.fatal", external_key: "", message },
    ]);
    await finalizeSafeSyncRun(client, runId, {
      status: "failed",
      error_count: 1,
      metadata: {
        source,
        dry_run: false,
        no_deactivation: true,
        duration_ms: Date.now() - startedAt,
        yml: ymlMetrics,
        missing_candidates: missing,
        missing_candidates_error: missingError,
        fatal_error: message,
      },
    });

    return jsonResponse(
      {
        run_id: runId,
        mode: "live",
        status: "failed",
        error: message,
        yml: ymlMetrics,
      },
      500,
    );
  }
});

interface YmlMetrics {
  size_bytes: number;
  categories_count: number;
  groups_count: number;
  offers_count: number;
  offers_with_picture: number;
  images_in_yml: number;
}

/**
 * Computes summary metrics over a parsed YML catalog. The metrics
 * are deterministic and side-effect free; they are returned in the
 * response and persisted in the run metadata.
 */
function computeYmlMetrics(
  catalog: TildaCatalog,
  sizeBytes: number,
): YmlMetrics {
  const groups = new Set<string>();
  let offersWithPicture = 0;
  let imagesInYml = 0;

  for (const offer of catalog.offers) {
    groups.add(offer.groupId ?? offer.id);
    const pics = offer.pictures && offer.pictures.length > 0
      ? offer.pictures
      : (offer.picture ? [offer.picture] : []);
    if (pics.length > 0) offersWithPicture++;
    imagesInYml += pics.length;
  }

  return {
    size_bytes: sizeBytes,
    categories_count: catalog.categories.length,
    groups_count: groups.size,
    offers_count: catalog.offers.length,
    offers_with_picture: offersWithPicture,
    images_in_yml: imagesInYml,
  };
}

function jsonResponse(body: unknown, status = 200): Response {
  return new Response(JSON.stringify(body), {
    status,
    headers: {
      "Content-Type": "application/json; charset=utf-8",
      ...CORS_HEADERS,
    },
  });
}
