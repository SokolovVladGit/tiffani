import { createClient } from "https://esm.sh/@supabase/supabase-js@2";
import { parseTildaYml } from "../catalog-sync/yml-parser.ts";
import { upsertCatalogSlice } from "../catalog-sync/sync-engine.ts";

import { loadRefillConfig } from "./config.ts";
import { buildYmlIndex } from "./yml-index.ts";
import { classifyUids, summarize } from "./classifier.ts";
import { buildUpsertSlice } from "./build-slice.ts";
import {
  createRefillRun,
  finalizeRefillRun,
  persistRefillErrors,
  type RunStatus,
} from "./run-logger.ts";
import type {
  BucketCounts,
  ClassificationSummary,
  UidBucket,
  UidClassification,
} from "./types.ts";

const CORS_HEADERS = {
  "Access-Control-Allow-Origin": "*",
  "Access-Control-Allow-Headers":
    "authorization, x-client-info, apikey, content-type",
  "Access-Control-Allow-Methods": "POST, OPTIONS",
};

/**
 * catalog-refill — targeted, idempotent refill of Tilda products.
 *
 * Contract:
 *   POST /functions/v1/catalog-refill
 *   body: { "uids": string[], "dry_run": boolean (default true) }
 *
 * Dry run (default):
 *   - Classifies UIDs against the YML feed + /tproduct probe.
 *   - Writes nothing to catalog tables.
 *   - Optionally records a row in `catalog_sync_runs` (best-effort).
 *
 * Live (`dry_run: false`):
 *   - Classifies UIDs.
 *   - Upserts ONLY `found_in_yml_offer` + `found_in_yml_group` buckets
 *     through `upsertCatalogSlice` (phases 1–3; never deactivates).
 *   - Admin products (tilda_uid IS NULL) are untouchable by
 *     ON CONFLICT (tilda_uid); this is enforced by DB schema.
 *   - `is_active` is only ever written as `true` by the sync engine.
 */
