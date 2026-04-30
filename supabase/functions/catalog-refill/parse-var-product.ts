/**
 * Minimal, sanitized extractor for `var product = {...}` blocks found in
 * Tilda /tproduct/<uid> SPA-shell HTML.
 *
 * Discovery evidence (5/5 samples):
 *   - `uid` (= URL UID) is the edition/offer UID.
 *   - `parentuid` is the product-level UID.
 *   - Gallery / description / brand / category / images are NOT present
 *     in the HTML; they load client-side after render.
 *
 * This parser intentionally extracts ONLY identity + title + price + externalid.
 * It must never surface proprietary content beyond what a classification probe
 * requires.
 */
export interface VarProductMinimal {
  uid: string;
  parentuid?: string;
  title?: string;
  price?: string;
  externalid?: string;
}

export function parseVarProduct(html: string): VarProductMinimal | null {
  const marker = /var\s+product\s*=\s*/;
  const m = marker.exec(html);
  if (!m) return null;

  let i = m.index + m[0].length;
  while (i < html.length && html[i] !== "{") i++;
  if (i >= html.length || html[i] !== "{") return null;

  const literal = extractBalancedObject(html, i);
  if (!literal) return null;

  let obj: unknown;
  try {
    obj = JSON.parse(literal);
  } catch {
    return null;
  }

  if (!obj || typeof obj !== "object") return null;
  const rec = obj as Record<string, unknown>;

  const uid = toStr(rec.uid);
  if (!uid) return null;

  return {
    uid,
    parentuid: toStr(rec.parentuid),
    title: toStr(rec.title),
    price: toStr(rec.price),
    externalid: toStr(rec.externalid),
  };
}

/**
 * Returns the substring from `start` (inclusive `{`) to the matching `}`,
 * respecting string literals and escape sequences. Returns null if the
 * object is not properly balanced.
 */
function extractBalancedObject(html: string, start: number): string | null {
  let depth = 0;
  let inStr = false;
  let strCh = "";
  let escape = false;

  for (let i = start; i < html.length; i++) {
    const c = html[i];
    if (inStr) {
      if (escape) {
        escape = false;
        continue;
      }
      if (c === "\\") {
        escape = true;
        continue;
      }
      if (c === strCh) inStr = false;
      continue;
    }
    if (c === '"' || c === "'") {
      inStr = true;
      strCh = c;
      continue;
    }
    if (c === "{") depth++;
    else if (c === "}") {
      depth--;
      if (depth === 0) return html.slice(start, i + 1);
    }
  }
  return null;
}

function toStr(v: unknown): string | undefined {
  if (v === null || v === undefined) return undefined;
  if (typeof v === "string") return v;
  if (typeof v === "number" && Number.isFinite(v)) return String(v);
  return undefined;
}
