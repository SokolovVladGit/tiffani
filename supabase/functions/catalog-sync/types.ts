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
  picture?: string;
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
