/**
 * Product, variant, and image queries/mutations.
 *
 * Product writes target `products`.
 * Variant writes target `product_variants`.
 * Image writes target `product_images` (URL-based only, no storage upload).
 *
 * variant_id is NEVER sent in payloads — the DB generates it.
 */

import { supabase } from "../../lib/supabase";
import type {
  Product,
  ProductInsert,
  ProductUpdate,
  ProductVariant,
  VariantInsert,
  VariantUpdate,
  ProductImage,
  ImageInsert,
} from "../../lib/types/database";

export const PAGE_SIZE = 50;

export type StatusFilter = "all" | "active" | "inactive";
export type MarkFilter = "" | "NEW" | "ХИТ" | "SALE" | "none";
export type SortOption = "newest" | "oldest" | "title_asc" | "title_desc";

export interface ProductListFilters {
  search: string;
  status: StatusFilter;
  brand: string;
  category: string;
  mark: MarkFilter;
  sort: SortOption;
}

export const EMPTY_FILTERS: ProductListFilters = {
  search: "",
  status: "all",
  brand: "",
  category: "",
  mark: "",
  sort: "newest",
};

export type ProductListRow = Pick<
  Product,
  "id" | "title" | "brand" | "category" | "photo" | "is_active" | "mark" | "created_at"
>;

export interface ProductListResult {
  rows: ProductListRow[];
  totalCount: number;
}

const LIST_COLUMNS =
  "id, title, brand, category, photo, is_active, mark, created_at";

/**
 * Fetches a page of products with filters, search, and sort.
 * Search matches across title, external_id, and tilda_uid.
 */
export async function fetchProducts(
  filters: ProductListFilters,
  page: number,
): Promise<ProductListResult> {
  let query = supabase
    .from("products")
    .select(LIST_COLUMNS, { count: "exact" });

  if (filters.search.trim()) {
    const term = filters.search.trim().replace(/%/g, "\\%");
    query = query.or(
      `title.ilike.%${term}%,external_id.ilike.%${term}%,tilda_uid.ilike.%${term}%`,
    );
  }

  if (filters.status === "active") {
    query = query.eq("is_active", true);
  } else if (filters.status === "inactive") {
    query = query.eq("is_active", false);
  }

  if (filters.brand) {
    query = query.eq("brand", filters.brand);
  }

  if (filters.category) {
    query = query.eq("category", filters.category);
  }

  if (filters.mark === "none") {
    query = query.is("mark", null);
  } else if (filters.mark) {
    query = query.eq("mark", filters.mark);
  }

  const from = page * PAGE_SIZE;
  const to = from + PAGE_SIZE - 1;

  switch (filters.sort) {
    case "oldest":
      query = query.order("created_at", { ascending: true });
      break;
    case "title_asc":
      query = query.order("title", { ascending: true });
      break;
    case "title_desc":
      query = query.order("title", { ascending: false });
      break;
    default:
      query = query.order("created_at", { ascending: false });
  }

  const { data, count, error } = await query.range(from, to);

  if (error) throw error;

  return {
    rows: (data ?? []) as ProductListRow[],
    totalCount: count ?? 0,
  };
}

/**
 * Uses the `get_distinct_brands` RPC defined in
 * `supabase/migrations/20260330120000_create_distinct_filter_rpcs.sql`.
 */
export async function fetchDistinctBrands(): Promise<string[]> {
  const { data, error } = await supabase.rpc("get_distinct_brands");
  if (error) throw error;
  return ((data ?? []) as Array<{ brand: string }>).map((r) => r.brand);
}

/**
 * Uses the `get_distinct_categories` RPC defined in
 * `supabase/migrations/20260330120000_create_distinct_filter_rpcs.sql`.
 */
export async function fetchDistinctCategories(): Promise<string[]> {
  const { data, error } = await supabase.rpc("get_distinct_categories");
  if (error) throw error;
  return ((data ?? []) as Array<{ category: string }>).map((r) => r.category);
}

// ---------------------------------------------------------------------------
// Catalog health diagnostics
// ---------------------------------------------------------------------------

export interface CatalogHealth {
  productsCount: number;
  variantsCount: number;
  catalogItemsCount: number;
  orphanProductsCount: number;
}

/**
 * Returns counts for products, variants, catalog_items, and orphan products.
 * Uses HEAD+Prefer:count=exact for the first three; orphans require a filtered query.
 */
export async function fetchCatalogHealth(): Promise<CatalogHealth> {
  const [products, variants, catalog, orphans] = await Promise.all([
    supabase.from("products").select("id", { count: "exact", head: true }),
    supabase
      .from("product_variants")
      .select("id", { count: "exact", head: true }),
    supabase
      .from("catalog_items")
      .select("variant_id", { count: "exact", head: true }),
    supabase.rpc("count_orphan_products"),
  ]);

  return {
    productsCount: products.count ?? 0,
    variantsCount: variants.count ?? 0,
    catalogItemsCount: catalog.count ?? 0,
    orphanProductsCount:
      typeof orphans.data === "number" ? orphans.data : 0,
  };
}

// ---------------------------------------------------------------------------
// Detail queries
// ---------------------------------------------------------------------------

