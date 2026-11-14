import { imageIdentity } from "./image-identity.ts";
import type { PlannedExtra } from "./plan.ts";

export interface ExistingImage {
  url: string;
  position: number;
}

export interface GalleryInsertRow {
  product_id: string;
  url: string;
  position: number;
  source: "tilda_gallery";
}

/** Rows a later approved import could insert. Does not write. */
export function supplementalRows(input: {
  productId: string;
  importable: PlannedExtra[];
  existing: ExistingImage[];
}): GalleryInsertRow[] {
  const seen = new Set<string>();
  for (const row of input.existing) {
    const identity = imageIdentity(row.url);
    if (identity) seen.add(identity);
  }
  let position = input.existing.reduce(
    (max, row) => Math.max(max, row.position),
    -1,
  ) + 1;
  const out: GalleryInsertRow[] = [];
  for (const extra of input.importable) {
    if (seen.has(extra.identity)) continue;
    seen.add(extra.identity);
    out.push({
      product_id: input.productId,
      url: extra.url,
      position,
      source: "tilda_gallery",
    });
    position++;
  }
  return out;
}
