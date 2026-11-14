import type { GalleryCatalog } from "../catalog-gallery-recover/catalog.ts";
import { imageIdentity } from "../catalog-gallery-recover/image-identity.ts";
import { recoverGalleries } from "../catalog-gallery-recover/recover.ts";
import { supplementalRows } from "../catalog-gallery-recover/rows.ts";
import type { QueueStore } from "./memory-store.ts";
import {
  BATCH_LIMIT,
  CLAIM_TTL_MS,
  assertBootstrapCoverage,
  bootstrapItems,
  claimBatch,
  classifyInspection,
  compareUid,
  completedFromGallery,
  galleryFingerprint,
  iso,
  isAutomaticallyEligible,
  leaseOpen,
  type QueueItem,
  type QueueRun,
} from "./model.ts";

export interface QueueDeps {
  fetch: typeof fetch;
  catalog?: GalleryCatalog;
}

function runId(): string {
  return crypto.randomUUID();
}

async function writeRun(
  store: QueueStore,
  run: Omit<QueueRun, "id" | "startedAt" | "finishedAt"> & { startedAt?: string },
): Promise<void> {
  const now = iso(store.now());
  await store.addRun({
    id: runId(),
    startedAt: run.startedAt ?? now,
    finishedAt: now,
    ...run,
  });
}

export const UPSERT_CHUNK = 500;

export async function bootstrap(store: QueueStore): Promise<{
  counts: Record<string, number>;
  skippedHistorical: string[];
  writes: 0;
  snapshotRows: number;
  queueRows: number;
}> {
  let verified = false;
  try {
    const now = store.now();
    const candidates = await store.loadCandidates();
    const existing = await store.loadItems();
    const built = bootstrapItems(candidates, existing, now);
    assertBootstrapCoverage(candidates, existing, built);
    const previous = new Map(existing.map((item) => [item.productId, JSON.stringify(item)]));
    const changed = built.items.filter((item) => previous.get(item.productId) !== JSON.stringify(item));
    for (let index = 0; index < changed.length; index += UPSERT_CHUNK) {
      await store.saveItems(changed.slice(index, index + UPSERT_CHUNK));
    }
    const items = await store.loadItems();
    const queueRows = await store.countItems();
    if (items.length !== built.items.length || queueRows !== built.items.length) {
      throw new Error(`bootstrap_incomplete:${items.length}/${queueRows}/${built.items.length}`);
    }
    verified = true;
    await writeRun(store, {
      mode: "bootstrap",
      selectedUids: [],
      status: "completed",
      errorCount: 0,
      writes: 0,
      result: {
        upserted: changed.length,
        skippedHistorical: built.skippedHistorical,
        snapshotRows: candidates.length,
        queueRows,
      },
    });
    return {
      counts: countStatuses(items),
      skippedHistorical: built.skippedHistorical,
      writes: 0,
      snapshotRows: candidates.length,
      queueRows,
    };
  } catch (error) {
    if (!verified) {
      await writeRun(store, {
        mode: "bootstrap",
        selectedUids: [],
        status: "failed",
        errorCount: 1,
        writes: 0,
        result: { error: error instanceof Error ? error.message : "bootstrap_failed" },
      }).catch(() => undefined);
    }
    throw error;
  }
}

export async function prepare(store: QueueStore): Promise<{
  tildaUids: string[];
  writes: 0;
}> {
  const preview = claimBatch(await store.loadItems(), store.now(), BATCH_LIMIT, "preview-token");
  const tildaUids = preview.claimed.map((item) => item.tildaUid);
  await writeRun(store, {
    mode: "prepare",
    selectedUids: tildaUids,
    status: "completed",
    errorCount: 0,
    writes: 0,
    result: { claimed: false },
  });
  return { tildaUids, writes: 0 };
}

async function abandonStaleRuns(store: QueueStore): Promise<void> {
  await store.abandonRunsStartedBefore(store.now() - CLAIM_TTL_MS);
}

export async function inspect(store: QueueStore, deps: QueueDeps): Promise<{
  counts: Record<string, number>;
  selectedUids: string[];
  writes: 0;
}> {
  await abandonStaleRuns(store);
  const token = `inspect-${crypto.randomUUID()}`;
  const claimed = await store.claim(BATCH_LIMIT, token);
  return inspectItems(store, claimed, deps, "inspect", token);
}

