import type { TildaCatalog } from "../catalog-sync/types.ts";

export interface YmlMetrics {
  size_bytes: number;
  categories_count: number;
  groups_count: number;
  offers_count: number;
  offers_with_picture: number;
  images_in_yml: number;
}

/**
 * Summary metrics over a parsed YML catalog (same shape as safe sync).
 */
export function computeYmlMetrics(
  catalog: TildaCatalog,
  sizeBytes: number,
): YmlMetrics {
  const groups = new Set<string>();
  let offersWithPicture = 0;
  let imagesInYml = 0;

  for (const offer of catalog.offers) {
    groups.add(offer.groupId ?? offer.id);
    const pics = offer.pictures && offer.pictures.length > 0
      ? offer.pictures
      : (offer.picture ? [offer.picture] : []);
    if (pics.length > 0) offersWithPicture++;
    imagesInYml += pics.length;
  }

  return {
    size_bytes: sizeBytes,
    categories_count: catalog.categories.length,
    groups_count: groups.size,
    offers_count: catalog.offers.length,
    offers_with_picture: offersWithPicture,
    images_in_yml: imagesInYml,
  };
}

/**
 * Fast reject for obviously wrong uploads before full XML parse.
 */
export function looksLikeYmlText(text: string): boolean {
  const trimmed = text.trim();
  if (trimmed.length === 0) return false;
  if (!trimmed.startsWith("<")) return false;
  const head = trimmed.slice(0, 4000).toLowerCase();
  return head.includes("yml_catalog") || head.includes("<shop") ||
    head.includes("<offer");
}
