import { assert } from "https://deno.land/std@0.224.0/assert/mod.ts";
import { looksLikeYmlText } from "./metrics.ts";

const ROOT = new URL(".", import.meta.url);

async function readSource(name: string): Promise<string> {
  const raw = await Deno.readTextFile(new URL(name, ROOT));
  return stripComments(raw);
}

function stripComments(src: string): string {
  let out = "";
  let i = 0;
  let inStr = false;
  let strCh = "";
  let escape = false;
  while (i < src.length) {
    const c = src[i];
    const next = src[i + 1];
    if (inStr) {
      out += c;
      if (escape) escape = false;
      else if (c === "\\") escape = true;
      else if (c === strCh) inStr = false;
      i++;
      continue;
    }
    if (c === '"' || c === "'" || c === "`") {
      inStr = true;
      strCh = c;
      out += c;
      i++;
      continue;
    }
    if (c === "/" && next === "/") {
      while (i < src.length && src[i] !== "\n") i++;
      continue;
    }
    if (c === "/" && next === "*") {
      i += 2;
      while (i < src.length && !(src[i - 1] === "*" && src[i] === "/")) i++;
      i++;
      continue;
    }
    out += c;
    i++;
  }
  return out;
}

const MANUAL_FILES = [
  "index.ts",
  "auth.ts",
  "config.ts",
  "run-logger.ts",
  "metrics.ts",
];

Deno.test("manual import: no syncCatalog reference", async () => {
  for (const file of MANUAL_FILES) {
    const src = await readSource(file);
    assert(!/\bsyncCatalog\b/.test(src), `${file} must not reference syncCatalog`);
  }
});

Deno.test("manual import: no deactivateMissingProducts", async () => {
  for (const file of MANUAL_FILES) {
    const src = await readSource(file);
    assert(
      !src.includes("deactivateMissingProducts"),
      `${file} must not reference deactivateMissingProducts`,
    );
  }
});

Deno.test("manual import: no is_active=false write", async () => {
  for (const file of MANUAL_FILES) {
    const src = await readSource(file);
    assert(
      !/is_active\s*:\s*false/.test(src),
      `${file} must not contain is_active: false`,
    );
  }
});

Deno.test("manual import: no destructive deletes on catalog tables", async () => {
  const src = await readSource("index.ts");
  for (const table of ["products", "product_variants", "product_images"]) {
    assert(
      !new RegExp(`\\.from\\(\\s*["']${table}["']\\s*\\)[\\s\\S]*?\\.delete\\(`)
        .test(src),
      `index.ts must not delete from ${table}`,
    );
  }
});

Deno.test("manual import: source_type yml_manual_import", async () => {
  const src = await readSource("run-logger.ts");
  assert(
    src.includes('"yml_manual_import"'),
    "run-logger must use source_type yml_manual_import",
  );
});

Deno.test("manual import: dry_run default requires literal false for live", async () => {
  const src = await readSource("index.ts");
  assert(
    src.includes("body.dry_run !== false"),
    "index.ts must require body.dry_run === false for live writes",
  );
});

Deno.test("manual import: no_deactivation in run metadata", async () => {
  const src = await readSource("index.ts");
  assert(
    src.includes("no_deactivation: true"),
    "index.ts must pin no_deactivation: true",
  );
});

Deno.test("manual import: uses upsertCatalogSlice on live path", async () => {
  const src = await readSource("index.ts");
  assert(
    src.includes("upsertCatalogSlice"),
    "index.ts must call upsertCatalogSlice",
  );
});

Deno.test("manual import: dry-run path does not await upsertCatalogSlice", async () => {
  const src = await readSource("index.ts");
  const dryRunReturn = src.indexOf('mode: "dry_run"');
  const syncSeenAt = src.indexOf("const syncSeenAt");
  assert(dryRunReturn >= 0 && syncSeenAt >= 0);
  const beforeLive = src.slice(0, syncSeenAt);
  assert(
    !/await\s+upsertCatalogSlice\s*\(/.test(beforeLive),
    "upsertCatalogSlice must not be awaited before live path",
  );
  assert(
    /await\s+upsertCatalogSlice\s*\(/.test(src.slice(syncSeenAt)),
    "live path must await upsertCatalogSlice",
  );
});

Deno.test("manual import: requireAdmin before parse call", async () => {
  const src = await readSource("index.ts");
  const authPos = src.indexOf("await requireAdmin");
  const parsePos = src.indexOf("parseTildaYml(ymlText)");
  assert(authPos >= 0 && parsePos >= 0 && authPos < parsePos);
});

Deno.test("config.toml: verify_jwt true for catalog-yml-import-manual", async () => {
  const raw = await Deno.readTextFile(
    new URL("../../config.toml", ROOT),
  );
  assert(
    raw.includes("[functions.catalog-yml-import-manual]"),
    "config.toml must define catalog-yml-import-manual",
  );
  const section = raw.slice(raw.indexOf("[functions.catalog-yml-import-manual]"));
  assert(
    /verify_jwt\s*=\s*true/.test(section.split("\n\n")[0] ?? section),
    "catalog-yml-import-manual must have verify_jwt = true",
  );
});

Deno.test("looksLikeYmlText accepts minimal yml_catalog", () => {
  assert(looksLikeYmlText(
    '<?xml version="1.0"?><yml_catalog><shop><offers><offer id="1"/></offers></shop></yml_catalog>',
  ));
});

Deno.test("looksLikeYmlText rejects plain text", () => {
  assert(!looksLikeYmlText("not xml at all"));
});
