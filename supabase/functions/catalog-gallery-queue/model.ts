import { imageIdentity } from "../catalog-gallery-recover/image-identity.ts";
import type { ProductReport } from "../catalog-gallery-recover/recover.ts";
import {
  HISTORICAL_AMBIGUOUS,
  HISTORICAL_AMBIGUOUS_DETAIL,
  HISTORICAL_NO_EXTRA,
} from "./historical.ts";

export const BATCH_LIMIT = 20;
export const CLAIM_TTL_MS = 15 * 60 * 1000;
export const UID_RE = /^\d{6,20}$/;

const HOUR_MS = 60 * 60 * 1000;
const DAY_MS = 24 * HOUR_MS;

export type QueueStatus =
  | "pending"
  | "no_extra"
  | "ready_for_review"
  | "ambiguous"
  | "access_denied"
  | "error"
  | "completed";

export interface CatalogCandidate {
  productId: string;
  tildaUid: string;
  variantCount: number;
  ymlImageCount: number;
  galleryImageCount: number;
  galleryUrls: string[];
  primaryUrl: string;
  primaryMatches: boolean;
  hidden: boolean;
}

export interface QueueItem {
  productId: string;
  tildaUid: string;
  status: QueueStatus;
  dbVariantCount: number;
  websiteEditionCount: number | null;
  websiteImageCount: number | null;
  existingPrimaryCount: number;
  confirmedSupplementaryCount: number;
  expectedNewImageCount: number;
  importableUrls: string[];
  contentFingerprint: string | null;
  lastCheckedAt: string | null;
  nextCheckAt: string | null;
  lastSuccessAt: string | null;
  errorClassification: string | null;
  retryCount: number;
  lastError: string | null;
  claimedAt: string | null;
  claimToken: string | null;
  updatedAt: string;
}

export interface QueueRun {
  id: string;
  mode: "bootstrap" | "prepare" | "inspect" | "propose" | "recheck" | "live";
  selectedUids: string[];
  status: "running" | "completed" | "aborted" | "failed" | "abandoned";
  result: Record<string, unknown>;
  errorCount: number;
  writes: number;
  startedAt: string;
  finishedAt: string | null;
}

export function iso(ms: number): string {
  return new Date(ms).toISOString();
}

export function compareUid(a: string, b: string): number {
  const left = BigInt(a);
  const right = BigInt(b);
  if (left < right) return -1;
  if (left > right) return 1;
  if (a < b) return -1;
  if (a > b) return 1;
  return 0;
}

export function isAutomaticallyEligible(candidate: CatalogCandidate): boolean {
  return UID_RE.test(candidate.tildaUid) &&
    candidate.variantCount === 1 &&
    candidate.ymlImageCount === 1 &&
    candidate.galleryImageCount === 0 &&
    candidate.primaryMatches &&
    imageIdentity(candidate.primaryUrl) !== null;
}

export function galleryFingerprint(input: {
  variantCount: number;
  primaryUrl: string;
  importableIdentities: string[];
}): string {
  const primary = imageIdentity(input.primaryUrl) ?? "";
  return `${input.variantCount}|${primary}|${input.importableIdentities.join(",")}`;
}

function blank(candidate: CatalogCandidate, now: number, status: QueueStatus): QueueItem {
  return {
    productId: candidate.productId,
    tildaUid: candidate.tildaUid,
    status,
    dbVariantCount: candidate.variantCount,
    websiteEditionCount: null,
    websiteImageCount: null,
    existingPrimaryCount: candidate.ymlImageCount === 1 ? 1 : 0,
    confirmedSupplementaryCount: 0,
    expectedNewImageCount: 0,
    importableUrls: [],
    contentFingerprint: null,
    lastCheckedAt: null,
    nextCheckAt: null,
    lastSuccessAt: null,
    errorClassification: null,
    retryCount: 0,
    lastError: null,
    claimedAt: null,
    claimToken: null,
    updatedAt: iso(now),
  };
}

