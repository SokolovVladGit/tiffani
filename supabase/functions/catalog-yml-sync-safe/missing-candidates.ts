import type { SupabaseClient } from "https://esm.sh/@supabase/supabase-js@2";
import type { TildaCatalog } from "../catalog-sync/types.ts";

/**
 * Read-only diff helper used by the safe YML sync.
 *
 * Computes the set of products that:
 *   - have a non-NULL `tilda_uid` (i.e. are Tilda-sourced — admin
 *     products with `tilda_uid IS NULL` are excluded by design),
 *   - are currently `is_active = true`,
 *   - and whose `tilda_uid` is NOT present in the current YML feed
 *     (neither as an offer id nor as a group id).
 *
 * The result is informational only. The caller MUST NOT use it to
 * deactivate, delete, or otherwise mutate any row — v1 automation
 * never touches missing products. The structural test in this
 * folder asserts that this module never invokes any non-`select`
 * supabase-js mutation method.
 */

export interface MissingCandidatesResult {
  /** Active Tilda-sourced products considered for the diff. */
  active_products_with_tilda_uid_in_db: number;
  /** Subset of the above whose tilda_uid is absent from the YML. */
  absent_from_current_yml: number;
  /** Up to `sampleLimit` example tilda_uids of missing rows. */
  sample: string[];
  /** Constant — pinned so monitoring queries can verify intent. */
  action_taken: "none";
}

const PAGE_SIZE = 5_000;

/**
 * Computes the missing-candidates summary by comparing active
 * Tilda-sourced products in the database against the union of
 * offer ids and group ids in the parsed YML catalog.
 *
 * Schema-compatible:
 *   - Reads only `products.tilda_uid` of active rows.
 *   - Never selects, joins, or modifies admin products.
 *   - Never reads anything from `product_variants` or
 *     `product_images` (no need for the diff).
 *
 * @param client       Supabase service-role client.
 * @param catalog      Parsed YML catalog (offers + categories).
 * @param sampleLimit  Maximum number of sample uids to include.
 */
export async function computeMissingCandidates(
  client: SupabaseClient,
  catalog: TildaCatalog,
  sampleLimit: number,
): Promise<MissingCandidatesResult> {
  const ymlKeys = collectYmlKeys(catalog);

  let total = 0;
  let missingCount = 0;
  const missingSample: string[] = [];

  let page = 0;
  while (true) {
    const from = page * PAGE_SIZE;
    const to = from + PAGE_SIZE - 1;

    const { data, error } = await client
      .from("products")
      .select("tilda_uid")
      .eq("is_active", true)
      .not("tilda_uid", "is", null)
      .range(from, to);

    if (error) {
      throw new Error(
        `missing-candidates page ${page} failed: ${error.message}`,
      );
    }
    if (!data || data.length === 0) break;

    total += data.length;
    for (const row of data) {
      const uid = String((row as { tilda_uid: string }).tilda_uid ?? "");
      if (!uid) continue;
      if (!ymlKeys.has(uid)) {
        missingCount++;
        if (missingSample.length < sampleLimit) {
          missingSample.push(uid);
        }
      }
    }

    if (data.length < PAGE_SIZE) break;
    page++;
  }

  return {
    active_products_with_tilda_uid_in_db: total,
    absent_from_current_yml: missingCount,
    sample: missingSample,
    action_taken: "none",
  };
}

/**
 * Extracts the union of every offer id and group id present in the
 * parsed YML catalog. Used to test whether a product's `tilda_uid`
 * is still represented in the current feed.
 *
 * Exported for unit tests; not used by callers outside this module.
 */
export function collectYmlKeys(catalog: TildaCatalog): Set<string> {
  const keys = new Set<string>();
  for (const offer of catalog.offers) {
    if (offer.id) keys.add(offer.id);
    if (offer.groupId) keys.add(offer.groupId);
  }
  return keys;
}
