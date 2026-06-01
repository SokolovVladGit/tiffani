import { assert } from "https://deno.land/std@0.224.0/assert/mod.ts";

/**
 * Structural guard for Phase 3A migration SQL (native product RPC).
 */
const migrationSource = await Deno.readTextFile(
  new URL("./20260601130000_admin_upsert_native_product_rpc.sql", import.meta.url),
);

Deno.test("migration defines generate_admin_variant_id with admin_ prefix", () => {
  assert(migrationSource.includes("generate_admin_variant_id"));
  assert(
    migrationSource.includes("'admin_' || replace(gen_random_uuid()"),
    "must generate admin_<hex> variant_id",
  );
});

Deno.test("migration rejects Tilda product edits", () => {
  assert(
    migrationSource.includes("Tilda products cannot be edited"),
    "must block tilda_uid IS NOT NULL updates",
  );
});

Deno.test("migration forces native tilda_uid NULL and is_active true", () => {
  assert(migrationSource.includes("tilda_uid      = NULL"));
  assert(migrationSource.includes("is_active      = true"));
});

Deno.test("migration replaces product_images on update", () => {
  assert(migrationSource.includes("DELETE FROM public.product_images"));
});

Deno.test("migration does not alter catalog_items view or submit_order RPCs", () => {
  assert(!migrationSource.includes("DROP VIEW"));
  assert(!migrationSource.includes("CREATE VIEW public.catalog_items"));
  assert(!migrationSource.includes("CREATE OR REPLACE FUNCTION public.submit_order"));
});

Deno.test("migration update path preserves variant_id from locked row", () => {
  assert(
    migrationSource.includes("v_variant_id := v_variant.variant_id"),
    "update must keep existing variant_id",
  );
  const updateVariantSet = migrationSource.slice(
    migrationSource.indexOf("UPDATE public.product_variants"),
    migrationSource.lastIndexOf("WHERE id = v_variant.id"),
  );
  assert(
    !updateVariantSet.includes("variant_id"),
    "variant update SET must not include variant_id column",
  );
});

Deno.test("migration create path uses generate_admin_variant_id", () => {
  assert(
    migrationSource.includes("v_variant_id := public.generate_admin_variant_id()"),
    "create must assign admin variant_id via helper",
  );
});
