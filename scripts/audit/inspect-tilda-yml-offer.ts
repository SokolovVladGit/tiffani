#!/usr/bin/env -S deno run --allow-net --allow-env
/**
 * Read-only Tilda YML inspector for visibility / availability experiments.
 *
 * Uses TILDA_YML_URL (HTTP GET only). No Supabase, no Tilda API keys.
 *
 * Usage:
 *   export TILDA_YML_URL="https://..."
 *   deno run --allow-net --allow-env scripts/audit/inspect-tilda-yml-offer.ts \
 *     --offer=184192311111 [--offer=...] [--group=G123] [--title=substring]
 */

import { XMLParser } from "https://esm.sh/fast-xml-parser@4.5.1";

interface CliOpts {
  offerIds: string[];
  groupFilter?: string;
  titleSubstring?: string;
}

function parseCli(args: string[]): CliOpts {
  const offerIds: string[] = [];
  let groupFilter: string | undefined;
  let titleSubstring: string | undefined;
  for (const a of args) {
    if (a.startsWith("--offer=")) {
      offerIds.push(a.slice("--offer=".length).trim());
    } else if (a.startsWith("--group=")) {
      groupFilter = a.slice("--group=".length).trim() || undefined;
    } else if (a.startsWith("--title=")) {
      titleSubstring = a.slice("--title=".length).trim().toLowerCase() || undefined;
    }
  }
  return { offerIds, groupFilter, titleSubstring };
}

function str(v: unknown): string | null {
  if (v == null) return null;
  if (typeof v === "string") return v;
  if (typeof v === "number" || typeof v === "boolean") return String(v);
  return null;
}

/** Scalar XML text child: string, number, or `{ "#text": "..." }`. */
function xmlTextContent(raw: unknown): string | undefined {
  if (raw == null) return undefined;
  if (typeof raw === "string") {
    const t = raw.trim();
    return t.length > 0 ? t : undefined;
  }
  if (typeof raw === "number") return String(raw);
  if (typeof raw === "object" && "#text" in (raw as object)) {
    const t = str((raw as Record<string, unknown>)["#text"])?.trim();
    return t && t.length > 0 ? t : undefined;
  }
  return undefined;
}

function normalizeOffers(raw: unknown): Record<string, unknown>[] {
  if (!raw) return [];
  return Array.isArray(raw) ? raw as Record<string, unknown>[] : [raw as Record<string, unknown>];
}

function normalizeCategories(raw: unknown): { id: string; name: string }[] {
  const items = normalizeOffers(raw);
  const out: { id: string; name: string }[] = [];
  for (const r of items) {
    const id = str(r["@_id"]);
    const name = str(r["#text"]);
    if (id && name) out.push({ id, name: name.trim() });
  }
  return out;
}

function listXmlAttributes(record: Record<string, unknown>): Record<string, string> {
  const attrs: Record<string, string> = {};
  for (const [k, v] of Object.entries(record)) {
    if (!k.startsWith("@_")) continue;
    const val = str(v);
    if (val !== null) attrs[k.replace(/^@_/, "")] = val;
  }
  return attrs;
}

function pictureCount(rawPicture: unknown): number {
  if (!rawPicture) return 0;
  const items = Array.isArray(rawPicture) ? rawPicture : [rawPicture];
  let n = 0;
  for (const item of items) {
    const val =
      typeof item === "string" || typeof item === "number"
        ? str(item)
        : item && typeof item === "object"
        ? str((item as Record<string, unknown>)["#text"])
        : null;
    if (val?.trim()) n++;
  }
  return n;
}

/** `<count>` may be a string node or `{ "#text": "5" }` from fast-xml-parser. */
function offerCountField(raw: unknown): number | null {
  if (raw == null) return null;
  if (typeof raw === "string" || typeof raw === "number") {
    const n = Number(raw);
    return Number.isFinite(n) ? Math.trunc(n) : null;
  }
  if (typeof raw === "object" && raw !== null && "#text" in raw) {
    const n = Number(str((raw as Record<string, unknown>)["#text"]));
    return Number.isFinite(n) ? Math.trunc(n) : null;
  }
  return null;
}

