import type { SupabaseClient } from "https://esm.sh/@supabase/supabase-js@2";
import type { SyncError } from "./types.ts";
import type { SyncConfig } from "./config.ts";

/**
 * Enriches product gallery images by scraping Tilda product pages.
 *
 * Processes a limited batch of products per run (configurable via
 * SYNC_GALLERY_BATCH_SIZE). Over multiple sync cycles, all products
 * get enriched. Only products missing gallery images (position > 0)
 * are selected.
 *
 * Failure in this step never fails the overall catalog sync.
 */
export async function enrichGallery(
  client: SupabaseClient,
  config: SyncConfig,
): Promise<{ imagesUpserted: number; errors: SyncError[] }> {
  const errors: SyncError[] = [];
  let imagesUpserted = 0;

  const candidates = await findEnrichmentCandidates(
    client,
    config.galleryBatchSize,
  );
  if (candidates.length === 0) {
    return { imagesUpserted, errors };
  }

  const results = await runWithConcurrency(
    candidates,
    config.galleryConcurrency,
    async ({ productId, tildaUid }) => {
      try {
        const images = await fetchGalleryImages(tildaUid, config);
        if (images.length <= 1) return 0;

        const galleryImages = images.slice(1).map((url, i) => ({
          product_id: productId,
          url,
          position: i + 1,
        }));

        const { error } = await client
          .from("product_images")
          .upsert(galleryImages, { onConflict: "product_id,url" });

        if (error) {
          errors.push({
            stage: "gallery_upsert",
            external_key: tildaUid,
            message: error.message,
          });
          return 0;
        }

        return galleryImages.length;
      } catch (e) {
        errors.push({
          stage: "gallery_fetch",
          external_key: tildaUid,
          message: e instanceof Error ? e.message : String(e),
        });
        return 0;
      }
    },
  );

  imagesUpserted = results.reduce((sum, n) => sum + n, 0);
  return { imagesUpserted, errors };
}

interface EnrichCandidate {
  productId: string;
  tildaUid: string;
}

/**
 * Finds active tilda-sourced products that have no gallery images yet.
 * Returns up to `limit` candidates for enrichment.
 */
async function findEnrichmentCandidates(
  client: SupabaseClient,
  limit: number,
): Promise<EnrichCandidate[]> {
  const { data: products } = await client
    .from("catalog_items")
    .select("product_id, tilda_uid")
    .eq("is_active", true)
    .not("tilda_uid", "is", null)
    .limit(1000);

  if (!products || products.length === 0) return [];

  const uniqueProducts = new Map<string, string>();
  for (const p of products) {
    if (!uniqueProducts.has(p.product_id)) {
      uniqueProducts.set(p.product_id, p.tilda_uid);
    }
  }

  const productIds = [...uniqueProducts.keys()];
  const { data: existingGallery } = await client
    .from("product_images")
    .select("product_id")
    .in("product_id", productIds)
    .gt("position", 0);

  const enrichedIds = new Set(
    (existingGallery ?? []).map((r) => r.product_id),
  );

  const candidates: EnrichCandidate[] = [];
  for (const [productId, tildaUid] of uniqueProducts) {
    if (enrichedIds.has(productId)) continue;
    candidates.push({ productId, tildaUid });
    if (candidates.length >= limit) break;
  }

  return candidates;
}

async function fetchGalleryImages(
  tildaUid: string,
  config: SyncConfig,
): Promise<string[]> {
  const url = `https://tiffani.md/tproduct/${tildaUid}`;

  const controller = new AbortController();
  const timeout = setTimeout(
    () => controller.abort(),
    config.requestTimeoutMs,
  );

  try {
    const response = await fetch(url, {
      headers: {
        "User-Agent": config.userAgent,
        Accept:
          "text/html,application/xhtml+xml,application/xml;q=0.9,*/*;q=0.8",
        "Accept-Language": "en-US,en;q=0.5",
      },
      signal: controller.signal,
      redirect: "follow",
    });

    if (!response.ok) {
      throw new Error(`HTTP ${response.status}`);
    }

    const html = await response.text();
    return parseGalleryFromHtml(html);
  } finally {
    clearTimeout(timeout);
  }
}

/**
 * Extracts gallery image URLs from Tilda product page HTML.
 *
 * Primary strategy: parse `var product = {...}` JS object for gallery array.
 * Fallback: regex extraction from the gallery substring.
 *
 * Mirrors the logic in scripts/extract-tilda-images-batch.js.
 */
function parseGalleryFromHtml(html: string): string[] {
  const match = html.match(/var\s+product\s*=\s*(\{.+?\});/s);
  if (!match) return [];

  let images: string[] = [];

  try {
    const product = JSON.parse(match[1]);
    if (Array.isArray(product.gallery)) {
      for (const entry of product.gallery) {
        if (
          entry.img &&
          typeof entry.img === "string" &&
          entry.img.includes("static.tildacdn")
        ) {
          images.push(entry.img);
        }
      }
    }
  } catch {
    const galleryMatch = match[1].match(/"gallery"\s*:\s*\[([^\]]+)\]/);
    if (galleryMatch) {
      const urlMatches = galleryMatch[1].match(
        /https?:\\?\/\\?\/static\.tildacdn\.[^"'\\]+/g,
      );
      if (urlMatches) {
        images = urlMatches.map((u) => u.replace(/\\\//g, "/"));
      }
    }
  }

  return [...new Set(images)];
}

async function runWithConcurrency<T, R>(
  items: T[],
  concurrency: number,
  fn: (item: T) => Promise<R>,
): Promise<R[]> {
  const results: R[] = [];
  const queue = [...items];

  async function worker() {
    while (queue.length > 0) {
      const item = queue.shift()!;
      results.push(await fn(item));
    }
  }

  const workers = Array.from(
    { length: Math.min(concurrency, items.length) },
    () => worker(),
  );
  await Promise.all(workers);
  return results;
}