function defer(item: QueueItem, now: number, detail: string): QueueItem {
  const days = item.status === "no_extra" ? 7 : 30;
  return {
    ...item,
    lastCheckedAt: iso(now),
    nextCheckAt: iso(now + days * DAY_MS),
    lastError: detail,
    errorClassification: item.status === "ambiguous" ? "historical_observation" : null,
    updatedAt: iso(now),
  };
}

export function completedFromGallery(
  candidate: CatalogCandidate,
  current: QueueItem | undefined,
  now: number,
): QueueItem {
  const base = current ?? blank(candidate, now, "completed");
  return {
    ...base,
    productId: candidate.productId,
    tildaUid: candidate.tildaUid,
    status: "completed",
    dbVariantCount: candidate.variantCount,
    existingPrimaryCount: candidate.ymlImageCount,
    confirmedSupplementaryCount: candidate.galleryImageCount,
    expectedNewImageCount: candidate.galleryImageCount,
    lastSuccessAt: current?.lastSuccessAt ?? iso(now),
    claimedAt: null,
    claimToken: null,
    nextCheckAt: null,
    errorClassification: null,
    lastError: null,
    updatedAt: current?.status === "completed" &&
        current.expectedNewImageCount === candidate.galleryImageCount
      ? current.updatedAt
      : iso(now),
  };
}

export interface BootstrapResult {
  items: QueueItem[];
  skippedHistorical: string[];
}

/** Queue rows to persist. Existing completed and deferred rows are kept. */
export function bootstrapItems(
  candidates: CatalogCandidate[],
  existing: QueueItem[],
  now: number,
): BootstrapResult {
  const byId = new Map(existing.map((item) => [item.productId, item]));
  const byUid = new Map<string, CatalogCandidate>();
  for (const candidate of candidates) {
    if (!byUid.has(candidate.tildaUid)) byUid.set(candidate.tildaUid, candidate);
  }
  const skippedHistorical: string[] = [];

  const remember = (uid: string, status: "no_extra" | "ambiguous", detail: string) => {
    const candidate = byUid.get(uid);
    if (!candidate) {
      skippedHistorical.push(uid);
      return;
    }
    if (byId.has(candidate.productId) || candidate.galleryImageCount > 0) return;
    const resolved = candidate.variantCount === 1 ? status : "ambiguous";
    byId.set(
      candidate.productId,
      defer(blank(candidate, now, resolved), now, detail),
    );
  };

  for (const uid of HISTORICAL_NO_EXTRA) {
    remember(uid, "no_extra", "historical_observation");
  }
  for (const uid of HISTORICAL_AMBIGUOUS) {
    remember(uid, "ambiguous", HISTORICAL_AMBIGUOUS_DETAIL);
  }

  const discovered = candidates
    .filter((candidate) => isAutomaticallyEligible(candidate) && !byId.has(candidate.productId))
    .sort((a, b) => compareUid(a.tildaUid, b.tildaUid));
  for (const candidate of discovered) {
    byId.set(candidate.productId, blank(candidate, now, "pending"));
  }

  for (const candidate of candidates) {
    if (candidate.galleryImageCount <= 0) continue;
    const current = byId.get(candidate.productId);
    if (
      current?.status === "completed" &&
      current.expectedNewImageCount === candidate.galleryImageCount &&
      current.tildaUid === candidate.tildaUid
    ) {
      continue;
    }
    byId.set(candidate.productId, completedFromGallery(candidate, current, now));
  }

  return { items: [...byId.values()], skippedHistorical };
}

const HISTORICAL_UIDS = new Set<string>([...HISTORICAL_NO_EXTRA, ...HISTORICAL_AMBIGUOUS]);

