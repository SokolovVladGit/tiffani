import type { StoreProduct } from "./extract.ts";
import { imageIdentity, isAllowedImageUrl } from "./image-identity.ts";

/**
 * `gallery[]` entries on tiffani.md are `{ img }` only. They are not
 * linked to an edition. Multi-variant extras therefore have no reliable
 * variant or whole-product association and are skipped.
 *
 * A later import of those extras would need
 * `product_images.variant_id uuid NULL REFERENCES product_variants(id)`.
 * That column is not added: the page does not provide the relationship.
 */
export type GalleryClassification =
  | "importable"
  | "no_extras"
  | "ambiguous"
  | "inconsistent_variant_count"
  | "unknown_variant_count"
  | "uid_mismatch"
  | "validation_failed";

export interface PlannedExtra {
  url: string;
  identity: string;
}

export interface GalleryPlan {
  tildaUid: string;
  classification: GalleryClassification;
  editionCount: number;
  galleryCount: number;
  singleVariant: boolean;
  extras: PlannedExtra[];
  skippedAmbiguous: PlannedExtra[];
  duplicates: string[];
  invalid: { url: string; reason: string }[];
  /** Filled only after a candidate URL probe succeeds. */
  importable: PlannedExtra[];
  detail?: string;
}

export function planProductGallery(input: {
  tildaUid: string;
  product: StoreProduct;
  knownImageUrls: string[];
  variantCount?: number;
}): GalleryPlan {
  const editionCount = input.product.editions.length;
  const known = new Set<string>();
  for (const url of input.knownImageUrls) {
    const identity = imageIdentity(url);
    if (identity) known.add(identity);
  }
  for (const edition of input.product.editions) {
    if (!edition.img) continue;
    const identity = imageIdentity(edition.img);
    if (identity) known.add(identity);
  }

  const duplicates: string[] = [];
  const invalid: { url: string; reason: string }[] = [];
  const extras: PlannedExtra[] = [];
  const seen = new Set<string>(known);

  for (const url of input.product.gallery) {
    if (!isAllowedImageUrl(url)) {
      invalid.push({ url, reason: "host_or_extension_rejected" });
      continue;
    }
    const identity = imageIdentity(url);
    if (!identity) {
      invalid.push({ url, reason: "unparseable_url" });
      continue;
    }
    if (seen.has(identity)) {
      duplicates.push(url);
      continue;
    }
    seen.add(identity);
    extras.push({ url, identity });
  }

  const base = {
    tildaUid: input.tildaUid,
    editionCount,
    galleryCount: input.product.gallery.length,
    extras,
    duplicates,
    invalid,
    importable: [] as PlannedExtra[],
  };

  if (input.product.uid && input.product.uid !== input.tildaUid) {
    return {
      ...base,
      classification: "uid_mismatch",
      singleVariant: false,
      skippedAmbiguous: extras,
      detail: `page uid ${input.product.uid}`,
    };
  }

  const declared = input.variantCount;
  if (
    declared != null &&
    editionCount > 0 &&
    declared !== editionCount
  ) {
    return {
      ...base,
      classification: "inconsistent_variant_count",
      singleVariant: false,
      skippedAmbiguous: extras,
      detail: `page editions ${editionCount}, caller variants ${declared}`,
    };
  }

  const single = editionCount === 1 || (editionCount === 0 && declared === 1);
  const multi = editionCount > 1 || (declared != null && declared > 1);
  if (!single && !multi) {
    return {
      ...base,
      classification: "unknown_variant_count",
      singleVariant: false,
      skippedAmbiguous: extras,
    };
  }
  if (multi) {
    return {
      ...base,
      classification: extras.length > 0 ? "ambiguous" : "no_extras",
      singleVariant: false,
      skippedAmbiguous: extras,
    };
  }
  return {
    ...base,
    classification: extras.length > 0 ? "importable" : "no_extras",
    singleVariant: true,
    skippedAmbiguous: [],
  };
}