function main(): void {
  const opts = parseCli(Deno.args);
  const url = Deno.env.get("TILDA_YML_URL");
  if (!url) {
    console.error("TILDA_YML_URL is required");
    Deno.exit(1);
  }
  if (
    opts.offerIds.length === 0 && !opts.titleSubstring && !opts.groupFilter
  ) {
    console.error(
      "Provide at least one of: --offer=UID (repeatable), --group=, --title=",
    );
    Deno.exit(1);
  }

  const run = async () => {
    const res = await fetch(url, {
      headers: { "User-Agent": "TiffaniYmlInspect/1.0" },
      signal: AbortSignal.timeout(120_000),
    });
    if (!res.ok) {
      throw new Error(`YML fetch failed: HTTP ${res.status}`);
    }
    const xml = await res.text();
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
    if (!shop) throw new Error("Invalid YML: missing yml_catalog.shop");

    const categories = normalizeCategories(shop.categories?.category ?? []);
    const catById = new Map(categories.map((c) => [c.id, c.name]));
    const rawOffers = normalizeOffers(shop.offers?.offer ?? []);

    const report: unknown[] = [];
    const wantsOfferList = opts.offerIds.length > 0;

    for (const r of rawOffers) {
      const id = str(r["@_id"]);
      if (!id) continue;
      const groupId = str(r["@_group_id"]) || undefined;
      const name = xmlTextContent(r.name);
      const availableRaw = str(r["@_available"]);
      const available = availableRaw !== "false";

      let include = false;
      if (wantsOfferList) {
        include = opts.offerIds.includes(id);
        if (include && opts.groupFilter && groupId !== opts.groupFilter) {
          include = false;
        }
      } else if (opts.groupFilter && opts.titleSubstring) {
        include =
          groupId === opts.groupFilter &&
          (name?.toLowerCase().includes(opts.titleSubstring) ?? false);
      } else if (opts.groupFilter) {
        include = groupId === opts.groupFilter;
      } else if (opts.titleSubstring) {
        include = name?.toLowerCase().includes(opts.titleSubstring) ?? false;
      }

      if (!include) continue;

      const categoryId = xmlTextContent(r.categoryId);
      const attrs = listXmlAttributes(r);
      const known = new Set(["id", "group_id", "available", "url"]);
      const possiblyVisibility = Object.entries(attrs).filter(([k]) => {
        if (known.has(k)) return false;
        const low = k.toLowerCase();
        return (
          low.includes("available") ||
          low.includes("visib") ||
          low.includes("status") ||
          low.includes("active") ||
          low.includes("publish") ||
          low.includes("store")
        );
      });

      report.push({
        offer_id: id,
        group_id: groupId ?? null,
        present_in_yml: true,
        available_flag: available,
        available_raw: availableRaw,
        count_in_yml: offerCountField(r.count),
        name: name ?? null,
        category_id: categoryId ?? null,
        category_name: categoryId ? catById.get(categoryId) ?? null : null,
        picture_tags_count: pictureCount(r.picture),
        xml_attributes_on_offer: attrs,
        attributes_possibly_visibility_related: Object.fromEntries(possiblyVisibility),
      });
    }

    const wantedOffers = new Set(opts.offerIds);
    for (const oid of wantedOffers) {
      if (!report.some((x) => (x as { offer_id: string }).offer_id === oid)) {
        report.push({
          offer_id: oid,
          present_in_yml: false,
          note: "No matching <offer> in this YML fetch",
        });
      }
    }

    const groupUidInYml = opts.groupFilter
      ? rawOffers.some((r) => str(r["@_group_id"]) === opts.groupFilter)
      : undefined;

    console.log(JSON.stringify({
      yml_fetched_bytes: xml.length,
      group_uid_in_yml: groupUidInYml,
      offers: report,
    }, null, 2));
  };

  run().catch((e) => {
    console.error(e instanceof Error ? e.message : String(e));
    Deno.exit(1);
  });
}

main();
