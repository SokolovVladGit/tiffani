import type { TildaCatalog, TildaOffer } from "../catalog-sync/types.ts";

/**
 * In-memory index over a parsed Tilda YML catalog.
 *
 * Enables O(1) lookup of a UID against both the offer-id axis
 * (variant/SKU) and the group-id axis (product).
 */
export interface YmlIndex {
  byOfferId: Map<string, TildaOffer>;
  byGroupId: Map<string, TildaOffer[]>;
  offersCount: number;
  groupsCount: number;
  categoriesCount: number;
}

export function buildYmlIndex(catalog: TildaCatalog): YmlIndex {
  const byOfferId = new Map<string, TildaOffer>();
  const byGroupId = new Map<string, TildaOffer[]>();

  for (const offer of catalog.offers) {
    if (offer.id) byOfferId.set(offer.id, offer);

    const gid = offer.groupId;
    if (gid) {
      const arr = byGroupId.get(gid);
      if (arr) arr.push(offer);
      else byGroupId.set(gid, [offer]);
    }
  }

  return {
    byOfferId,
    byGroupId,
    offersCount: catalog.offers.length,
    groupsCount: byGroupId.size,
    categoriesCount: catalog.categories.length,
  };
}

export interface UidLookupResult {
  offer?: TildaOffer;
  groupOffers?: TildaOffer[];
}

/**
 * Resolves a UID against the YML index.
 *
 * Offer-id match takes priority over group-id match when a UID happens
 * to satisfy both (rare edge case for single-variant products where
 * `@_id` equals `@_group_id`).
 */
export function lookupUid(index: YmlIndex, uid: string): UidLookupResult {
  return {
    offer: index.byOfferId.get(uid),
    groupOffers: index.byGroupId.get(uid),
  };
}
