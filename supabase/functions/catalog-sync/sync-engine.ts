import type { SupabaseClient } from "https://esm.sh/@supabase/supabase-js@2";
import type {
  TildaCatalog,
  TildaOffer,
  ProductRow,
  VariantRow,
  ProductImageRow,
  SyncStats,
  SyncError,
} from "./types.ts";
import { buildCategoryLookup } from "./yml-parser.ts";

const BATCH_SIZE = 50;

const EDITION_PARAMS = new Set([
  "Объём",
  "Объем",
  "Размер",
  "Size",
  "Volume",
]);
const MODIFICATION_PARAMS = new Set([
  "Цвет",
  "Оттенок",
  "Color",
  "Shade",
  "Тон",
]);

/**
 * Syncs parsed Tilda catalog into the base tables:
 *   products         — product-level data  (conflict key: tilda_uid)
 *   product_variants — variant/SKU data    (conflict key: variant_id)
 *   product_images   — main images         (conflict key: product_id + url)
 *
 * catalog_items is a VIEW — the sync never writes to it.
 *
 * Memory-optimised: variant and image rows are processed in streaming
 * chunks rather than accumulated into full arrays up-front.
 */
export async function syncCatalog(
  client: SupabaseClient,
  catalog: TildaCatalog,
  _runId: string,
): Promise<{ stats: SyncStats; errors: SyncError[] }> {
  const errors: SyncError[] = [];
  const stats: SyncStats = {
    products_seen: 0,
    variants_seen: 0,
    images_seen: 0,
    products_upserted: 0,
    variants_upserted: 0,
    images_upserted: 0,
    error_count: 0,
  };

  const categoryLookup = buildCategoryLookup(catalog.categories);
  const productGroups = groupOffersByProduct(catalog.offers);
  stats.products_seen = productGroups.size;
  stats.variants_seen = catalog.offers.length;

  // --- Phase 1: Build and upsert product-level rows ---
  const seenTildaUids = new Set<string>();
  const productRows: ProductRow[] = [];
  for (const [tildaUid, offers] of productGroups) {
    try {
      productRows.push(buildProductRow(tildaUid, offers[0], categoryLookup));
      seenTildaUids.add(tildaUid);
    } catch (e) {
      errors.push({
        stage: "build_product",
        external_key: tildaUid,
        message: e instanceof Error ? e.message : String(e),
      });
    }
  }

  for (let i = 0; i < productRows.length; i += BATCH_SIZE) {
    const batch = productRows.slice(i, i + BATCH_SIZE);
    const { error } = await client
      .from("products")
      .upsert(batch, { onConflict: "tilda_uid" });

    if (error) {
      for (const row of batch) {
        const { error: rowErr } = await client
          .from("products")
          .upsert(row, { onConflict: "tilda_uid" });

        if (rowErr) {
          errors.push({
            stage: "upsert_product",
            external_key: row.tilda_uid,
            message: rowErr.message,
            details: { code: (rowErr as Record<string, unknown>).code },
          });
        } else {
          stats.products_upserted++;
        }
      }
    } else {
      stats.products_upserted += batch.length;
    }
  }

  // --- Phase 2: Resolve product PKs ---
  const tildaUids = productRows.map((r) => r.tilda_uid);
  const productIdMap = await resolveProductIds(client, tildaUids);

  // --- Phase 3: Stream variant + image upserts in chunks ---
  // Avoids building full 2400-row arrays; only one chunk lives in memory.
  const seenImageKeys = new Set<string>();
  const offers = catalog.offers;

  for (let i = 0; i < offers.length; i += BATCH_SIZE) {
    const chunk = offers.slice(i, i + BATCH_SIZE);
    const variantBatch: VariantRow[] = [];
    const imageBatch: ProductImageRow[] = [];

    for (const offer of chunk) {
      const productKey = offer.groupId ?? offer.id;
      const resolvedProductId = productIdMap.get(productKey);

      if (!resolvedProductId) {
        errors.push({
          stage: "resolve_product_id",
          external_key: offer.id,
          message: `Could not resolve product PK for tilda_uid=${productKey}`,
        });
        continue;
      }

      try {
        variantBatch.push(
          buildVariantRow(offer, resolvedProductId, categoryLookup),
        );

        if (offer.picture) {
          const imageKey = `${resolvedProductId}|${offer.picture}`;
          if (!seenImageKeys.has(imageKey)) {
            seenImageKeys.add(imageKey);
            imageBatch.push({
              product_id: resolvedProductId,
              url: offer.picture,
              position: 0,
            });
          }
        }
      } catch (e) {
        errors.push({
          stage: "build_variant",
          external_key: offer.id,
          message: e instanceof Error ? e.message : String(e),
        });
      }
    }

    stats.images_seen += imageBatch.length;

    if (variantBatch.length > 0) {
      const { error } = await client
        .from("product_variants")
        .upsert(variantBatch, { onConflict: "variant_id" });

      if (error) {
        for (const row of variantBatch) {
          const { error: rowErr } = await client
            .from("product_variants")
            .upsert(row, { onConflict: "variant_id" });

          if (rowErr) {
            errors.push({
              stage: "upsert_variant",
              external_key: row.variant_id,
              message: rowErr.message,
              details: { code: (rowErr as Record<string, unknown>).code },
            });
          } else {
            stats.variants_upserted++;
          }
        }
      } else {
        stats.variants_upserted += variantBatch.length;
      }
    }

    if (imageBatch.length > 0) {
      const { error } = await client
        .from("product_images")
        .upsert(imageBatch, { onConflict: "product_id,url" });

      if (error) {
        errors.push({
          stage: "upsert_images",
          external_key: `chunk_${i}`,
          message: error.message,
        });
      } else {
        stats.images_upserted += imageBatch.length;
      }
    }
  }

  // --- Phase 4: Deactivate missing products ---
  await deactivateMissingProducts(client, seenTildaUids, errors);

  stats.error_count = errors.length;
  return { stats, errors };
}

