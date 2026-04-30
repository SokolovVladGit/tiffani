export interface TildaCategory {
  id: string;
  name: string;
  parentId?: string;
}

export interface TildaParam {
  name: string;
  value: string;
}

export interface TildaOffer {
  id: string;
  groupId?: string;
  available: boolean;
  url?: string;
  price?: number;
  oldPrice?: number;
  currencyId?: string;
  categoryId?: string;
  /**
   * Convenience accessor for the first picture URL, preserved for
   * backward compatibility with code that only reads a single image
   * (e.g. `products.photo`, `product_variants.photo`). Equals
   * `pictures[0]` when `pictures` is non-empty, otherwise undefined.
   */
  picture?: string;
  /**
   * Full ordered list of `<picture>` URLs for the offer, deduplicated
   * while preserving source order. Always defined; may be empty when
   * the offer carries no pictures. Optional in the type to keep
   * hand-constructed test fixtures backward compatible.
   */
  pictures?: string[];
  name?: string;
  vendor?: string;
  description?: string;
  count?: number;
  params: TildaParam[];
}

export interface TildaCatalog {
  categories: TildaCategory[];
  offers: TildaOffer[];
}

/**
 * Row written to `products` base table.
 *
 * `mark` is intentionally excluded — manually curated ('NEW', 'ХИТ').
 * Omitting it means INSERT gets DB default (NULL), UPDATE leaves it untouched.
 */
export interface ProductRow {
  tilda_uid: string;
  title: string;
  brand: string | null;
  category: string | null;
  description: string | null;
  photo: string | null;
  is_active: boolean;
}

/**
 * Row written to `product_variants` base table.
 */
export interface VariantRow {
  variant_id: string;
  product_id: string;
  title: string;
  price: number | null;
  old_price: number | null;
  quantity: number | null;
  editions: string | null;
  modifications: string | null;
  photo: string | null;
  attributes: Record<string, unknown> | null;
}

export interface ProductImageRow {
  product_id: string;
  url: string;
  position: number;
}

export interface SyncStats {
  products_seen: number;
  variants_seen: number;
  images_seen: number;
  products_upserted: number;
  variants_upserted: number;
  images_upserted: number;
  error_count: number;
}

export interface SyncError {
  stage: string;
  external_key: string;
  message: string;
  details?: Record<string, unknown>;
}
