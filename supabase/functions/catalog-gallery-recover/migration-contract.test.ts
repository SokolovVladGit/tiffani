import { assert, assertEquals } from "https://deno.land/std@0.224.0/assert/mod.ts";

const migrationUrl = new URL(
  "../../deploy/migrations/20261114121521_product_images_source.sql",
  import.meta.url,
);

Deno.test("gallery source migration is additive and tilda-only", async () => {
  const sql = await Deno.readTextFile(migrationUrl);
  assert(sql.includes("ADD COLUMN IF NOT EXISTS source text"));
  assert(sql.includes("'yml_variant'"));
  assert(sql.includes("'tilda_gallery'"));
  assert(sql.includes("product.tilda_uid IS NOT NULL"));
  assert(sql.includes("image.source IS NULL"));
  assert(sql.includes("variant.photo = image.url"));
  assertEquals(sql.includes("DROP TABLE"), false);
  assertEquals(sql.includes("DELETE FROM"), false);
  assertEquals(/\bmark\b/.test(sql), false);
});