Deno.serve(async (req) => {
  if (req.method === "OPTIONS") {
    return new Response("ok", { status: 200, headers: CORS_HEADERS });
  }
  if (req.method !== "POST") {
    return jsonResponse({ error: "method not allowed" }, 405);
  }

  let body: unknown;
  try {
    body = await req.json();
  } catch {
    return jsonResponse({ error: "invalid JSON body" }, 400);
  }

  const record = (body ?? {}) as Record<string, unknown>;
  const dryRun = record.dry_run !== false;

  const rawUids = record.uids;
  if (!Array.isArray(rawUids) || rawUids.length === 0) {
    return jsonResponse(
      { error: "uids array is required and must be non-empty" },
      400,
    );
  }

  let config;
  try {
    config = loadRefillConfig();
  } catch (e) {
    return jsonResponse({ error: (e as Error).message }, 500);
  }

  if (rawUids.length > config.maxUidsPerRequest) {
    return jsonResponse(
      {
        error:
          `too many uids: received ${rawUids.length}, max ${config.maxUidsPerRequest}. Batch the request.`,
      },
      413,
    );
  }

  const uids = rawUids.map((u) => String(u ?? ""));

  const supabaseUrl = Deno.env.get("SUPABASE_URL");
  const supabaseKey = Deno.env.get("SUPABASE_SERVICE_ROLE_KEY");
  const supabase = supabaseUrl && supabaseKey
    ? createClient(supabaseUrl, supabaseKey, {
      auth: { persistSession: false },
    })
    : null;

  if (!dryRun && !supabase) {
    return jsonResponse(
      {
        error:
          "Missing SUPABASE_URL / SUPABASE_SERVICE_ROLE_KEY env vars; cannot perform live upsert.",
      },
      500,
    );
  }

  let ymlText: string;
  try {
    const ymlResp = await fetch(config.tildaYmlUrl, {
      headers: { "User-Agent": config.userAgent },
      signal: AbortSignal.timeout(config.requestTimeoutMs),
    });
    if (!ymlResp.ok) {
      return jsonResponse(
        { error: `YML fetch failed: HTTP ${ymlResp.status}` },
        502,
      );
    }
    ymlText = await ymlResp.text();
  } catch (e) {
    const msg = e instanceof Error ? e.message : String(e);
    return jsonResponse({ error: `YML fetch error: ${msg}` }, 502);
  }

  let index;
  try {
    const catalog = parseTildaYml(ymlText);
    index = { catalog, yml: buildYmlIndex(catalog) };
  } catch (e) {
    const msg = e instanceof Error ? e.message : String(e);
    return jsonResponse({ error: `YML parse error: ${msg}` }, 502);
  }

  const results = await classifyUids(uids, index.yml, config);
  const { counts, samples } = summarize(results, config.sampleLimitPerBucket);

  const runId = supabase
    ? await createRefillRun(supabase, dryRun ? "dry_run" : "running", {
      uid_list_size: uids.length,
      dry_run: dryRun,
      classifier_counts: counts,
      skipped_buckets: notUpsertBuckets(),
      tproduct_base_url: config.tproductBaseUrl,
    })
    : null;

  const classifierSummary: ClassificationSummary = {
    total: uids.length,
    counts,
    samples,
    yml_meta: {
      offers_count: index.yml.offersCount,
      groups_count: index.yml.groupsCount,
      categories_count: index.yml.categoriesCount,
    },
    dry_run: dryRun,
    generated_at: new Date().toISOString(),
  };

  if (dryRun) {
    if (supabase) {
      await finalizeRefillRun(supabase, runId, {
        status: "dry_run_completed",
        metadata: {
          uid_list_size: uids.length,
          dry_run: true,
          classifier_counts: counts,
          skipped_buckets: notUpsertBuckets(),
          upsert_eligible: counts.found_in_yml_offer + counts.found_in_yml_group,
        },
      });
    }
    return jsonResponse({
      mode: "dry_run",
      run_id: runId,
      classifier: classifierSummary,
    });
  }

  // -------------------- LIVE UPSERT --------------------

  if (!supabase) {
    return jsonResponse(
      { error: "supabase client unavailable; cannot perform live upsert" },
      500,
    );
  }

  const { slice, metrics: sliceMetrics } = buildUpsertSlice(
    results,
    index.yml,
    index.catalog,
  );

  if (slice.offers.length === 0) {
    await finalizeRefillRun(supabase, runId, {
      status: "completed",
      products_seen: 0,
      variants_seen: 0,
      images_seen: 0,
      products_upserted: 0,
      variants_upserted: 0,
      images_upserted: 0,
      error_count: 0,
      metadata: {
        uid_list_size: uids.length,
        dry_run: false,
        classifier_counts: counts,
        skipped_buckets: notUpsertBuckets(),
        slice_metrics: sliceMetrics,
        note: "no upsert-eligible offers after classification",
      },
    });
    return jsonResponse({
      mode: "live",
      run_id: runId,
      classifier: classifierSummary,
      slice_metrics: sliceMetrics,
      upsert: zeroUpsertResult(),
    });
  }

  try {
    const { stats, errors } = await upsertCatalogSlice(
      supabase,
      slice,
      runId ?? crypto.randomUUID(),
    );

    const finalStatus: RunStatus = errors.length > 0
      ? "completed_with_errors"
      : "completed";

    await persistRefillErrors(
      supabase,
      runId,
      errors.map((e) => ({
        stage: `refill.${e.stage}`,
        external_key: e.external_key,
        message: e.message,
        details: e.details,
      })),
    );

    await finalizeRefillRun(supabase, runId, {
      status: finalStatus,
      products_seen: stats.products_seen,
      variants_seen: stats.variants_seen,
      images_seen: stats.images_seen,
      products_upserted: stats.products_upserted,
      variants_upserted: stats.variants_upserted,
      images_upserted: stats.images_upserted,
      error_count: errors.length,
      metadata: {
        uid_list_size: uids.length,
        dry_run: false,
        classifier_counts: counts,
        skipped_buckets: notUpsertBuckets(),
        slice_metrics: sliceMetrics,
      },
    });

    return jsonResponse({
      mode: "live",
      run_id: runId,
      status: finalStatus,
      classifier: classifierSummary,
      slice_metrics: sliceMetrics,
      upsert: {
        products_seen: stats.products_seen,
        variants_seen: stats.variants_seen,
        images_seen: stats.images_seen,
        products_upserted: stats.products_upserted,
        variants_upserted: stats.variants_upserted,
        images_upserted: stats.images_upserted,
        error_count: errors.length,
        error_sample: errors.slice(0, 5).map((e) => ({
          stage: e.stage,
          key: e.external_key,
          msg: e.message,
        })),
      },
    });
  } catch (e) {
    const msg = e instanceof Error ? e.message : String(e);
    await persistRefillErrors(supabase, runId, [
      { stage: "refill.fatal", external_key: "", message: msg },
    ]);
    await finalizeRefillRun(supabase, runId, {
      status: "failed",
      error_count: 1,
      metadata: {
        uid_list_size: uids.length,
        dry_run: false,
        classifier_counts: counts,
        skipped_buckets: notUpsertBuckets(),
        slice_metrics: sliceMetrics,
        fatal_error: msg,
      },
    });
    return jsonResponse(
      { run_id: runId, mode: "live", status: "failed", error: msg },
      500,
    );
  }
});

function notUpsertBuckets(): UidBucket[] {
  return [
    "needs_manual_review",
    "tilda_gone",
    "probe_error",
    "invalid_uid",
  ];
}

function zeroUpsertResult() {
  return {
    products_seen: 0,
    variants_seen: 0,
    images_seen: 0,
    products_upserted: 0,
    variants_upserted: 0,
    images_upserted: 0,
    error_count: 0,
    error_sample: [] as unknown[],
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

// Re-export for downstream consumption / testing.
export type { BucketCounts, UidClassification };
