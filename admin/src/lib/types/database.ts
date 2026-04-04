/**
 * Product-level data. Source table: `products`.
 *
 * Contains presentation/content fields (title, brand, category, description,
 * photo, mark). The `is_active` flag controls visibility across the entire
 * mobile app.
 *
 * Key contract notes:
 * - `tilda_uid` links to the external Tilda catalog sync. Manually-created
 *   products should leave this null.
 * - `mark` controls badge/section placement in the mobile app
 *   (e.g. "NEW", "ХИТ", "SALE"). Case-sensitive in mobile queries.
 * - `text` is the full description (HTML). `description` is the short one.
 */
export interface Product {
  id: string;
  tilda_uid: string | null;
  external_id: string | null;
  title: string;
  brand: string | null;
  category: string | null;
  mark: string | null;
  description: string | null;
  text: string | null;
  photo: string | null;
  is_active: boolean;
  created_at?: string;
}

/**
 * Variant/SKU-level data. Source table: `product_variants`.
 *
 * Key contract notes:
 * - `variant_id` is the PUBLIC identity field used by the mobile app as
 *   CatalogItemEntity.id. It MUST be non-null for the mobile app to function.
 *   The backfill migration sets it to `id::text` for existing rows, but new
 *   rows inserted with null will break the Flutter app.
 * - `editions` / `modifications` are semicolon-delimited display strings.
 * - The `attributes` JSONB column does NOT exist in the live DB (as of the
 *   last audit). Do not reference it until a migration creates it.
 */
export interface ProductVariant {
  id: string;
  product_id: string;
  variant_id: string | null;
  title: string | null;
  price: number | null;
  old_price: number | null;
  quantity: number | null;
  editions: string | null;
  modifications: string | null;
  photo: string | null;
  /** Present in sync-engine schema; not verified via live DDL dump. */
  external_id?: string | null;
  /** Present in sync-engine schema; not verified via live DDL dump. */
  parent_uid?: string | null;
  /** Present in sync-engine schema; not verified via live DDL dump. */
  weight?: string | null;
  /** Present in sync-engine schema; not verified via live DDL dump. */
  raw_data?: Record<string, unknown> | null;
  /** Present in sync-engine schema; not verified via live DDL dump. */
  tilda_uid?: string | null;
  created_at?: string;
}

/**
 * Gallery image. Source table: `product_images`.
 *
 * Ordered by `position` (ascending). The mobile app loads these separately
 * from the catalog VIEW for the product detail page.
 *
 * `product_tilda_uid` verified via REST API — links to parent product's
 * Tilda sync UID.
 */
export interface ProductImage {
  id: string;
  product_id: string;
  url: string;
  position: number;
  product_tilda_uid?: string | null;
}

export type ProductInsert = Omit<Product, "id" | "created_at">;
export type ProductUpdate = Partial<ProductInsert>;

/**
 * variant_id is excluded — the DB generates it via DEFAULT gen_random_uuid()::text.
 * raw_data and created_at are also DB-managed.
 */
export type VariantInsert = Omit<ProductVariant, "id" | "variant_id" | "created_at" | "raw_data">;
export type VariantUpdate = Partial<Omit<VariantInsert, "product_id">>;

export type ImageInsert = Omit<ProductImage, "id">;
