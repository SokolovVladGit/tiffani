import type { GalleryCatalog } from "./catalog.ts";
import { extractStoreProduct } from "./extract.ts";
import { fetchStorePage } from "./fetch-page.ts";
import type { PlannedExtra } from "./plan.ts";
import { planProductGallery } from "./plan.ts";
import { supplementalRows } from "./rows.ts";
import { confirmImageUrl } from "./validate-url.ts";

const MAX_UIDS = 20;
/** One page at a time. A 403 on one UID cannot fan out into parallel retries. */
const CONCURRENCY = 1;
const UID_RE = /^\d{6,20}$/;

export interface ProductReport {
  tildaUid: string;
  classification: string;
  editionCount: number;
  galleryCount: number;
  importable: PlannedExtra[];
  skippedAmbiguous: PlannedExtra[];
  duplicates: string[];
  invalid: { url: string; reason: string }[];
  /** Rows actually inserted. Dry-run and inspect leave this at 0. */
  inserted: number;
  /** Existing variant-primary images observed before any insert. */
  primaryCount: number;
  detail?: string;
}

export interface RecoverReport {
  mode: "inspect" | "dry_run" | "live";
  writes: number;
  requestedUids: string[];
  products: ProductReport[];
}

export type RecoverResult =
  | { ok: true; report: RecoverReport }
  | { ok: false; status: number; error: string };

function stringList(value: unknown): string[] | null {
  if (value == null) return [];
  if (!Array.isArray(value)) return null;
  const out: string[] = [];
  for (const item of value) {
    if (typeof item !== "string") return null;
    out.push(item);
  }
  return out;
}

export async function recoverGalleries(
  body: unknown,
  deps: {
    fetch: typeof fetch;
    timeoutMs?: number;
    retries?: number;
    catalog?: GalleryCatalog;
  },
): Promise<RecoverResult> {
  if (!body || typeof body !== "object" || Array.isArray(body)) {
    return { ok: false, status: 400, error: "body_must_be_object" };
  }
  const record = body as Record<string, unknown>;
  if (record.mode !== "inspect" && record.mode !== "dry_run" && record.mode !== "live") {
    return { ok: false, status: 400, error: "mode_must_be_inspect_dry_run_or_live" };
  }
  const mode = record.mode;
  if (!Array.isArray(record.tilda_uids) || record.tilda_uids.length === 0) {
    return { ok: false, status: 400, error: "tilda_uids_required" };
  }
  if (record.tilda_uids.length > MAX_UIDS) {
    return { ok: false, status: 400, error: "tilda_uids_over_limit" };
  }
  const uids: string[] = [];
  for (const uid of record.tilda_uids) {
    if (typeof uid !== "string" || !UID_RE.test(uid)) {
      return { ok: false, status: 400, error: "invalid_tilda_uid" };
    }
    uids.push(uid);
  }
  if (new Set(uids).size !== uids.length) {
    return { ok: false, status: 400, error: "duplicate_tilda_uid" };
  }
  if (mode === "live") {
    if (!deps.catalog) {
      return { ok: false, status: 500, error: "catalog_unavailable" };
    }
    const allowlist = stringList(record.allowlist);
    if (!allowlist || allowlist.length === 0) {
      return { ok: false, status: 400, error: "allowlist_required" };
    }
    if (allowlist.length > MAX_UIDS) {
      return { ok: false, status: 400, error: "allowlist_over_limit" };
    }
    for (const uid of allowlist) {
      if (!UID_RE.test(uid)) {
        return { ok: false, status: 400, error: "invalid_tilda_uid" };
      }
    }
    if (new Set(allowlist).size !== allowlist.length) {
      return { ok: false, status: 400, error: "duplicate_tilda_uid" };
    }
    const allowed = new Set(allowlist);
    if (uids.some((uid) => !allowed.has(uid))) {
      return { ok: false, status: 400, error: "uid_not_in_allowlist" };
    }
    const products: ProductReport[] = [];
    let writes = 0;
    for (const uid of uids) {
      void CONCURRENCY;
      const report = await liveUid(uid, deps.catalog, deps);
      products.push(report);
      writes += report.inserted;
    }
    return {
      ok: true,
      report: { mode: "live", writes, requestedUids: uids, products },
    };
  }

  const knownImages = record.known_images;
  const variantCounts = record.variant_counts;
  if (knownImages != null && (typeof knownImages !== "object" || Array.isArray(knownImages))) {
    return { ok: false, status: 400, error: "known_images_must_be_object" };
  }
  if (variantCounts != null && (typeof variantCounts !== "object" || Array.isArray(variantCounts))) {
    return { ok: false, status: 400, error: "variant_counts_must_be_object" };
  }

  const products: ProductReport[] = [];
  for (const uid of uids) {
    const known = stringList(
      (knownImages as Record<string, unknown> | undefined)?.[uid],
    );
    if (!known) {
      return { ok: false, status: 400, error: "known_images_must_be_string_arrays" };
    }
    const declaredRaw = (variantCounts as Record<string, unknown> | undefined)?.[uid];
    if (declaredRaw != null && (typeof declaredRaw !== "number" || !Number.isInteger(declaredRaw) || declaredRaw < 0)) {
      return { ok: false, status: 400, error: "variant_counts_must_be_integers" };
    }
    products.push(await inspectUid(uid, mode, known, declaredRaw as number | undefined, deps));
  }

  return {
    ok: true,
    report: { mode, writes: 0, requestedUids: uids, products },
  };
}

