import { createClient, type SupabaseClient } from "https://esm.sh/@supabase/supabase-js@2";
import type { GalleryInsertRow } from "./rows.ts";

export interface CatalogImageRow {
  url: string;
  position: number;
  source: string | null;
}

export interface CatalogProductSnapshot {
  id: string;
  tildaUid: string;
  variantCount: number;
  variantPhotoUrls: string[];
  images: CatalogImageRow[];
}

export type LoadProductResult = CatalogProductSnapshot | null | "ambiguous_product";

export type InsertImageResult =
  | "inserted"
  | "duplicate"
  | { error: string };

/**
 * The only catalog operations gallery recovery is allowed to perform.
 * Product, variant, price, mark, text, and visibility rows are not writable.
 */
export interface GalleryCatalog {
  loadProduct(tildaUid: string): Promise<LoadProductResult>;
  insertGalleryImage(row: GalleryInsertRow): Promise<InsertImageResult>;
}

interface DbError {
  message: string;
  code?: string;
}

interface FilterBuilder {
  eq(
    column: string,
    value: string,
  ): PromiseLike<{ data: unknown; error: DbError | null }>;
}

interface TableBuilder {
  select(columns: string): FilterBuilder;
  insert(row: GalleryInsertRow): PromiseLike<{ error: DbError | null }>;
}

export interface GalleryDb {
  from(table: string): TableBuilder;
}

function rowsOf(data: unknown): Record<string, unknown>[] {
  if (!Array.isArray(data)) return [];
  return data.filter((row): row is Record<string, unknown> =>
    !!row && typeof row === "object" && !Array.isArray(row)
  );
}

export function createGalleryCatalog(db: GalleryDb): GalleryCatalog {
  return {
    async loadProduct(tildaUid) {
      const products = await db.from("products").select("id, tilda_uid").eq(
        "tilda_uid",
        tildaUid,
      );
      if (products.error) throw new Error(products.error.message);
      const found = rowsOf(products.data).filter((row) => row.tilda_uid === tildaUid);
      if (found.length === 0) return null;
      if (found.length > 1) return "ambiguous_product";
      const id = found[0].id;
      if (typeof id !== "string" || !id) throw new Error("product_id_missing");

      const variants = await db.from("product_variants").select("photo").eq(
        "product_id",
        id,
      );
      if (variants.error) throw new Error(variants.error.message);
      const variantRows = rowsOf(variants.data);
      const images = await db.from("product_images").select("url, position, source").eq(
        "product_id",
        id,
      );
      if (images.error) throw new Error(images.error.message);

      return {
        id,
        tildaUid,
        variantCount: variantRows.length,
        variantPhotoUrls: variantRows.flatMap((row) =>
          typeof row.photo === "string" && row.photo.trim() ? [row.photo.trim()] : []
        ),
        images: rowsOf(images.data).flatMap((row) => {
          if (typeof row.url !== "string" || typeof row.position !== "number") return [];
          return [{
            url: row.url,
            position: row.position,
            source: typeof row.source === "string" ? row.source : null,
          }];
        }),
      };
    },

    async insertGalleryImage(row) {
      if (row.source !== "tilda_gallery") return { error: "source_rejected" };
      const inserted = await db.from("product_images").insert({
        product_id: row.product_id,
        url: row.url,
        position: row.position,
        source: "tilda_gallery",
      });
      if (!inserted.error) return "inserted";
      if (inserted.error.code === "23505") return "duplicate";
      return { error: inserted.error.message };
    },
  };
}

export function galleryCatalogFromEnv(): GalleryCatalog | null {
  const url = Deno.env.get("SUPABASE_URL");
  const key = Deno.env.get("SUPABASE_SERVICE_ROLE_KEY");
  if (!url || !key) return null;
  const client = createClient(url, key, {
    auth: { persistSession: false },
  }) as SupabaseClient;
  return createGalleryCatalog(client as unknown as GalleryDb);
}
