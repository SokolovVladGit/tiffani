import type { TildaCatalog, TildaOffer } from "../catalog-sync/types.ts";
import type { UidBucket, UidClassification } from "./types.ts";
import type { YmlIndex } from "./yml-index.ts";

/**
 * Buckets eligible for upsert. Everything else is skipped.
 */
const UPSERT_BUCKETS: ReadonlySet<UidBucket> = new Set([
  "found_in_yml_offer",
  "found_in_yml_group",
]);

export interface SliceMetrics {
  /** Distinct offers included in the slice. */
  offers_included: number;
  /** Distinct product groups (tilda_uid keys) included. */
  products_included: number;
  /** Offers that appeared in multiple buckets and were deduplicated. */
  duplicates_collapsed: number;
  /** Offers dropped because they had no non-empty id. */
  invalid_offers_skipped: number;
  /** Eligible classifications that resolved to zero offers. */
  unresolved_classifications: number;
  /** Skipped UIDs grouped by bucket. */
  skipped_by_bucket: Partial<Record<UidBucket, number>>;
}

export interface BuildSliceResult {
  slice: TildaCatalog;
  metrics: SliceMetrics;
}

/**
 * Synthesizes a `TildaCatalog` slice from classification results,
 * including only offers that map to UIDs in upsert-eligible buckets.
 *
 * Safety rules:
 *   - Only `found_in_yml_offer` and `found_in_yml_group` contribute offers.
 *   - Offers are deduplicated by `offer.id` (a UID can appear in both the
 *     offer-axis and the group-axis of the same request).
 *   - Offers with empty/missing `id` are dropped (would violate the
 *     `variant_id` NOT NULL contract).
 *   - Offers with empty/missing `groupId` keep the existing fallback
 *     (`groupId ?? id`) from the sync engine; they are NOT dropped, but
 *     are counted for observability.
 *   - All categories from the source YML are carried over so the sync
 *     engine's category-name lookup resolves every `categoryId`.
 */
export function buildUpsertSlice(
  results: readonly UidClassification[],
  index: YmlIndex,
  source: TildaCatalog,
): BuildSliceResult {
  const included = new Map<string, TildaOffer>();
  const productKeys = new Set<string>();
  let duplicatesCollapsed = 0;
  let invalidOffersSkipped = 0;
  let unresolvedClassifications = 0;
  const skippedByBucket: Partial<Record<UidBucket, number>> = {};

  for (const r of results) {
    if (!UPSERT_BUCKETS.has(r.bucket)) {
      skippedByBucket[r.bucket] = (skippedByBucket[r.bucket] ?? 0) + 1;
      continue;
    }

    const offersForRow = resolveOffersFor(r, index);
    if (offersForRow.length === 0) {
      unresolvedClassifications += 1;
      continue;
    }

    for (const offer of offersForRow) {
      if (!offer.id) {
        invalidOffersSkipped += 1;
        continue;
      }
      if (included.has(offer.id)) {
        duplicatesCollapsed += 1;
        continue;
      }
      included.set(offer.id, offer);
      productKeys.add(offer.groupId ?? offer.id);
    }
  }

  const slice: TildaCatalog = {
    categories: source.categories,
    offers: [...included.values()],
  };

  return {
    slice,
    metrics: {
      offers_included: included.size,
      products_included: productKeys.size,
      duplicates_collapsed: duplicatesCollapsed,
      invalid_offers_skipped: invalidOffersSkipped,
      unresolved_classifications: unresolvedClassifications,
      skipped_by_bucket: skippedByBucket,
    },
  };
}

function resolveOffersFor(
  r: UidClassification,
  index: YmlIndex,
): TildaOffer[] {
  if (r.bucket === "found_in_yml_offer") {
    const id = r.offer_id ?? r.uid;
    const offer = index.byOfferId.get(id);
    return offer ? [offer] : [];
  }
  if (r.bucket === "found_in_yml_group") {
    const gid = r.group_id ?? r.uid;
    return index.byGroupId.get(gid) ?? [];
  }
  return [];
}
