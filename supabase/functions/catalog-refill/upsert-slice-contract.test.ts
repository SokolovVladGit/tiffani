import { assert } from "https://deno.land/std@0.224.0/assert/mod.ts";

/**
 * Structural guard — ensures the refill upsert path can never
 * call `deactivateMissingProducts`. This runs as a cheap static
 * check against the actual sync-engine source so refactors that
 * would regress the invariant fail loudly.
 */
const engineSource = await Deno.readTextFile(
  new URL("../catalog-sync/sync-engine.ts", import.meta.url),
);

/**
 * Extracts the body of a TypeScript function given its declaration header.
 *
 * Tracks angle-bracket depth so the `{ … }` inside generic type
 * annotations such as `Promise<{ stats: Stats }>` in the return type
 * is not mistaken for the function body opener.
 */
function extractFunctionBody(
  src: string,
  header: string,
): string {
  const headerStart = src.indexOf(header);
  if (headerStart < 0) {
    throw new Error(`function header not found: ${header}`);
  }

  let bodyOpen = -1;
  {
    let angle = 0;
    let paren = 0;
    let inStr = false, strCh = "", escape = false;
    let line = false, block = false;

    for (let i = headerStart; i < src.length; i++) {
      const c = src[i];
      const prev = src[i - 1];
      if (line) { if (c === "\n") line = false; continue; }
      if (block) { if (prev === "*" && c === "/") block = false; continue; }
      if (inStr) {
        if (escape) { escape = false; continue; }
        if (c === "\\") { escape = true; continue; }
        if (c === strCh) inStr = false;
        continue;
      }
      if (c === "/" && src[i + 1] === "/") { line = true; continue; }
      if (c === "/" && src[i + 1] === "*") { block = true; continue; }
      if (c === '"' || c === "'" || c === "`") { inStr = true; strCh = c; continue; }
      if (c === "<") angle++;
      else if (c === ">") { if (angle > 0) angle--; }
      else if (c === "(") paren++;
      else if (c === ")") paren--;
      else if (c === "{" && angle === 0 && paren === 0) {
        bodyOpen = i;
        break;
      }
    }
  }
  if (bodyOpen < 0) {
    throw new Error(`body opener not found for: ${header}`);
  }

  let depth = 0;
  let inStr = false, strCh = "", escape = false;
  let line = false, block = false;

  for (let i = bodyOpen; i < src.length; i++) {
    const c = src[i];
    const prev = src[i - 1];
    if (line) { if (c === "\n") line = false; continue; }
    if (block) { if (prev === "*" && c === "/") block = false; continue; }
    if (inStr) {
      if (escape) { escape = false; continue; }
      if (c === "\\") { escape = true; continue; }
      if (c === strCh) inStr = false;
      continue;
    }
    if (c === "/" && src[i + 1] === "/") { line = true; continue; }
    if (c === "/" && src[i + 1] === "*") { block = true; continue; }
    if (c === '"' || c === "'" || c === "`") { inStr = true; strCh = c; continue; }
    if (c === "{") depth++;
    else if (c === "}") {
      depth--;
      if (depth === 0) return src.slice(bodyOpen, i + 1);
    }
  }
  throw new Error(`unterminated function: ${header}`);
}

Deno.test(
  "upsertCatalogSlice never references deactivateMissingProducts",
  () => {
    const body = extractFunctionBody(
      engineSource,
      "export async function upsertCatalogSlice",
    );
    assert(
      !body.includes("deactivateMissingProducts"),
      "upsertCatalogSlice must not invoke the deactivation helper",
    );
    assert(
      !body.includes("is_active: false"),
      "upsertCatalogSlice must not ever write is_active=false",
    );
  },
);

Deno.test(
  "shared upsertPhases1to3 helper stays deactivation-free",
  () => {
    const body = extractFunctionBody(
      engineSource,
      "async function upsertPhases1to3",
    );
    assert(
      !body.includes("deactivateMissingProducts"),
      "phases 1-3 must not reference the deactivation helper",
    );
    assert(
      !body.includes("is_active: false"),
      "phases 1-3 must not ever write is_active=false",
    );
  },
);

Deno.test(
  "syncCatalog still performs deactivation (regression guard)",
  () => {
    const body = extractFunctionBody(
      engineSource,
      "export async function syncCatalog",
    );
    assert(
      body.includes("deactivateMissingProducts"),
      "syncCatalog must continue to call deactivateMissingProducts (full-sync behavior preserved)",
    );
  },
);
