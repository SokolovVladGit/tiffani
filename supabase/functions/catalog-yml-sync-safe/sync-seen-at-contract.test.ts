import { assert } from "https://deno.land/std@0.224.0/assert/mod.ts";

/**
 * Live safe sync must pass syncSeenAt into upsertCatalogSlice so
 * last_seen_in_yml is stamped on upserted rows.
 */
const ROOT = new URL(".", import.meta.url);

async function readSource(name: string): Promise<string> {
  return await Deno.readTextFile(new URL(name, ROOT));
}

Deno.test("live path passes syncSeenAt to upsertCatalogSlice", async () => {
  const src = await readSource("index.ts");
  assert(
    src.includes("{ syncSeenAt }"),
    "index.ts must pass { syncSeenAt } into upsertCatalogSlice",
  );
  assert(
    src.includes("const syncSeenAt = new Date().toISOString()"),
    "index.ts must compute syncSeenAt before live upsert",
  );
  assert(
    src.includes("sync_seen_at: syncSeenAt"),
    "index.ts must record sync_seen_at in run metadata",
  );
});