export async function recheck(
  store: QueueStore,
  tildaUid: string,
  deps: QueueDeps,
): Promise<{ status: string; writes: 0; error?: string }> {
  await abandonStaleRuns(store);
  const token = `recheck-${crypto.randomUUID()}`;
  const claimed = await store.claimForRecheck(tildaUid, token);
  if ("error" in claimed) return { status: claimed.error, writes: 0, error: claimed.error };
  const result = await inspectItems(store, [claimed.item], deps, "recheck", token);
  const updated = (await store.loadItems()).find((row) => row.tildaUid === tildaUid);
  return { status: updated?.status ?? "missing", writes: result.writes };
}

async function inspectItems(
  store: QueueStore,
  claimed: QueueItem[],
  deps: QueueDeps,
  mode: "inspect" | "recheck",
  token: string,
): Promise<{ counts: Record<string, number>; selectedUids: string[]; writes: 0 }> {
  const selectedUids = claimed.map((item) => item.tildaUid);
  if (claimed.length === 0) {
    await writeRun(store, {
      mode,
      selectedUids,
      status: "completed",
      errorCount: 0,
      writes: 0,
      result: { empty: true },
    });
    return { counts: countStatuses(await store.loadItems()), selectedUids, writes: 0 };
  }
  const startedAt = iso(store.now());
  const run = runId();
  await store.addRun({
    id: run,
    mode,
    selectedUids,
    status: "running",
    result: {},
    errorCount: 0,
    writes: 0,
    startedAt,
    finishedAt: null,
  });
  try {
    return await inspectClaimed(store, claimed, deps, token, run);
  } catch (error) {
    await store.finishRun(run, {
      status: "failed",
      errorCount: 1,
      writes: 0,
      finishedAt: iso(store.now()),
      result: { error: error instanceof Error ? error.message : "inspect_failed" },
    });
    throw error;
  }
}

async function inspectClaimed(
  store: QueueStore,
  claimed: QueueItem[],
  deps: QueueDeps,
  token: string,
  run: string,
): Promise<{ counts: Record<string, number>; selectedUids: string[]; writes: 0 }> {
  const selectedUids = claimed.map((item) => item.tildaUid);
  const candidates = new Map((await store.loadCandidates()).map((candidate) => [candidate.tildaUid, candidate]));
  const known: Record<string, string[]> = {};
  const counts: Record<string, number> = {};
  for (const item of claimed) {
    const candidate = candidates.get(item.tildaUid);
    known[item.tildaUid] = [
      ...(candidate ? [candidate.primaryUrl, ...candidate.galleryUrls] : []),
    ];
    counts[item.tildaUid] = item.dbVariantCount;
  }
  const recovered = await recoverGalleries({
    mode: "dry_run",
    tilda_uids: selectedUids,
    known_images: known,
    variant_counts: counts,
  }, { fetch: deps.fetch, retries: 0 });
  if (!recovered.ok) {
    await store.saveOwned(claimed.map((item) => ({
      ...item,
      status: "pending",
      claimedAt: null,
      claimToken: null,
      updatedAt: iso(store.now()),
    })), token);
    await store.finishRun(run, {
      status: "failed",
      errorCount: 1,
      writes: 0,
      finishedAt: iso(store.now()),
      result: { error: recovered.error },
    });
    return { counts: countStatuses(await store.loadItems()), selectedUids, writes: 0 };
  }
  const reports = new Map(recovered.report.products.map((product) => [product.tildaUid, product]));
  const now = store.now();
  const updated = claimed.map((item) => {
    const report = reports.get(item.tildaUid);
    const primary = candidates.get(item.tildaUid)?.primaryUrl ?? "";
    if (!report) {
      return classifyInspection(item, {
        tildaUid: item.tildaUid,
        classification: "extract_failed",
        editionCount: 0,
        galleryCount: 0,
        importable: [],
        skippedAmbiguous: [],
        duplicates: [],
        invalid: [],
        inserted: 0,
        primaryCount: 0,
        detail: "report_missing",
      }, primary, now);
    }
    return classifyInspection(item, report, primary, now);
  });
  await store.saveOwned(updated, token);
  await store.finishRun(run, {
    status: "completed",
    errorCount: updated.filter((item) => item.status === "error" || item.status === "access_denied").length,
    writes: 0,
    finishedAt: iso(store.now()),
    result: {
      statuses: Object.fromEntries(updated.map((item) => [item.tildaUid, item.status])),
      expected: Object.fromEntries(updated.map((item) => [item.tildaUid, item.expectedNewImageCount])),
    },
  });
  return { counts: countStatuses(await store.loadItems()), selectedUids, writes: 0 };
}

