import { assert } from "https://deno.land/std@0.224.0/assert/mod.ts";

/**
 * Structural guards for catalog-yml-sync-safe.
 *
 * Each test reads the relevant source file as text and asserts
 * that forbidden constructs do not appear. These checks run as
 * part of `deno test` and are deliberately cheap so they can also
 * gate any future refactor that would weaken the safety contract.
 *
 * The patterns checked here mirror the safety contract documented
 * in `index.ts` and the v1 anchor prompt:
 *   - no use of `syncCatalog`
 *   - no reference to `deactivateMissingProducts`
 *   - no `is_active: false` write
 *   - no use of the old `catalog-sync` endpoint
 *   - no use of any Tilda REST product API endpoint
 */

const ROOT = new URL(".", import.meta.url);

/**
 * Reads a source file and strips JavaScript/TypeScript comments
 * (line and block) so that documentation that mentions forbidden
 * APIs by name does not trigger false positives in the structural
 * checks below. String/template literals are preserved as-is.
 */
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
      if (escape) {
        escape = false;
      } else if (c === "\\") {
        escape = true;
      } else if (c === strCh) {
        inStr = false;
      }
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

const FORBIDDEN_TILDA_REST = [
  "/v1/getproductslist",
  "/v1/getproduct",
  "/v1/getstoreproducts",
  "/v1/getcatalog",
  "/v1/getgoods",
  "/v1/getproductlist",
  "/v1/getstorelist",
  "/v1/getstoreproduct",
  "/v1/getproducts",
  "api.tildacdn.info",
];

const SAFE_SYNC_FILES = [
  "index.ts",
  "config.ts",
  "run-logger.ts",
  "missing-candidates.ts",
];

Deno.test("safe sync source: no syncCatalog import or call", async () => {
  for (const file of SAFE_SYNC_FILES) {
    const src = await readSource(file);
    assert(
      !/\bsyncCatalog\b/.test(src),
      `${file} must not reference syncCatalog`,
    );
  }
});

Deno.test(
  "safe sync source: no deactivateMissingProducts reference",
  async () => {
    for (const file of SAFE_SYNC_FILES) {
      const src = await readSource(file);
      assert(
        !src.includes("deactivateMissingProducts"),
        `${file} must not reference deactivateMissingProducts`,
      );
    }
  },
);

Deno.test("safe sync source: no is_active=false write", async () => {
  for (const file of SAFE_SYNC_FILES) {
    const src = await readSource(file);
    assert(
      !/is_active\s*:\s*false/.test(src),
      `${file} must not contain "is_active: false"`,
    );
  }
});

Deno.test("safe sync source: no call to old catalog-sync endpoint", async () => {
  for (const file of SAFE_SYNC_FILES) {
    const src = await readSource(file);
    assert(
      !src.includes("/functions/v1/catalog-sync"),
      `${file} must not invoke /functions/v1/catalog-sync`,
    );
  }
});

Deno.test(
  "safe sync source: no Tilda REST product API endpoints",
  async () => {
    for (const file of SAFE_SYNC_FILES) {
      const src = await readSource(file);
      for (const needle of FORBIDDEN_TILDA_REST) {
        assert(
          !src.includes(needle),
          `${file} must not reference Tilda REST API ${needle}`,
        );
      }
    }
  },
);

Deno.test(
  "missing-candidates: no mutating supabase methods",
  async () => {
    const src = await readSource("missing-candidates.ts");
    const forbidden = [
      ".update(",
      ".delete(",
      ".upsert(",
      ".insert(",
      ".rpc(",
    ];
    for (const needle of forbidden) {
      assert(
        !src.includes(needle),
        `missing-candidates.ts must not call ${needle}`,
      );
    }
  },
);

Deno.test(
  "missing-candidates: filters tilda_uid IS NOT NULL and is_active true",
  async () => {
    const src = await readSource("missing-candidates.ts");
    assert(
      src.includes('.eq("is_active", true)'),
      "missing-candidates must filter is_active = true",
    );
    assert(
      src.includes('.not("tilda_uid", "is", null)'),
      "missing-candidates must exclude rows where tilda_uid IS NULL",
    );
  },
);

Deno.test(
  "index.ts: dry-run is the default (live requires literal false)",
  async () => {
    const src = await readSource("index.ts");
    assert(
      src.includes("body.dry_run !== false"),
      "index.ts must require body.dry_run === false to enable live writes",
    );
  },
);

Deno.test(
  "index.ts: pins no_deactivation: true in run metadata",
  async () => {
    const src = await readSource("index.ts");
    assert(
      src.includes("no_deactivation: true"),
      "index.ts must mark every run as no_deactivation: true for monitoring",
    );
  },
);

Deno.test(
  "run-logger: source_type is the safe sync constant",
  async () => {
    const src = await readSource("run-logger.ts");
    assert(
      src.includes('"yml_safe_sync"'),
      "run-logger must stamp catalog_sync_runs with source_type yml_safe_sync",
    );
  },
);