/** Fetches a single product by ID. Throws PGRST116 if not found. */
export async function fetchProduct(id: string): Promise<Product> {
  const { data, error } = await supabase
    .from("products")
    .select("*")
    .eq("id", id)
    .single();

  if (error) throw error;
  return data as Product;
}

/** Fetches all variants for a product, ordered by creation time. */
export async function fetchProductVariants(
  productId: string,
): Promise<ProductVariant[]> {
  const { data, error } = await supabase
    .from("product_variants")
    .select("*")
    .eq("product_id", productId)
    .order("created_at", { ascending: true });

  if (error) throw error;
  return (data ?? []) as ProductVariant[];
}

/** Fetches all gallery images for a product, ordered by position. */
export async function fetchProductImages(
  productId: string,
): Promise<ProductImage[]> {
  const { data, error } = await supabase
    .from("product_images")
    .select("*")
    .eq("product_id", productId)
    .order("position", { ascending: true });

  if (error) throw error;
  return (data ?? []) as ProductImage[];
}

// ---------------------------------------------------------------------------
// Product mutations
// ---------------------------------------------------------------------------

export interface CreateVariantOverrides {
  price?: number | null;
  old_price?: number | null;
  quantity?: number | null;
  editions?: string | null;
  modifications?: string | null;
}

/**
 * Creates a product AND a default variant in one logical operation.
 * Without at least one variant the product is invisible in catalog_items.
 * variant_id is never sent — the DB generates it.
 */
export async function createProduct(
  payload: ProductInsert,
  variantOverrides?: CreateVariantOverrides,
): Promise<Product> {
  const { data, error } = await supabase
    .from("products")
    .insert(payload)
    .select()
    .single();

  if (error) throw error;
  const product = data as Product;

  const { error: variantError } = await supabase
    .from("product_variants")
    .insert({
      product_id: product.id,
      title: product.title,
      price: variantOverrides?.price ?? 0,
      old_price: variantOverrides?.old_price ?? null,
      quantity: variantOverrides?.quantity ?? 0,
      editions: variantOverrides?.editions ?? null,
      modifications: variantOverrides?.modifications ?? null,
      photo: product.photo ?? null,
      external_id: product.external_id ?? null,
      tilda_uid: product.tilda_uid ?? null,
    });

  if (variantError) {
    console.error(
      `[createProduct] Product ${product.id} created but default variant failed:`,
      variantError.message,
    );
  }

  return product;
}

/**
 * Toggles a product's is_active flag. Returns the new value.
 * This is the fast path for visibility management from the list page.
 */
export async function toggleProductActive(
  id: string,
  isActive: boolean,
): Promise<boolean> {
  const { data, error } = await supabase
    .from("products")
    .update({ is_active: isActive })
    .eq("id", id)
    .select("is_active")
    .single();

  if (error) throw error;
  return (data as { is_active: boolean }).is_active;
}

export async function updateProduct(
  id: string,
  payload: ProductUpdate,
): Promise<Product> {
  const { data, error } = await supabase
    .from("products")
    .update(payload)
    .eq("id", id)
    .select()
    .single();

  if (error) throw error;
  return data as Product;
}

// ---------------------------------------------------------------------------
// Variant mutations (variant_id is NEVER included — DB generates it)
// ---------------------------------------------------------------------------

export async function createVariant(
  payload: VariantInsert,
): Promise<ProductVariant> {
  const { data, error } = await supabase
    .from("product_variants")
    .insert(payload)
    .select()
    .single();

  if (error) throw error;
  return data as ProductVariant;
}

export async function updateVariant(
  id: string,
  payload: VariantUpdate,
): Promise<ProductVariant> {
  const { data, error } = await supabase
    .from("product_variants")
    .update(payload)
    .eq("id", id)
    .select()
    .single();

  if (error) throw error;
  return data as ProductVariant;
}

/**
 * Deletes a variant after verifying it is not the last one for its product.
 * A product with zero variants becomes invisible in the mobile app.
 */
export async function deleteVariant(
  id: string,
  productId: string,
): Promise<void> {
  const { count, error: countErr } = await supabase
    .from("product_variants")
    .select("id", { count: "exact", head: true })
    .eq("product_id", productId);

  if (countErr) throw countErr;

  if ((count ?? 0) <= 1) {
    console.warn(
      `[deleteVariant] Blocked: variant ${id} is the last variant of product ${productId}`,
    );
    throw new Error(
      "Cannot delete the last variant. A product without variants is invisible in the mobile app.",
    );
  }

  const { error } = await supabase
    .from("product_variants")
    .delete()
    .eq("id", id);

  if (error) throw error;
}

// ---------------------------------------------------------------------------
// Image mutations (URL-based only — no storage upload)
// ---------------------------------------------------------------------------

export async function addImage(payload: ImageInsert): Promise<ProductImage> {
  const { data, error } = await supabase
    .from("product_images")
    .insert(payload)
    .select()
    .single();

  if (error) throw error;
  return data as ProductImage;
}

export async function updateImagePosition(
  id: string,
  position: number,
): Promise<void> {
  const { error } = await supabase
    .from("product_images")
    .update({ position })
    .eq("id", id);

  if (error) throw error;
}

export async function deleteImage(id: string): Promise<void> {
  const { error } = await supabase
    .from("product_images")
    .delete()
    .eq("id", id);

  if (error) throw error;
}
