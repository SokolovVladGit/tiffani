import { XMLParser } from "https://esm.sh/fast-xml-parser@4.5.1";
import type {
  TildaCatalog,
  TildaCategory,
  TildaOffer,
  TildaParam,
} from "./types.ts";

/**
 * Parses a Tilda YML (Yandex.Market XML) export into structured catalog data.
 * Tolerates missing fields; never trusts shape blindly.
 */
export function parseTildaYml(xml: string): TildaCatalog {
  const parser = new XMLParser({
    ignoreAttributes: false,
    attributeNamePrefix: "@_",
    textNodeName: "#text",
    isArray: (_name: string) =>
      ["category", "offer", "param", "picture"].includes(_name),
    trimValues: true,
  });

  const doc = parser.parse(xml);
  const shop = doc?.yml_catalog?.shop;
  if (!shop) {
    throw new Error("Invalid YML: missing yml_catalog.shop");
  }

  const categories = parseCategories(shop.categories?.category ?? []);
  const offers = parseOffers(shop.offers?.offer ?? []);

  return { categories, offers };
}

function parseCategories(raw: unknown[]): TildaCategory[] {
  const result: TildaCategory[] = [];
  for (const item of raw) {
    if (!item || typeof item !== "object") continue;
    const r = item as Record<string, unknown>;
    const id = str(r["@_id"]);
    const name = str(r["#text"]);
    if (!id || !name) continue;
    result.push({
      id,
      name: name.trim(),
      parentId: str(r["@_parentId"]) || undefined,
    });
  }
  return result;
}

function parseOffers(raw: unknown[]): TildaOffer[] {
  const result: TildaOffer[] = [];
  for (const item of raw) {
    if (!item || typeof item !== "object") continue;
    const r = item as Record<string, unknown>;
    const id = str(r["@_id"]);
    if (!id) continue;

    result.push({
      id,
      groupId: str(r["@_group_id"]) || undefined,
      available: str(r["@_available"]) !== "false",
      url: str(r.url) || undefined,
      price: num(r.price),
      oldPrice: num(r.oldprice),
      currencyId: str(r.currencyId) || undefined,
      categoryId: str(r.categoryId) || undefined,
      picture: extractFirstPicture(r.picture),
      name: str(r.name) || undefined,
      vendor: str(r.vendor) || undefined,
      description: str(r.description) || undefined,
      count: int(r.count),
      params: parseParams(r.param),
    });
  }
  return result;
}

function parseParams(raw: unknown): TildaParam[] {
  if (!raw) return [];
  const items = Array.isArray(raw) ? raw : [raw];
  const result: TildaParam[] = [];
  for (const item of items) {
    if (!item || typeof item !== "object") continue;
    const r = item as Record<string, unknown>;
    const name = str(r["@_name"]);
    const value = str(r["#text"]);
    if (name && value) {
      result.push({ name: name.trim(), value: value.trim() });
    }
  }
  return result;
}

function extractFirstPicture(raw: unknown): string | undefined {
  if (!raw) return undefined;
  if (typeof raw === "string") return raw;
  if (Array.isArray(raw)) {
    for (const item of raw) {
      const s =
        typeof item === "object" && item !== null
          ? str((item as Record<string, unknown>)["#text"])
          : str(item);
      if (s) return s;
    }
  }
  return undefined;
}

/**
 * Builds a lookup from category ID to leaf category name.
 * Uses the immediate category name (not full path) to match
 * the existing flat category values in catalog_items.
 */
export function buildCategoryLookup(
  categories: TildaCategory[],
): Map<string, string> {
  const lookup = new Map<string, string>();
  for (const c of categories) {
    lookup.set(c.id, c.name);
  }
  return lookup;
}

function str(v: unknown): string | null {
  if (v == null) return null;
  if (typeof v === "string") return v;
  if (typeof v === "number" || typeof v === "boolean") return String(v);
  return null;
}

function num(v: unknown): number | undefined {
  if (v == null) return undefined;
  const n = Number(v);
  return Number.isFinite(n) ? n : undefined;
}

function int(v: unknown): number | undefined {
  const n = num(v);
  return n !== undefined ? Math.floor(n) : undefined;
}
