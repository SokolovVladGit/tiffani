import { createClient } from "https://esm.sh/@supabase/supabase-js@2";
import { loadConfig } from "./config.ts";
import { parseTildaYml } from "./yml-parser.ts";
import { syncCatalog } from "./sync-engine.ts";
import { enrichGallery } from "./gallery-enricher.ts";
import type { SyncError } from "./types.ts";

const CORS_HEADERS = {
  "Access-Control-Allow-Origin": "*",
  "Access-Control-Allow-Headers":
    "authorization, x-client-info, apikey, content-type",
};

Deno.serve(async (req) => {
  if (req.method === "OPTIONS") {
    return jsonResponse("ok", 200);
  }

  const supabaseUrl = Deno.env.get("SUPABASE_URL");
  const supabaseKey = Deno.env.get("SUPABASE_SERVICE_ROLE_KEY");

  if (!supabaseUrl || !supabaseKey) {
    return jsonResponse({ error: "Missing Supabase credentials" }, 500);
  }

  const client = createClient(supabaseUrl, supabaseKey, {
    auth: { persistSession: false },
  });

  let config;
  try {
    config = loadConfig();
  } catch (e) {
    return jsonResponse({ error: (e as Error).message }, 400);
  }

  let dryRun = false;
  try {
    const body = await req.json();
    dryRun = body?.dry_run === true;
  } catch { /* no body or invalid JSON — default to live run */ }

  const { data: run, error: runError } = await client
    .from("catalog_sync_runs")
    .insert({
      status: dryRun ? "dry_run" : "running",
      source_type: "yml",
      started_at: new Date().toISOString(),
    })
    .select("id")
    .single();

  if (runError || !run) {
    return jsonResponse(
      { error: "Failed to create sync run", details: runError?.message },
      500,
    );
  }

  const runId: string = run.id;
  const allErrors: SyncError[] = [];
  let syncStatus = dryRun ? "dry_run_completed" : "completed";

  try {
    const ymlResponse = await fetch(config.tildaYmlUrl, {
      headers: { "User-Agent": config.userAgent },
      signal: AbortSignal.timeout(config.requestTimeoutMs),
    });

    if (!ymlResponse.ok) {
      throw new Error(`YML fetch failed: HTTP ${ymlResponse.status}`);
    }

    let ymlText = await ymlResponse.text();
    const ymlSizeBytes = ymlText.length;
    const catalog = parseTildaYml(ymlText);
    ymlText = "";

    const offersCount = catalog.offers.length;
    const categoriesCount = catalog.categories.length;

    if (dryRun) {
      await client
        .from("catalog_sync_runs")
        .update({
          status: "dry_run_completed",
          finished_at: new Date().toISOString(),
          products_seen: new Set(catalog.offers.map((o) => o.groupId ?? o.id)).size,
          variants_seen: offersCount,
          images_seen: catalog.offers.filter((o) => o.picture).length,
          metadata: {
            yml_url: config.tildaYmlUrl,
            yml_size_bytes: ymlSizeBytes,
            categories_count: categoriesCount,
            offers_count: offersCount,
            dry_run: true,
          },
        })
        .eq("id", runId);

      return jsonResponse({
        run_id: runId,
        status: "dry_run_completed",
        dry_run: true,
        yml_size_bytes: ymlSizeBytes,
        categories_count: categoriesCount,
        products_seen: new Set(catalog.offers.map((o) => o.groupId ?? o.id)).size,
        variants_seen: offersCount,
        images_in_yml: catalog.offers.filter((o) => o.picture).length,
        sample_offer: catalog.offers[0]
          ? { id: catalog.offers[0].id, name: catalog.offers[0].name, groupId: catalog.offers[0].groupId }
          : null,
      });
    }

    const { stats, errors: syncErrors } = await syncCatalog(
      client,
      catalog,
      runId,
    );
    allErrors.push(...syncErrors);

    let galleryImagesUpserted = 0;
    let galleryErrorCount = 0;

    if (config.galleryEnabled) {
      try {
        const galleryResult = await enrichGallery(client, config);
        galleryImagesUpserted = galleryResult.imagesUpserted;
        galleryErrorCount = galleryResult.errors.length;
        allErrors.push(...galleryResult.errors);
      } catch (e) {
        allErrors.push({
          stage: "gallery_enrichment",
          external_key: "",
          message: (e as Error).message,
        });
      }
    }

    if (syncErrors.length > 0) {
      syncStatus = "completed_with_errors";
    } else if (galleryErrorCount > 0) {
      syncStatus = "completed_gallery_errors";
    }

    await client
      .from("catalog_sync_runs")
      .update({
        status: syncStatus,
        finished_at: new Date().toISOString(),
        products_seen: stats.products_seen,
        variants_seen: stats.variants_seen,
        images_seen: stats.images_seen + galleryImagesUpserted,
        products_upserted: stats.products_upserted,
        variants_upserted: stats.variants_upserted,
        images_upserted: stats.images_upserted + galleryImagesUpserted,
        error_count: allErrors.length,
        metadata: {
          yml_url: config.tildaYmlUrl,
          yml_size_bytes: ymlSizeBytes,
          categories_count: categoriesCount,
          offers_count: offersCount,
          gallery_enabled: config.galleryEnabled,
          gallery_images_upserted: galleryImagesUpserted,
        },
      })
      .eq("id", runId);

    if (allErrors.length > 0) {
      await persistErrors(client, runId, allErrors);
    }

    const errorSample = allErrors.slice(0, 5).map((e) => ({
      stage: e.stage,
      key: e.external_key,
      msg: e.message,
      det: e.details,
    }));

    return jsonResponse({
      run_id: runId,
      status: syncStatus,
      products_seen: stats.products_seen,
      products_upserted: stats.products_upserted,
      variants_seen: stats.variants_seen,
      variants_upserted: stats.variants_upserted,
      images_upserted: stats.images_upserted + galleryImagesUpserted,
      error_count: allErrors.length,
      error_sample: errorSample,
    });
  } catch (e) {
    const message = (e as Error).message;
    syncStatus = "failed";

    await client
      .from("catalog_sync_runs")
      .update({
        status: syncStatus,
        finished_at: new Date().toISOString(),
        error_count: 1,
        metadata: { fatal_error: message },
      })
      .eq("id", runId);

    await persistErrors(client, runId, [
      { stage: "fatal", external_key: "", message },
    ]);

    return jsonResponse(
      { run_id: runId, status: "failed", error: message },
      500,
    );
  }
});

async function persistErrors(
  client: ReturnType<typeof createClient>,
  runId: string,
  errors: SyncError[],
): Promise<void> {
  const rows = errors.map((e) => ({
    run_id: runId,
    stage: e.stage,
    external_key: e.external_key,
    message: e.message,
    details: e.details ?? null,
  }));

  const BATCH = 100;
  for (let i = 0; i < rows.length; i += BATCH) {
    await client
      .from("catalog_sync_run_errors")
      .insert(rows.slice(i, i + BATCH));
  }
}

function jsonResponse(body: unknown, status = 200): Response {
  return new Response(JSON.stringify(body), {
    status,
    headers: { "Content-Type": "application/json", ...CORS_HEADERS },
  });
}
