import { assert, assertEquals } from "https://deno.land/std@0.224.0/assert/mod.ts";
import { auditGalleryReport } from "./audit.ts";
import type { RecoverReport } from "./recover.ts";

const hiddenMigration = new URL(
  "../../deploy/migrations/20261114121551_tilda_insert_hidden.sql",
  import.meta.url,
);
const schedulePlaceholder = new URL(
  "../../deploy/pending/catalog_pipeline_schedule.sql",
  import.meta.url,
);
const visibilityRpc = new URL(
  "../../deploy/migrations/20261113190107_admin_rpcs.sql",
  import.meta.url,
);

Deno.test("new Tilda products are hidden on insert only", async () => {
  const sql = await Deno.readTextFile(hiddenMigration);
  assert(sql.includes("BEFORE INSERT ON public.products"));
  assert(sql.includes("NEW.app_is_visible := false"));
  assert(sql.includes("NEW.tilda_uid IS NOT NULL"));
  assertEquals(sql.includes("BEFORE UPDATE"), false);
  assertEquals(sql.includes("DELETE FROM public.products"), false);
  assertEquals(sql.includes("cron.schedule"), false);
});

Deno.test("catalog schedule placeholder refuses to install", async () => {
  const sql = await Deno.readTextFile(schedulePlaceholder);
  assert(sql.includes("RAISE EXCEPTION"));
  assertEquals(/^\s*SELECT\s+cron\.schedule/m.test(sql), false);
});

Deno.test("admin visibility RPC does not reject Tilda products", async () => {
  const sql = await Deno.readTextFile(visibilityRpc);
  const start = sql.indexOf("FUNCTION public.admin_set_product_visibility");
  const end = sql.indexOf("COMMENT ON FUNCTION public.admin_set_product_visibility");
  const body = sql.slice(start, end);
  assert(body.includes("SET app_is_visible = p_visible"));
  assertEquals(body.includes("tilda_uid"), false);
  assertEquals(body.includes("is_active ="), false);
});

Deno.test("gallery handler returns the audit and does not write", async () => {
  const source = await Deno.readTextFile(new URL("./index.ts", import.meta.url));
  assert(source.includes("auditGalleryReport"));
  assertEquals(source.includes(".insert("), false);
  assertEquals(source.includes(".upsert("), false);
  assertEquals(source.includes("cron.schedule"), false);
});

Deno.test("gallery audit stays at zero writes when extras are mixed", () => {
  const report: RecoverReport = {
    mode: "dry_run",
    writes: 0,
    requestedUids: ["1", "2", "3"],
    products: [
      {
        tildaUid: "1",
        classification: "importable",
        editionCount: 1,
        galleryCount: 3,
        importable: [
          { url: "https://static.tildacdn.com/a/1.jpg", identity: "tildacdn:/a/1.jpg" },
          { url: "https://static.tildacdn.com/a/2.jpg", identity: "tildacdn:/a/2.jpg" },
        ],
        skippedAmbiguous: [],
        duplicates: [],
        invalid: [],
        inserted: 0,
        primaryCount: 0,
      },
      {
        tildaUid: "2",
        classification: "ambiguous",
        editionCount: 16,
        galleryCount: 17,
        importable: [],
        skippedAmbiguous: [
          { url: "https://static.tildacdn.com/b/extra.jpg", identity: "tildacdn:/b/extra.jpg" },
        ],
        duplicates: [],
        invalid: [],
        inserted: 0,
        primaryCount: 0,
      },
      {
        tildaUid: "3",
        classification: "access_denied",
        editionCount: 0,
        galleryCount: 0,
        importable: [],
        skippedAmbiguous: [],
        duplicates: [],
        invalid: [],
        inserted: 0,
        primaryCount: 0,
        detail: "HTTP 403",
      },
    ],
  };

  assertEquals(auditGalleryReport(report), {
    mode: "dry_run",
    requestedUids: ["1", "2", "3"],
    processed: 3,
    sourceImagesFound: 20,
    existingPrimaryImages: 0,
    confirmedSupplementary: 2,
    imagesInserted: 0,
    skippedDuplicates: 0,
    skippedAmbiguous: 1,
    access_denied: 1,
    errors: 1,
    writes: 0,
    isolatedFromCatalogSync: true,
    attempted: 3,
    importableProducts: 1,
    preparedImages: 2,
    ambiguousProducts: 1,
    accessDenied: 1,
    extractFailed: 0,
    validationFailed: 0,
    noExtras: 0,
  });
});