/** Rejects a bootstrap that would drop, duplicate, or mis-count rows. */
export function assertBootstrapCoverage(
  candidates: CatalogCandidate[],
  existing: QueueItem[],
  built: BootstrapResult,
): void {
  const candidateIds = new Set<string>();
  const candidateUids = new Set<string>();
  for (const candidate of candidates) {
    if (!candidate.productId || !candidate.tildaUid) throw new Error("missing_identifier");
    if (candidateIds.has(candidate.productId)) throw new Error("duplicate_product_id");
    if (candidateUids.has(candidate.tildaUid)) throw new Error("duplicate_tilda_uid");
    candidateIds.add(candidate.productId);
    candidateUids.add(candidate.tildaUid);
  }
  const builtById = new Map<string, QueueItem>();
  const builtUids = new Set<string>();
  for (const item of built.items) {
    if (builtById.has(item.productId)) throw new Error("duplicate_product_id");
    if (builtUids.has(item.tildaUid)) throw new Error("duplicate_tilda_uid");
    builtById.set(item.productId, item);
    builtUids.add(item.tildaUid);
  }
  const existingIds = new Set(existing.map((item) => item.productId));
  for (const item of existing) {
    const next = builtById.get(item.productId);
    if (!next) throw new Error("existing_row_dropped");
    if (next.status === item.status && next.nextCheckAt === item.nextCheckAt) continue;
    const candidate = candidates.find((row) => row.productId === item.productId);
    const galleryRefresh = candidate !== undefined &&
      candidate.galleryImageCount > 0 &&
      !(item.status === "completed" && item.expectedNewImageCount === candidate.galleryImageCount);
    if (!galleryRefresh) throw new Error("existing_row_rewritten");
  }
  let expected = 0;
  for (const candidate of candidates) {
    const wanted = candidate.galleryImageCount > 0 ||
      isAutomaticallyEligible(candidate) ||
      HISTORICAL_UIDS.has(candidate.tildaUid);
    if (wanted || existingIds.has(candidate.productId)) expected++;
  }
  for (const item of existing) {
    if (!candidateIds.has(item.productId)) expected++;
  }
  if (built.items.length !== expected) throw new Error("bootstrap_count_mismatch");
}

function due(item: QueueItem, now: number): boolean {
  return item.nextCheckAt === null || Date.parse(item.nextCheckAt) <= now;
}

export function leaseOpen(item: { claimedAt: string | null }, now: number): boolean {
  if (!item.claimedAt) return true;
  return now - Date.parse(item.claimedAt) >= CLAIM_TTL_MS;
}

export function claimBatch(
  items: QueueItem[],
  now: number,
  limit: number,
  token: string,
): { items: QueueItem[]; claimed: QueueItem[] } {
  const size = Math.min(Math.max(limit, 0), BATCH_LIMIT);
  if (size === 0 || token.length < 8) return { items, claimed: [] };
  const promoted = items.map((item) => {
    const deferred = item.status === "no_extra" ||
      item.status === "ambiguous" ||
      item.status === "access_denied" ||
      item.status === "error";
    if (!deferred || !item.nextCheckAt || Date.parse(item.nextCheckAt) > now) return item;
    return {
      ...item,
      status: "pending" as const,
      claimedAt: null,
      claimToken: null,
      updatedAt: iso(now),
    };
  });
  const picked = promoted
    .filter((item) => item.status === "pending" && due(item, now) && leaseOpen(item, now))
    .sort((a, b) => compareUid(a.tildaUid, b.tildaUid))
    .slice(0, size);
  const ids = new Set(picked.map((item) => item.productId));
  const next = promoted.map((item) =>
    ids.has(item.productId)
      ? { ...item, claimedAt: iso(now), claimToken: token, updatedAt: iso(now) }
      : item
  );
  return { items: next, claimed: next.filter((item) => ids.has(item.productId)) };
}

const AMBIGUOUS = new Set([
  "inconsistent_variant_count",
  "ambiguous",
  "ambiguous_variant_gallery",
  "ambiguous_product",
  "unknown_variant_count",
  "uid_mismatch",
]);

