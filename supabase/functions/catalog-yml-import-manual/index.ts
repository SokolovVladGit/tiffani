import { createClient } from "https://esm.sh/@supabase/supabase-js@2";
import { parseTildaYml } from "../catalog-sync/yml-parser.ts";
import { upsertCatalogSlice } from "../catalog-sync/sync-engine.ts";
import type { TildaCatalog } from "../catalog-sync/types.ts";

import { requireAdmin } from "./auth.ts";
import { loadMaxManualYmlUploadBytes } from "./config.ts";
import { computeYmlMetrics, looksLikeYmlText } from "./metrics.ts";
import {
  createManualImportRun,
  finalizeManualImportRun,
  persistManualImportErrors,
  type ManualImportRunStatus,
} from "./run-logger.ts";

/**
 * catalog-yml-import-manual — admin-only fallback when TILDA_YML_URL is down.
 *
 * Contract:
 *   POST /functions/v1/catalog-yml-import-manual
 *   Authorization: Bearer <user JWT> (admin via is_admin())
 *   body:
 *     { "yml_text": "...", "dry_run": true, "filename": "export.xml" }
 *
 * Safety:
 *   - parseTildaYml + upsertCatalogSlice only
 *   - Never syncCatalog / deactivateMissingProducts
 *   - no_deactivation: true on every run
 */

const CORS_HEADERS = {
  "Access-Control-Allow-Origin": "*",
  "Access-Control-Allow-Headers":
    "authorization, x-client-info, apikey, content-type",
  "Access-Control-Allow-Methods": "POST, OPTIONS",
};

const DEFAULT_SOURCE = "manual_admin_upload";

interface RequestBody {
  yml_text?: unknown;
  dry_run?: unknown;
  filename?: unknown;
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

  const auth = await requireAdmin(req);
  if (!auth.ok) {
    return jsonResponse({ error: auth.message }, auth.status);
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

  const ymlText = typeof body.yml_text === "string" ? body.yml_text : "";
  if (ymlText.trim().length === 0) {
    return jsonResponse({ error: "yml_text is required and must be non-empty" }, 400);
  }

  const maxBytes = loadMaxManualYmlUploadBytes();
  const sizeBytes = new TextEncoder().encode(ymlText).length;
  if (sizeBytes > maxBytes) {
    return jsonResponse(
      {
        error: "yml_text exceeds maximum upload size",
        file_size: sizeBytes,
        max_bytes: maxBytes,
        hint:
          "File is too large for inline upload. Storage-based import may be added in a future version.",
      },
      413,
    );
  }

  if (!looksLikeYmlText(ymlText)) {
    return jsonResponse(
      {
        error:
          "file does not look like Tilda YML/XML (expected yml_catalog or shop/offer elements)",
      },
      400,
    );
  }

  const dryRun = body.dry_run !== false;
  const source = typeof body.source === "string" && body.source.length > 0
    ? body.source
    : DEFAULT_SOURCE;
  const filename = typeof body.filename === "string" && body.filename.length > 0
    ? body.filename
    : null;

  const supabaseUrl = Deno.env.get("SUPABASE_URL");
  const serviceKey = Deno.env.get("SUPABASE_SERVICE_ROLE_KEY");
  if (!supabaseUrl || !serviceKey) {
    return jsonResponse(
      { error: "Missing SUPABASE_URL / SUPABASE_SERVICE_ROLE_KEY env vars" },
      500,
    );
  }

  const serviceClient = createClient(supabaseUrl, serviceKey, {
    auth: { persistSession: false },
  });

  const initialStatus: ManualImportRunStatus = dryRun ? "dry_run" : "running";
  const runId = await createManualImportRun(serviceClient, initialStatus, {
    source,
    dry_run: dryRun,
    no_deactivation: true,
    admin_email: auth.adminEmail,
    filename,
    file_size: sizeBytes,
  });

  let catalog: TildaCatalog;
  try {
    catalog = parseTildaYml(ymlText);
  } catch (e) {
    const message = e instanceof Error ? e.message : String(e);
    await persistManualImportErrors(serviceClient, runId, [
      { stage: "parse_yml", external_key: "", message },
    ]);
    await finalizeManualImportRun(serviceClient, runId, {
      status: "failed",
      error_count: 1,
      metadata: buildFinalizeMetadata({
        source,
        dryRun,
        auth,
        filename,
        sizeBytes,
        startedAt,
        fatalError: message,
      }),
    });
    return jsonResponse(
      buildResponse({
        runId,
        mode: dryRun ? "dry_run" : "live",
        status: "failed",
        startedAt,
        ymlMetrics: emptyMetrics(sizeBytes),
        productsSeen: 0,
        variantsSeen: 0,
        imagesSeen: 0,
        productsUpserted: 0,
        variantsUpserted: 0,
        imagesUpserted: 0,
        errorCount: 1,
        errorSample: [{ stage: "parse_yml", msg: message }],
        syncSeenAt: null,
        error: message,
      }),
      502,
    );
  }

  const ymlMetrics = computeYmlMetrics(catalog, sizeBytes);
  const productsSeen = ymlMetrics.groups_count;
  const variantsSeen = ymlMetrics.offers_count;
  const imagesSeen = ymlMetrics.images_in_yml;

  if (dryRun) {
    await finalizeManualImportRun(serviceClient, runId, {
      status: "dry_run_completed",
      products_seen: productsSeen,
      variants_seen: variantsSeen,
      images_seen: imagesSeen,
      error_count: 0,
      metadata: buildFinalizeMetadata({
        source,
        dryRun: true,
        auth,
        filename,
        sizeBytes,
        startedAt,
        yml: ymlMetrics,
      }),
    });

    return jsonResponse(
      buildResponse({
        runId,
        mode: "dry_run",
        status: "dry_run_completed",
        startedAt,
        ymlMetrics,
        productsSeen,
        variantsSeen,
        imagesSeen,
        productsUpserted: 0,
        variantsUpserted: 0,
        imagesUpserted: 0,
        errorCount: 0,
        errorSample: [],
        syncSeenAt: null,
      }),
    );
  }

  const syncSeenAt = new Date().toISOString();

  try {
    const { stats, errors } = await upsertCatalogSlice(
      serviceClient,
      catalog,
      runId ?? crypto.randomUUID(),
      { syncSeenAt },
    );

    const finalStatus: ManualImportRunStatus = errors.length > 0
      ? "completed_with_errors"
      : "completed";

    await persistManualImportErrors(
      serviceClient,
      runId,
      errors.map((e) => ({
        stage: `manual_import.${e.stage}`,
        external_key: e.external_key,
        message: e.message,
        details: e.details,
      })),
    );

    await finalizeManualImportRun(serviceClient, runId, {
      status: finalStatus,
      products_seen: stats.products_seen,
      variants_seen: stats.variants_seen,
      images_seen: stats.images_seen,
      products_upserted: stats.products_upserted,
      variants_upserted: stats.variants_upserted,
      images_upserted: stats.images_upserted,
      error_count: errors.length,
      metadata: buildFinalizeMetadata({
        source,
        dryRun: false,
        auth,
        filename,
        sizeBytes,
        startedAt,
        yml: ymlMetrics,
        syncSeenAt,
      }),
    });

    return jsonResponse(
      buildResponse({
        runId,
        mode: "live",
        status: finalStatus,
        startedAt,
        ymlMetrics,
        productsSeen: stats.products_seen,
        variantsSeen: stats.variants_seen,
        imagesSeen: stats.images_seen,
        productsUpserted: stats.products_upserted,
        variantsUpserted: stats.variants_upserted,
        imagesUpserted: stats.images_upserted,
        errorCount: errors.length,
        errorSample: errors.slice(0, 5).map((e) => ({
          stage: `manual_import.${e.stage}`,
          key: e.external_key,
          msg: e.message,
        })),
        syncSeenAt,
      }),
    );
  } catch (e) {
    const message = e instanceof Error ? e.message : String(e);
    await persistManualImportErrors(serviceClient, runId, [
      { stage: "manual_import.fatal", external_key: "", message },
    ]);
    await finalizeManualImportRun(serviceClient, runId, {
      status: "failed",
      error_count: 1,
      metadata: buildFinalizeMetadata({
        source,
        dryRun: false,
        auth,
        filename,
        sizeBytes,
        startedAt,
        yml: ymlMetrics,
        syncSeenAt,
        fatalError: message,
      }),
    });

    return jsonResponse(
      buildResponse({
        runId,
        mode: "live",
        status: "failed",
        startedAt,
        ymlMetrics,
        productsSeen,
        variantsSeen,
        imagesSeen,
        productsUpserted: 0,
        variantsUpserted: 0,
        imagesUpserted: 0,
        errorCount: 1,
        errorSample: [{ stage: "manual_import.fatal", msg: message }],
        syncSeenAt,
        error: message,
      }),
      500,
    );
  }
});

