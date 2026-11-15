import { createClient, type SupabaseClient } from "https://esm.sh/@supabase/supabase-js@2";
import type { QueueStore } from "./memory-store.ts";
import { CLAIM_TTL_MS, iso, UID_RE, type CatalogCandidate, type QueueItem, type QueueRun, type QueueStatus } from "./model.ts";

/** Under the hosted PostgREST max-rows cap of 1000. */
export const PAGE_SIZE = 500;

/**
 * Read every row. `fetchPage` uses an inclusive range and must already
 * apply a unique ascending order. A short page ends the read. A full page
 * that does not move past the previous key is a truncated or reordered result.
 */
export async function readOrderedPages<T>(
  fetchPage: (from: number, to: number) => Promise<T[]>,
  key: (row: T) => string,
): Promise<T[]> {
  const rows: T[] = [];
  let from = 0;
  let previousKey: string | null = null;
  for (;;) {
    const page = await fetchPage(from, from + PAGE_SIZE - 1);
    if (page.length > PAGE_SIZE) throw new Error("page_longer_than_requested");
    if (page.length === 0) break;
    let last = key(page[0]);
    if (!last) throw new Error("missing_identifier");
    if (previousKey !== null && last <= previousKey) throw new Error("page_did_not_advance");
    for (let index = 1; index < page.length; index++) {
      const current = key(page[index]);
      if (!current || current <= last) throw new Error("page_not_ordered");
      last = current;
    }
    rows.push(...page);
    previousKey = last;
    if (page.length < PAGE_SIZE) break;
    from += PAGE_SIZE;
  }
  return rows;
}

export function assertUniqueIdentities(rows: { productId: string; tildaUid: string }[]): void {
  const ids = new Set<string>();
  const uids = new Set<string>();
  for (const row of rows) {
    if (!row.productId || !row.tildaUid) throw new Error("missing_identifier");
    if (ids.has(row.productId)) throw new Error("duplicate_product_id");
    if (uids.has(row.tildaUid)) throw new Error("duplicate_tilda_uid");
    ids.add(row.productId);
    uids.add(row.tildaUid);
  }
}

export function assertCountMatches(loaded: number, exact: number | null, label: string): void {
  if (exact == null) throw new Error(`${label}_count_unavailable`);
  if (loaded !== exact) throw new Error(`${label}_incomplete:${loaded}/${exact}`);
}

function exactUid(value: unknown): string {
  if (typeof value !== "string" || !UID_RE.test(value)) throw new Error("tilda_uid_not_exact_text");
  return value;
}

function requireText(value: unknown, label: string): string {
  if (typeof value !== "string" || value.length === 0) throw new Error(`missing_${label}`);
  return value;
}

/**
 * Service-role adapter. Queue rows and run audit only.
 * Catalog image inserts stay in catalog-gallery-recover's catalog adapter,
 * called by executeLive after the approval gate.
 */
export function supabaseQueueStoreFromEnv(): QueueStore | null {
  const url = Deno.env.get("SUPABASE_URL");
  const key = Deno.env.get("SUPABASE_SERVICE_ROLE_KEY");
  if (!url || !key) return null;
  const client = createClient(url, key, { auth: { persistSession: false } });
  return new SupabaseQueueStore(client);
}

class SupabaseQueueStore implements QueueStore {
  constructor(private readonly client: SupabaseClient) {}

  now(): number {
    return Date.now();
  }

  async loadCandidates(): Promise<CatalogCandidate[]> {
    const counted = await this.client.rpc("gallery_recovery_catalog_snapshot", {}, {
      count: "exact",
      head: true,
    });
    if (counted.error) throw new Error(counted.error.message);
    const rows = await readOrderedPages(
      async (from, to) => {
        const { data, error } = await this.client
          .rpc("gallery_recovery_catalog_snapshot")
          .order("tilda_uid", { ascending: true })
          .range(from, to);
        if (error) throw new Error(error.message);
        return (data ?? []) as Record<string, unknown>[];
      },
      (row) => exactUid(row.tilda_uid),
    );
    assertCountMatches(rows.length, counted.count, "snapshot");
    const candidates = rows.map(mapSnapshotRow);
    assertUniqueIdentities(candidates);
    return candidates;
  }