export async function propose(store: QueueStore): Promise<{
  allowlist: string[];
  expected: Record<string, number>;
  writes: 0;
}> {
  const candidates = new Map((await store.loadCandidates()).map((candidate) => [candidate.tildaUid, candidate]));
  const items = await store.loadItems();
  const updates: QueueItem[] = [];
  const ready: QueueItem[] = [];
  for (const item of items) {
    if (item.status !== "ready_for_review" || !leaseOpen(item, store.now())) continue;
    const candidate = candidates.get(item.tildaUid);
    if (candidate && candidate.galleryImageCount > 0) {
      updates.push(completedFromGallery(candidate, item, store.now()));
      continue;
    }
    if (candidate && !isAutomaticallyEligible(candidate)) {
      updates.push({
        ...item,
        status: "ambiguous",
        errorClassification: "eligibility_changed",
        lastError: "database eligibility changed before approval",
        nextCheckAt: iso(store.now() + 30 * 24 * 60 * 60 * 1000),
        claimedAt: null,
        claimToken: null,
        updatedAt: iso(store.now()),
      });
      continue;
    }
    ready.push(item);
  }
  if (updates.length > 0) await store.saveIfLeaseOpen(updates);
  ready.sort((a, b) => compareUid(a.tildaUid, b.tildaUid));
  const batch = ready.slice(0, BATCH_LIMIT);
  const expected = Object.fromEntries(batch.map((item) => [item.tildaUid, item.expectedNewImageCount]));
  await writeRun(store, {
    mode: "propose",
    selectedUids: batch.map((item) => item.tildaUid),
    status: "completed",
    errorCount: 0,
    writes: 0,
    result: { expected },
  });
  return { allowlist: batch.map((item) => item.tildaUid), expected, writes: 0 };
}

export interface LiveRequest {
  authorizeLive: boolean;
  allowlist: string[];
  expected: Record<string, number>;
}