function buildFinalizeMetadata(args: {
  source: string;
  dryRun: boolean;
  auth: { adminEmail: string | null };
  filename: string | null;
  sizeBytes: number;
  startedAt: number;
  yml?: ReturnType<typeof computeYmlMetrics>;
  syncSeenAt?: string;
  fatalError?: string;
}): Record<string, unknown> {
  const meta: Record<string, unknown> = {
    source: args.source,
    dry_run: args.dryRun,
    no_deactivation: true,
    admin_email: args.auth.adminEmail,
    filename: args.filename,
    file_size: args.sizeBytes,
    duration_ms: Date.now() - args.startedAt,
  };
  if (args.yml) meta.yml = args.yml;
  if (args.syncSeenAt) meta.sync_seen_at = args.syncSeenAt;
  if (args.fatalError) meta.fatal_error = args.fatalError;
  return meta;
}

function emptyMetrics(sizeBytes: number) {
  return {
    size_bytes: sizeBytes,
    categories_count: 0,
    groups_count: 0,
    offers_count: 0,
    offers_with_picture: 0,
    images_in_yml: 0,
  };
}

function buildResponse(args: {
  runId: string | null;
  mode: "dry_run" | "live";
  status: string;
  startedAt: number;
  ymlMetrics: ReturnType<typeof computeYmlMetrics>;
  productsSeen: number;
  variantsSeen: number;
  imagesSeen: number;
  productsUpserted: number;
  variantsUpserted: number;
  imagesUpserted: number;
  errorCount: number;
  errorSample: Array<{ stage: string; key?: string; msg: string }>;
  syncSeenAt: string | null;
  error?: string;
}): Record<string, unknown> {
  const body: Record<string, unknown> = {
    run_id: args.runId,
    mode: args.mode,
    status: args.status,
    duration_ms: Date.now() - args.startedAt,
    yml: args.ymlMetrics,
    products_seen: args.productsSeen,
    products_upserted: args.productsUpserted,
    variants_seen: args.variantsSeen,
    variants_upserted: args.variantsUpserted,
    images_seen: args.imagesSeen,
    images_upserted: args.imagesUpserted,
    error_count: args.errorCount,
    error_sample: args.errorSample,
    warnings: [] as string[],
    no_deactivation: true,
    verdict: args.status === "dry_run_completed"
      ? "safe_to_proceed_to_live"
      : undefined,
    sync_seen_at: args.syncSeenAt,
  };
  if (args.error) body.error = args.error;
  if (args.status !== "dry_run_completed") {
    delete body.verdict;
  }
  return body;
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