  async loadItems(): Promise<QueueItem[]> {
    const rows = await readOrderedPages(
      async (from, to) => {
        const { data, error } = await this.client
          .from("gallery_recovery_items")
          .select("*")
          .order("tilda_uid", { ascending: true })
          .range(from, to);
        if (error) throw new Error(error.message);
        return (data ?? []) as Record<string, unknown>[];
      },
      (row) => exactUid(row.tilda_uid),
    );
    const items = rows.map(rowToItem);
    assertUniqueIdentities(items);
    assertCountMatches(items.length, await this.countItems(), "queue");
    return items;
  }

  async countItems(): Promise<number> {
    const { count, error } = await this.client
      .from("gallery_recovery_items")
      .select("product_id", { count: "exact", head: true });
    if (error) throw new Error(error.message);
    if (count == null) throw new Error("queue_count_unavailable");
    return count;
  }

  async saveItems(items: QueueItem[]): Promise<void> {
    for (let index = 0; index < items.length; index += PAGE_SIZE) {
      const chunk = items.slice(index, index + PAGE_SIZE);
      if (chunk.length === 0) continue;
      const { error } = await this.client
        .from("gallery_recovery_items")
        .upsert(chunk.map(itemToRow), { onConflict: "product_id" });
      if (error) throw new Error(error.message);
    }
  }

  async saveOwned(items: QueueItem[], token: string): Promise<string[]> {
    const saved: string[] = [];
    for (const item of items) {
      const { data, error } = await this.client
        .from("gallery_recovery_items")
        .update(itemToRow(item))
        .eq("product_id", item.productId)
        .eq("claim_token", token)
        .select("tilda_uid");
      if (error) throw new Error(error.message);
      if (data && data.length > 0) saved.push(item.tildaUid);
    }
    return saved;
  }

  async saveIfLeaseOpen(items: QueueItem[]): Promise<string[]> {
    const staleBefore = new Date(this.now() - CLAIM_TTL_MS).toISOString();
    const saved: string[] = [];
    for (const item of items) {
      const { data, error } = await this.client
        .from("gallery_recovery_items")
        .update(itemToRow(item))
        .eq("product_id", item.productId)
        .or(`claim_token.is.null,claimed_at.lt.${staleBefore}`)
        .select("tilda_uid");
      if (error) throw new Error(error.message);
      if (data && data.length > 0) saved.push(item.tildaUid);
    }
    return saved;
  }

  async claim(limit: number, token: string): Promise<QueueItem[]> {
    const { data, error } = await this.client.rpc("gallery_recovery_claim_batch", {
      p_limit: limit,
      p_token: token,
    });
    if (error) throw new Error(error.message);
    return (data ?? []).map(rowToItem);
  }

  async claimLive(uids: string[], token: string): Promise<QueueItem[] | null> {
    const { data, error } = await this.client.rpc("gallery_recovery_claim_live", {
      p_uids: uids,
      p_token: token,
    });
    if (error) throw new Error(error.message);
    const rows = (data ?? []).map(rowToItem);
    return rows.length === uids.length ? rows : null;
  }

  async claimForRecheck(uid: string, token: string): Promise<
    { item: QueueItem } | { error: "missing" | "claim_held" }
  > {
    const { data, error } = await this.client.rpc("gallery_recovery_claim_recheck", {
      p_uid: uid,
      p_token: token,
    });
    if (error) throw new Error(error.message);
    const rows = (data ?? []).map(rowToItem);
    if (rows.length === 1) return { item: rows[0] };
    const existing = await this.client
      .from("gallery_recovery_items")
      .select("tilda_uid")
      .eq("tilda_uid", uid)
      .limit(1);
    if (existing.error) throw new Error(existing.error.message);
    if (!existing.data || existing.data.length === 0) return { error: "missing" };
    return { error: "claim_held" };
  }

  async addRun(run: QueueRun): Promise<void> {
    const { error } = await this.client.from("gallery_recovery_runs").insert({
      id: run.id,
      mode: run.mode,
      selected_uids: run.selectedUids,
      status: run.status,
      result: run.result,
      error_count: run.errorCount,
      writes: run.writes,
      started_at: run.startedAt,
      finished_at: run.finishedAt,
    });
    if (error) throw new Error(error.message);
  }

  async listRuns(limit: number): Promise<QueueRun[]> {
    const { data, error } = await this.client
      .from("gallery_recovery_runs")
      .select("*")
      .order("started_at", { ascending: false })
      .limit(limit);
    if (error) throw new Error(error.message);
    return (data ?? []).map((row: Record<string, unknown>) => ({
      id: String(row.id),
      mode: row.mode as QueueRun["mode"],
      selectedUids: Array.isArray(row.selected_uids) ? row.selected_uids.map(String) : [],
      status: row.status as QueueRun["status"],
      result: (row.result ?? {}) as Record<string, unknown>,
      errorCount: Number(row.error_count ?? 0),
      writes: Number(row.writes ?? 0),
      startedAt: String(row.started_at),
      finishedAt: row.finished_at == null ? null : String(row.finished_at),
    }));
  }