export async function executeLive(
  store: QueueStore,
  request: LiveRequest,
  deps: QueueDeps,
): Promise<{
  executed: boolean;
  writes: number;
  status: "completed" | "aborted" | "failed";
  error?: string;
  inserted: Record<string, number>;
}> {
  const aborted = async (error: string, uids: string[]) => {
    await writeRun(store, {
      mode: "live",
      selectedUids: uids,
      status: "aborted",
      errorCount: 1,
      writes: 0,
      result: { error },
    });
    return { executed: false, writes: 0, status: "aborted" as const, error, inserted: {} };
  };
  if (request.authorizeLive !== true) return aborted("authorize_live_required", request.allowlist);
  if (!deps.catalog) return aborted("catalog_unavailable", request.allowlist);
  const allowlist = request.allowlist;
  if (allowlist.length === 0 || allowlist.length > BATCH_LIMIT || new Set(allowlist).size !== allowlist.length) {
    return aborted("allowlist_invalid", allowlist);
  }
  const items = await store.loadItems();
  const byUid = new Map(items.map((item) => [item.tildaUid, item]));
  for (const uid of allowlist) {
    const item = byUid.get(uid);
    if (!item || item.status !== "ready_for_review") return aborted("uid_not_ready", allowlist);
    if (request.expected[uid] !== item.expectedNewImageCount) return aborted("expected_count_mismatch", allowlist);
  }

  const token = `live-${crypto.randomUUID()}`;
  const held = await store.claimLive(allowlist, token);
  if (!held) return aborted("live_claim_held", allowlist);
  const release = (rows: QueueItem[]) =>
    store.saveOwned(rows.map((item) => ({
      ...item,
      claimedAt: null,
      claimToken: null,
      updatedAt: iso(store.now()),
    })), token);

  const catalog = deps.catalog;
  const known: Record<string, string[]> = {};
  const variantCounts: Record<string, number> = {};
  for (const uid of allowlist) {
    const snapshot = await catalog.loadProduct(uid);
    if (!snapshot || snapshot === "ambiguous_product" || snapshot.variantCount !== 1) {
      await release(held);
      return aborted("database_revalidation_failed", allowlist);
    }
    known[uid] = [...snapshot.variantPhotoUrls, ...snapshot.images.map((image) => image.url)];
    variantCounts[uid] = snapshot.variantCount;
  }
  const fresh = await recoverGalleries({
    mode: "dry_run",
    tilda_uids: allowlist,
    known_images: known,
    variant_counts: variantCounts,
  }, { fetch: deps.fetch, retries: 0 });
  if (!fresh.ok) {
    await release(held);
    return aborted(fresh.error, allowlist);
  }

  const stale: QueueItem[] = [];
  const freshByUid = new Map(fresh.report.products.map((product) => [product.tildaUid, product]));
  for (const uid of allowlist) {
    const item = byUid.get(uid)!;
    const report = freshByUid.get(uid);
    const primary = known[uid][0] ?? "";
    const identities = report?.importable.map((extra) => extra.identity) ?? [];
    const fingerprint = galleryFingerprint({
      variantCount: 1,
      primaryUrl: primary,
      importableIdentities: identities,
    });
    const urlsChanged = JSON.stringify(report?.importable.map((extra) => extra.identity)) !==
      JSON.stringify(item.importableUrls.map((url) => imageIdentity(url)));
    if (
      !report ||
      report.classification !== "importable" ||
      report.editionCount !== 1 ||
      report.invalid.length > 0 ||
      report.importable.length !== item.expectedNewImageCount ||
      fingerprint !== item.contentFingerprint ||
      urlsChanged
    ) {
      stale.push({
        ...item,
        status: "error",
        errorClassification: "stale_inspection",
        lastError: "fresh inspection did not match the approved fingerprint",
        nextCheckAt: iso(store.now() + 60 * 60 * 1000),
        claimedAt: null,
        claimToken: null,
        updatedAt: iso(store.now()),
      });
    }
  }
  if (stale.length > 0) {
    const staleUids = new Set(stale.map((item) => item.tildaUid));
    await store.saveOwned(stale, token);
    await release(held.filter((item) => !staleUids.has(item.tildaUid)));
    return aborted("stale_inspection", allowlist);
  }

  const inserted: Record<string, number> = {};
  let writes = 0;
  const stop = async (uid: string, error: string, detail: string) => {
    const item = byUid.get(uid)!;
    await store.saveOwned([{
      ...item,
      status: "error",
      errorClassification: error,
      lastError: detail,
      claimedAt: null,
      claimToken: null,
      updatedAt: iso(store.now()),
    }], token);
    await release(held.filter((row) => row.tildaUid !== uid && inserted[row.tildaUid] === undefined));
    await writeRun(store, {
      mode: "live",
      selectedUids: allowlist,
      status: "failed",
      errorCount: 1,
      writes,
      result: { inserted, stoppedAt: uid },
    });
    return { executed: true, writes, status: "failed" as const, error, inserted };
  };
  for (const uid of allowlist) {
    const item = byUid.get(uid)!;
    const report = freshByUid.get(uid)!;
    const snapshot = await catalog.loadProduct(uid);
    if (!snapshot || snapshot === "ambiguous_product") {
      return stop(uid, "catalog_failed", "product disappeared before insert");
    }
    const rows = supplementalRows({
      productId: snapshot.id,
      importable: report.importable,
      existing: snapshot.images,
    });
    let productWrites = 0;
    for (const row of rows) {
      const outcome = await catalog.insertGalleryImage(row);
      if (outcome !== "inserted" && outcome !== "duplicate") {
        return stop(
          uid,
          "partial_failure",
          typeof outcome === "object" ? outcome.error : "insert_failed",
        );
      }
      if (outcome === "inserted") {
        productWrites++;
        writes++;
      }
    }
    const after = await catalog.loadProduct(uid);
    const have = new Set(
      !after || after === "ambiguous_product"
        ? []
        : after.images.filter((image) => image.source === "tilda_gallery")
          .map((image) => imageIdentity(image.url))
          .filter((identity): identity is string => !!identity),
    );
    const expectedIds = report.importable.map((extra) => extra.identity);
    if (expectedIds.some((identity) => !have.has(identity))) {
      return stop(uid, "reconcile_failed", "inserted rows were not visible on reload");
    }
    inserted[uid] = productWrites;
    const saved = await store.saveOwned([{
      ...item,
      status: "completed",
      confirmedSupplementaryCount: expectedIds.length,
      expectedNewImageCount: expectedIds.length,
      lastSuccessAt: iso(store.now()),
      errorClassification: null,
      lastError: null,
      claimedAt: null,
      claimToken: null,
      updatedAt: iso(store.now()),
    }], token);
    if (!saved.includes(uid)) {
      return stop(uid, "lost_claim", "claim was no longer owned after insert");
    }
  }
  await writeRun(store, {
    mode: "live",
    selectedUids: allowlist,
    status: "completed",
    errorCount: 0,
    writes,
    result: { inserted },
  });
  return { executed: true, writes, status: "completed", inserted };
}

export function countStatuses(items: QueueItem[]): Record<string, number> {
  const counts: Record<string, number> = {};
  for (const item of items) counts[item.status] = (counts[item.status] ?? 0) + 1;
  return counts;
}