/**
 * Resolves tilda_uid → products.id mapping.
 */
async function resolveProductIds(
  client: SupabaseClient,
  tildaUids: string[],
): Promise<Map<string, string>> {
  const map = new Map<string, string>();
  for (let i = 0; i < tildaUids.length; i += BATCH_SIZE) {
    const batch = tildaUids.slice(i, i + BATCH_SIZE);
    const { data } = await client
      .from("products")
      .select("id, tilda_uid")
      .in("tilda_uid", batch);

    if (data) {
      for (const row of data) {
        map.set(
          row.tilda_uid,
          typeof row.id === "string" ? row.id : String(row.id),
        );
      }
    }
  }
  return map;
}

function groupOffersByProduct(
  offers: TildaOffer[],
): Map<string, TildaOffer[]> {
  const groups = new Map<string, TildaOffer[]>();
  for (const offer of offers) {
    const key = offer.groupId ?? offer.id;
    let group = groups.get(key);
    if (!group) {
      group = [];
      groups.set(key, group);
    }
    group.push(offer);
  }
  return groups;
}

/**
 * Soft-deactivate products in the `products` table that disappeared
 * from the Tilda feed.
 *
 * `is_active` lives on `products`, not on `product_variants`.
 * Compares by `tilda_uid` (product-level key).
 * Items without tilda_uid (manually added) are never touched.
 */
async function deactivateMissingProducts(
  client: SupabaseClient,
  seenTildaUids: Set<string>,
  errors: SyncError[],
): Promise<void> {
  const { data: activeProducts } = await client
    .from("products")
    .select("tilda_uid")
    .eq("is_active", true)
    .not("tilda_uid", "is", null);

  if (!activeProducts) return;

  const toDeactivate = activeProducts
    .filter((r) => !seenTildaUids.has(r.tilda_uid))
    .map((r) => r.tilda_uid);

  for (let i = 0; i < toDeactivate.length; i += BATCH_SIZE) {
    const batch = toDeactivate.slice(i, i + BATCH_SIZE);
    const { error } = await client
      .from("products")
      .update({ is_active: false })
      .in("tilda_uid", batch);

    if (error) {
      errors.push({
        stage: "deactivate_missing",
        external_key: `batch_${i}_of_${toDeactivate.length}`,
        message: error.message,
      });
    }
  }
}

function buildProductRow(
  tildaUid: string,
  representative: TildaOffer,
  categories: Map<string, string>,
): ProductRow {
  const category = representative.categoryId
    ? categories.get(representative.categoryId) ?? null
    : null;

  return {
    tilda_uid: tildaUid,
    title: representative.name ?? `Product ${tildaUid}`,
    brand: representative.vendor ?? null,
    category,
    description: representative.description
      ? stripHtml(representative.description).slice(0, 500)
      : null,
    photo: representative.picture ?? null,
    is_active: true,
  };
}

function buildVariantRow(
  offer: TildaOffer,
  productId: string,
  categories: Map<string, string>,
): VariantRow {
  let edition: string | null = null;
  let modification: string | null = null;
  const attrs: Record<string, string> = {};

  for (const p of offer.params) {
    attrs[p.name] = p.value;
    if (!edition && EDITION_PARAMS.has(p.name)) edition = p.value;
    if (!modification && MODIFICATION_PARAMS.has(p.name))
      modification = p.value;
  }

  void categories;

  return {
    variant_id: offer.id,
    product_id: productId,
    title: offer.name ?? `Variant ${offer.id}`,
    price: offer.price ?? null,
    old_price: offer.oldPrice ?? null,
    quantity: offer.count ?? null,
    editions: edition,
    modifications: modification,
    photo: offer.picture ?? null,
    attributes: Object.keys(attrs).length > 0 ? attrs : null,
  };
}

function stripHtml(html: string): string {
  return html
    .replace(/<br\s*\/?>/gi, "\n")
    .replace(/<\/p>/gi, "\n")
    .replace(/<[^>]+>/g, "")
    .replace(/&nbsp;/g, " ")
    .replace(/&amp;/g, "&")
    .replace(/&lt;/g, "<")
    .replace(/&gt;/g, ">")
    .replace(/&quot;/g, '"')
    .replace(/&#39;/g, "'")
    .replace(/\n{3,}/g, "\n\n")
    .trim();
}