  async finishRun(
    id: string,
    patch: Pick<QueueRun, "status" | "result" | "errorCount" | "writes" | "finishedAt">,
  ): Promise<void> {
    const { error } = await this.client
      .from("gallery_recovery_runs")
      .update({
        status: patch.status,
        result: patch.result,
        error_count: patch.errorCount,
        writes: patch.writes,
        finished_at: patch.finishedAt,
      })
      .eq("id", id)
      .eq("status", "running");
    if (error) throw new Error(error.message);
  }

  async abandonRunsStartedBefore(cutoffMs: number): Promise<void> {
    const { error } = await this.client
      .from("gallery_recovery_runs")
      .update({
        status: "abandoned",
        finished_at: iso(this.now()),
        result: { abandoned: "lease_expired" },
      })
      .eq("status", "running")
      .lte("started_at", new Date(cutoffMs).toISOString());
    if (error) throw new Error(error.message);
  }
}

function mapSnapshotRow(row: Record<string, unknown>): CatalogCandidate {
  return {
    productId: requireText(row.product_id, "product_id"),
    tildaUid: exactUid(row.tilda_uid),
    variantCount: Number(row.variant_count ?? 0),
    ymlImageCount: Number(row.yml_count ?? 0),
    galleryImageCount: Number(row.gallery_count ?? 0),
    galleryUrls: Array.isArray(row.gallery_urls) ? row.gallery_urls.map(String) : [],
    primaryUrl: typeof row.primary_url === "string" ? row.primary_url : "",
    primaryMatches: row.primary_matches === true,
    hidden: row.hidden === true,
  };
}

function rowToItem(row: Record<string, unknown>): QueueItem {
  return {
    productId: requireText(row.product_id, "product_id"),
    tildaUid: exactUid(row.tilda_uid),
    status: String(row.status) as QueueStatus,
    dbVariantCount: Number(row.db_variant_count ?? 0),
    websiteEditionCount: row.website_edition_count == null ? null : Number(row.website_edition_count),
    websiteImageCount: row.website_image_count == null ? null : Number(row.website_image_count),
    existingPrimaryCount: Number(row.existing_primary_count ?? 0),
    confirmedSupplementaryCount: Number(row.confirmed_supplementary_count ?? 0),
    expectedNewImageCount: Number(row.expected_new_image_count ?? 0),
    importableUrls: Array.isArray(row.importable_urls) ? row.importable_urls.map(String) : [],
    contentFingerprint: row.content_fingerprint == null ? null : String(row.content_fingerprint),
    lastCheckedAt: asText(row.last_checked_at),
    nextCheckAt: asText(row.next_check_at),
    lastSuccessAt: asText(row.last_success_at),
    errorClassification: row.error_classification == null ? null : String(row.error_classification),
    retryCount: Number(row.retry_count ?? 0),
    lastError: row.last_error == null ? null : String(row.last_error),
    claimedAt: asText(row.claimed_at),
    claimToken: row.claim_token == null ? null : String(row.claim_token),
    updatedAt: asText(row.updated_at) ?? iso(Date.now()),
  };
}

function itemToRow(item: QueueItem): Record<string, unknown> {
  return {
    product_id: item.productId,
    tilda_uid: item.tildaUid,
    status: item.status,
    db_variant_count: item.dbVariantCount,
    website_edition_count: item.websiteEditionCount,
    website_image_count: item.websiteImageCount,
    existing_primary_count: item.existingPrimaryCount,
    confirmed_supplementary_count: item.confirmedSupplementaryCount,
    expected_new_image_count: item.expectedNewImageCount,
    importable_urls: item.importableUrls,
    content_fingerprint: item.contentFingerprint,
    last_checked_at: item.lastCheckedAt,
    next_check_at: item.nextCheckAt,
    last_success_at: item.lastSuccessAt,
    error_classification: item.errorClassification,
    retry_count: item.retryCount,
    last_error: item.lastError,
    claimed_at: item.claimedAt,
    claim_token: item.claimToken,
    updated_at: item.updatedAt,
  };
}

function asText(value: unknown): string | null {
  return typeof value === "string" && value ? value : null;
}