async function inspectUid(
  tildaUid: string,
  mode: "inspect" | "dry_run",
  knownImageUrls: string[],
  variantCount: number | undefined,
  deps: { fetch: typeof fetch; timeoutMs?: number; retries?: number },
): Promise<ProductReport> {
  const page = await fetchStorePage(tildaUid, deps);
  if (!page.ok) {
    return {
      tildaUid,
      classification: page.classification,
      editionCount: 0,
      galleryCount: 0,
      importable: [],
      skippedAmbiguous: [],
      duplicates: [],
      invalid: [],
      inserted: 0,
      primaryCount: 0,
      detail: page.detail,
    };
  }
  const extracted = extractStoreProduct(page.html);
  if (!extracted.ok) {
    return {
      tildaUid,
      classification: "extract_failed",
      editionCount: 0,
      galleryCount: 0,
      importable: [],
      skippedAmbiguous: [],
      duplicates: [],
      invalid: [],
      inserted: 0,
      primaryCount: 0,
      detail: extracted.reason,
    };
  }
  const plan = planProductGallery({
    tildaUid,
    product: extracted.product,
    knownImageUrls,
    variantCount,
  });
  const report: ProductReport = {
    tildaUid,
    classification: plan.classification,
    editionCount: plan.editionCount,
    galleryCount: plan.galleryCount,
    importable: [],
    skippedAmbiguous: plan.skippedAmbiguous,
    duplicates: plan.duplicates,
    invalid: [...plan.invalid],
    inserted: 0,
    primaryCount: 0,
    detail: plan.detail,
  };
  if (mode === "inspect" || !plan.singleVariant || plan.extras.length === 0) {
    return report;
  }
  const importable: PlannedExtra[] = [];
  for (const extra of plan.extras) {
    const confirmed = await confirmImageUrl(extra.url, deps);
    if (!confirmed.ok) {
      report.invalid.push({ url: extra.url, reason: confirmed.reason });
      continue;
    }
    importable.push({ url: confirmed.url, identity: extra.identity });
  }
  report.importable = importable;
  if (importable.length === 0) report.classification = "validation_failed";
  return report;
}

function emptyProduct(tildaUid: string, classification: string, detail?: string): ProductReport {
  return {
    tildaUid,
    classification,
    editionCount: 0,
    galleryCount: 0,
    importable: [],
    skippedAmbiguous: [],
    duplicates: [],
    invalid: [],
    inserted: 0,
    primaryCount: 0,
    detail,
  };
}

async function liveUid(
  tildaUid: string,
  catalog: GalleryCatalog,
  deps: { fetch: typeof fetch; timeoutMs?: number; retries?: number },
): Promise<ProductReport> {
  let snapshot;
  try {
    snapshot = await catalog.loadProduct(tildaUid);
  } catch (error) {
    return emptyProduct(
      tildaUid,
      "catalog_failed",
      error instanceof Error ? error.message : "catalog_failed",
    );
  }
  if (snapshot === "ambiguous_product") {
    return emptyProduct(tildaUid, "ambiguous_product", "tilda_uid matched more than one product");
  }
  if (!snapshot) return emptyProduct(tildaUid, "missing_product");
  if (snapshot.variantCount !== 1) {
    return {
      ...emptyProduct(
        tildaUid,
        "ambiguous_variant_gallery",
        `variants ${snapshot.variantCount}`,
      ),
      editionCount: snapshot.variantCount,
      primaryCount: snapshot.variantPhotoUrls.length,
    };
  }

  const page = await fetchStorePage(tildaUid, deps);
  if (!page.ok) {
    return {
      ...emptyProduct(tildaUid, page.classification, page.detail),
      primaryCount: snapshot.variantPhotoUrls.length,
    };
  }
  const extracted = extractStoreProduct(page.html);
  if (!extracted.ok) {
    return {
      ...emptyProduct(tildaUid, "extract_failed", extracted.reason),
      primaryCount: snapshot.variantPhotoUrls.length,
    };
  }

  const known = [
    ...snapshot.variantPhotoUrls,
    ...snapshot.images.map((image) => image.url),
  ];
  const plan = planProductGallery({
    tildaUid,
    product: extracted.product,
    knownImageUrls: known,
    variantCount: snapshot.variantCount,
  });
  const report: ProductReport = {
    tildaUid,
    classification: plan.classification === "ambiguous"
      ? "ambiguous_variant_gallery"
      : plan.classification,
    editionCount: plan.editionCount,
    galleryCount: plan.galleryCount,
    importable: [],
    skippedAmbiguous: plan.skippedAmbiguous,
    duplicates: plan.duplicates,
    invalid: [...plan.invalid],
    inserted: 0,
    primaryCount: snapshot.variantPhotoUrls.length,
    detail: plan.detail,
  };
  if (!plan.singleVariant || plan.extras.length === 0) return report;

  const importable: PlannedExtra[] = [];
  for (const extra of plan.extras) {
    const confirmed = await confirmImageUrl(extra.url, deps);
    if (!confirmed.ok) {
      report.invalid.push({ url: extra.url, reason: confirmed.reason });
      continue;
    }
    importable.push({ url: confirmed.url, identity: extra.identity });
  }
  report.importable = importable;
  if (importable.length === 0) {
    report.classification = "validation_failed";
    return report;
  }

  const rows = supplementalRows({
    productId: snapshot.id,
    importable,
    existing: snapshot.images,
  });
  for (const row of rows) {
    let outcome;
    try {
      outcome = await catalog.insertGalleryImage(row);
    } catch (error) {
      report.classification = "partial_failure";
      report.detail = error instanceof Error ? error.message : "insert_failed";
      return report;
    }
    if (outcome === "inserted") {
      report.inserted++;
      continue;
    }
    if (outcome === "duplicate") {
      report.duplicates.push(row.url);
      continue;
    }
    report.classification = "partial_failure";
    report.detail = outcome.error;
    return report;
  }
  report.classification = report.inserted > 0 ? "inserted" : "no_extras";
  return report;
}