function cleared(item: QueueItem, report: ProductReport, now: number): QueueItem {
  return {
    ...item,
    claimedAt: null,
    claimToken: null,
    lastCheckedAt: iso(now),
    updatedAt: iso(now),
    websiteEditionCount: report.editionCount,
    websiteImageCount: report.galleryCount,
    existingPrimaryCount: Math.max(item.existingPrimaryCount, report.duplicates.length > 0 ? 1 : 0),
  };
}

/** Maps one dry-run product report onto the next queue status. */
export function classifyInspection(
  item: QueueItem,
  report: ProductReport,
  primaryUrl: string,
  now: number,
): QueueItem {
  const base = cleared(item, report, now);
  const primary = imageIdentity(primaryUrl);
  const primaryRecognized = !!primary &&
    report.duplicates.some((url) => imageIdentity(url) === primary);
  const importableIds = report.importable.map((extra) => extra.identity);
  const primaryImported = !!primary && importableIds.includes(primary);

  if (report.classification === "access_denied") {
    const retryCount = item.retryCount + 1;
    return {
      ...base,
      status: "access_denied",
      retryCount,
      errorClassification: "access_denied",
      lastError: report.detail ?? "HTTP 403",
      nextCheckAt: iso(now + (retryCount >= 3 ? 7 * DAY_MS : 6 * HOUR_MS)),
      expectedNewImageCount: 0,
      confirmedSupplementaryCount: 0,
      importableUrls: [],
      contentFingerprint: null,
    };
  }

  if (report.editionCount > 1 || AMBIGUOUS.has(report.classification) || item.dbVariantCount !== 1) {
    return {
      ...base,
      status: "ambiguous",
      errorClassification: report.classification,
      lastError: report.detail ?? report.classification,
      nextCheckAt: iso(now + 30 * DAY_MS),
      expectedNewImageCount: 0,
      confirmedSupplementaryCount: 0,
      importableUrls: [],
      contentFingerprint: null,
    };
  }

  const dedupFailed = report.classification === "importable" &&
    (!primaryRecognized || primaryImported || report.importable.length === report.galleryCount);
  if (
    !dedupFailed &&
    report.classification === "importable" &&
    report.editionCount === 1 &&
    report.importable.length > 0 &&
    report.invalid.length === 0 &&
    report.skippedAmbiguous.length === 0 &&
    report.importable.length < report.galleryCount
  ) {
    return {
      ...base,
      status: "ready_for_review",
      errorClassification: null,
      lastError: null,
      retryCount: 0,
      nextCheckAt: null,
      expectedNewImageCount: report.importable.length,
      confirmedSupplementaryCount: report.importable.length,
      importableUrls: report.importable.map((extra) => extra.url),
      contentFingerprint: galleryFingerprint({
        variantCount: 1,
        primaryUrl,
        importableIdentities: importableIds,
      }),
    };
  }

  if (
    report.classification === "no_extras" &&
    report.editionCount === 1 &&
    report.galleryCount === 1 &&
    primaryRecognized &&
    report.invalid.length === 0
  ) {
    return {
      ...base,
      status: "no_extra",
      errorClassification: null,
      lastError: null,
      retryCount: 0,
      nextCheckAt: iso(now + 7 * DAY_MS),
      expectedNewImageCount: 0,
      confirmedSupplementaryCount: 0,
      importableUrls: [],
      contentFingerprint: galleryFingerprint({
        variantCount: 1,
        primaryUrl,
        importableIdentities: [],
      }),
    };
  }

  const retryCount = item.retryCount + 1;
  return {
    ...base,
    status: "error",
    retryCount,
    errorClassification: report.invalid.length > 0
      ? "invalid_url"
      : report.galleryCount === 0
      ? "zero_gallery"
      : dedupFailed
      ? "dedup_failed"
      : report.classification,
    lastError: report.detail ?? report.classification,
    nextCheckAt: iso(now + (retryCount >= 5 ? DAY_MS : HOUR_MS)),
    expectedNewImageCount: 0,
    confirmedSupplementaryCount: 0,
    importableUrls: [],
    contentFingerprint: null,
  };
}
