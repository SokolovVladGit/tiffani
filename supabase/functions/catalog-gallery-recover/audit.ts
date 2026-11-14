import type { ProductReport, RecoverReport } from "./recover.ts";

const FAILURES = new Set([
  "access_denied",
  "extract_failed",
  "validation_failed",
  "missing_product",
  "ambiguous_product",
  "partial_failure",
  "uid_mismatch",
  "inconsistent_variant_count",
  "catalog_failed",
]);

/** Dry-run and inspect always report zero writes. Live reports inserted rows. */
export function auditGalleryReport(report: RecoverReport) {
  const count = (classification: string) =>
    report.products.filter((product) => product.classification === classification).length;
  const sum = (pick: (product: ProductReport) => number) =>
    report.products.reduce((total, product) => total + pick(product), 0);
  const imagesInserted = report.mode === "live"
    ? sum((product) => product.inserted)
    : 0;

  return {
    mode: report.mode,
    requestedUids: report.requestedUids,
    processed: report.products.length,
    sourceImagesFound: sum((product) => product.galleryCount),
    existingPrimaryImages: sum((product) => product.primaryCount),
    confirmedSupplementary: sum((product) => product.importable.length),
    imagesInserted,
    skippedDuplicates: sum((product) => product.duplicates.length),
    skippedAmbiguous: sum((product) => product.skippedAmbiguous.length),
    access_denied: count("access_denied"),
    errors: report.products.filter((product) => FAILURES.has(product.classification)).length,
    writes: imagesInserted,
    isolatedFromCatalogSync: true as const,
    attempted: report.products.length,
    importableProducts: count("importable"),
    preparedImages: sum((product) => product.importable.length),
    ambiguousProducts: count("ambiguous") + count("ambiguous_variant_gallery"),
    accessDenied: count("access_denied"),
    extractFailed: count("extract_failed"),
    validationFailed: count("validation_failed"),
    noExtras: count("no_extras"),
  };
}
