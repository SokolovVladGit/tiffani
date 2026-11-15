export interface StoreEdition {
  uid?: string;
  img?: string;
}

export interface StoreProduct {
  uid?: string;
  title?: string;
  gallery: string[];
  editions: StoreEdition[];
}

export type ExtractFailure =
  | "product_object_missing"
  | "product_object_unterminated"
  | "product_object_invalid_json"
  | "product_object_shape";

export function endOfJsonObject(source: string, open: number): number {
  if (source[open] !== "{") return -1;
  let depth = 0;
  let inString = false;
  let escape = false;
  for (let i = open; i < source.length; i++) {
    const char = source[i];
    if (inString) {
      if (escape) escape = false;
      else if (char === "\\") escape = true;
      else if (char === '"') inString = false;
      continue;
    }
    if (char === '"') {
      inString = true;
      continue;
    }
    if (char === "{") depth++;
    else if (char === "}") {
      depth--;
      if (depth === 0) return i + 1;
    }
  }
  return -1;
}

export function extractStoreProduct(
  html: string,
): { ok: true; product: StoreProduct } | { ok: false; reason: ExtractFailure } {
  const marker = "var product =";
  const at = html.indexOf(marker);
  if (at < 0) return { ok: false, reason: "product_object_missing" };
  const start = html.indexOf("{", at);
  if (start < 0) return { ok: false, reason: "product_object_missing" };
  const end = endOfJsonObject(html, start);
  if (end < 0) return { ok: false, reason: "product_object_unterminated" };
  let value: unknown;
  try {
    value = JSON.parse(html.slice(start, end));
  } catch {
    return { ok: false, reason: "product_object_invalid_json" };
  }
  const product = asStoreProduct(value);
  if (!product) return { ok: false, reason: "product_object_shape" };
  return { ok: true, product };
}

function asStoreProduct(value: unknown): StoreProduct | null {
  if (!value || typeof value !== "object" || Array.isArray(value)) return null;
  const record = value as Record<string, unknown>;
  if (!Array.isArray(record.gallery) || !Array.isArray(record.editions)) {
    return null;
  }
  const gallery: string[] = [];
  for (const entry of record.gallery) {
    if (!entry || typeof entry !== "object" || Array.isArray(entry)) continue;
    const img = (entry as Record<string, unknown>).img;
    if (typeof img === "string" && img.trim()) gallery.push(img.trim());
  }
  const editions: StoreEdition[] = [];
  for (const entry of record.editions) {
    if (!entry || typeof entry !== "object" || Array.isArray(entry)) continue;
    const row = entry as Record<string, unknown>;
    editions.push({
      uid: typeof row.uid === "string" ? row.uid : undefined,
      img: typeof row.img === "string" ? row.img.trim() : undefined,
    });
  }
  return {
    uid: typeof record.uid === "string" ? record.uid : undefined,
    title: typeof record.title === "string" ? record.title : undefined,
    gallery,
    editions,
  };
}
