import {
  assert,
  assertEquals,
} from "https://deno.land/std@0.224.0/assert/mod.ts";

import type { TildaCatalog, TildaOffer } from "./types.ts";
import { PRODUCT_ID_BATCH, upsertCatalogSlice } from "./sync-engine.ts";

/**
 * Real feed is ~1881 products and ~2901 offers. PostgREST returns at
 * most 1000 rows from `.select()` after an upsert. These stubs apply
 * that cap so a 2000-row product batch would lose ids.
 */

const API_MAX_ROWS = 1000;
const PRODUCTS = 1810;
const EXTRA_VARIANTS = 1100;

interface Call {
  table: string;
  rows: Record<string, unknown>[];
  onConflict?: string;
}

function offer(id: string, groupId: string, urls: string[]): TildaOffer {
  return {
    id,
    groupId,
    available: true,
    price: 10,
    picture: urls[0],
    pictures: urls,
    params: [],
  };
}

function scaleCatalog(): TildaCatalog {
  const offers: TildaOffer[] = [];
  for (let i = 0; i < PRODUCTS; i++) {
    const groupId = `g-${i}`;
    offers.push(offer(`v-${i}`, groupId, [
      `https://cdn/p/${i}.jpg`,
      `https://cdn/g/${i}.jpg`,
    ]));
    if (i < EXTRA_VARIANTS) {
      offers.push(offer(`v-${i}-b`, groupId, [
        `https://cdn/p/${i}-b.jpg`,
        `https://cdn/g/${i}.jpg`,
      ]));
    }
  }
  return { categories: [{ id: "c1", name: "Cat" }], offers };
}

function makeClient(selectCap: number) {
  const calls: Call[] = [];
  const mutations: string[] = [];
  const productIds = new Map<string, string>();
  let seq = 1;

  const client = {
    from(table: string) {
      return {
        upsert(
          rows: Record<string, unknown> | Record<string, unknown>[],
          opts: { onConflict?: string } = {},
        ) {
          const arr = Array.isArray(rows) ? rows : [rows];
          calls.push({ table, rows: arr, onConflict: opts.onConflict });

          let data: { id: string; tilda_uid: unknown }[] | null = null;
          if (table === "products") {
            const mapped = arr.map((row) => {
              const uid = String(row.tilda_uid);
              let id = productIds.get(uid);
              if (!id) {
                id = `pk-${seq++}`;
                productIds.set(uid, id);
              }
              return { id, tilda_uid: row.tilda_uid };
            });
            data = mapped.slice(0, selectCap);
          }

          const written = { data: null, error: null };
          return {
            select: (_cols: string) => Promise.resolve({ data, error: null }),
            then: <T>(
              resolve: (v: typeof written) => T,
              reject?: (e: unknown) => T,
            ) => Promise.resolve(written).then(resolve, reject),
          };
        },
        update() {
          mutations.push("update");
          return { in: () => Promise.resolve({ error: null }) };
        },
        delete() {
          mutations.push("delete");
          return Promise.resolve({ error: null });
        },
      };
    },
  };

  return { client, calls, mutations, productIds };
}

function rows(calls: Call[], table: string): Record<string, unknown>[] {
  return calls.filter((c) => c.table === table).flatMap((c) => c.rows);
}

Deno.test("product id batches stay under the PostgREST max-rows cap", () => {
  assertEquals(PRODUCT_ID_BATCH, 500);
  assert(PRODUCT_ID_BATCH < API_MAX_ROWS);
});

Deno.test(
  "scale upsert resolves every id when select is capped at 1000",
  async () => {
    const catalog = scaleCatalog();
    assert(catalog.offers.length > 2900);
    const groups = new Set(catalog.offers.map((o) => o.groupId ?? o.id));
    assert(groups.size > 1800);

    const { client, calls, mutations, productIds } = makeClient(API_MAX_ROWS);
    const { stats, errors } = await upsertCatalogSlice(
      // deno-lint-ignore no-explicit-any
      client as any,
      catalog,
      "run-scale",
    );

    assertEquals(errors, []);
    assertEquals(stats.products_seen, groups.size);
    assertEquals(stats.products_upserted, stats.products_seen);
    assertEquals(stats.variants_seen, catalog.offers.length);
    assertEquals(stats.variants_upserted, stats.variants_seen);
    assertEquals(stats.images_upserted, stats.images_seen);
    assert(stats.images_seen > 0);
    assertEquals(stats.error_count, 0);
    assertEquals(mutations, []);

    const productCalls = calls.filter((c) => c.table === "products");
    assert(productCalls.length > 1);
    for (const call of productCalls) {
      assert(call.rows.length <= PRODUCT_ID_BATCH);
      assert(call.rows.length <= API_MAX_ROWS);
      assertEquals(call.onConflict, "tilda_uid");
      for (const row of call.rows) {
        assertEquals(row.is_active, true);
      }
    }

    const variants = rows(calls, "product_variants");
    const byVariant = new Map(variants.map((row) => [String(row.variant_id), row]));
    assertEquals(byVariant.size, catalog.offers.length);

    const productIdByGroup = new Map<string, string>();
    for (const offer of catalog.offers) {
      const written = byVariant.get(offer.id);
      assert(written, offer.id);
      const group = offer.groupId ?? offer.id;
      const previous = productIdByGroup.get(group);
      const productId = String(written.product_id);
      if (previous) assertEquals(productId, previous);
      else productIdByGroup.set(group, productId);
      assertEquals(written.photo, offer.picture ?? null);
    }
    assertEquals(productIdByGroup.size, groups.size);

    const images = rows(calls, "product_images");
    assertEquals(images.length, stats.images_seen);
    for (const image of images) {
      const match = String(image.url).match(/\/(\d+)(?:-b)?\.jpg$/);
      assert(match, String(image.url));
      assertEquals(String(image.product_id), productIdByGroup.get(`g-${match[1]}`));
    }

    const firstCalls = calls.length;
    const firstIds = productIds.size;
    calls.length = 0;
    const again = await upsertCatalogSlice(
      // deno-lint-ignore no-explicit-any
      client as any,
      catalog,
      "run-scale-2",
    );
    assertEquals(again.errors, []);
    assertEquals(again.stats.products_upserted, stats.products_upserted);
    assertEquals(again.stats.variants_upserted, stats.variants_upserted);
    assertEquals(again.stats.images_upserted, stats.images_upserted);
    assertEquals(productIds.size, firstIds);
    assertEquals(calls.length, firstCalls);
    assertEquals(mutations, []);
  },
);

Deno.test(
  "truncated product select is an error and does not invent variant links",
  async () => {
    const offers: TildaOffer[] = [];
    for (let i = 0; i < 600; i++) {
      offers.push(offer(`v-${i}`, `g-${i}`, [`https://cdn/p/${i}.jpg`]));
    }
    const catalog: TildaCatalog = {
      categories: [],
      offers,
    };
    const { client, calls, mutations } = makeClient(100);
    const { stats, errors } = await upsertCatalogSlice(
      // deno-lint-ignore no-explicit-any
      client as any,
      catalog,
      "run-trunc",
    );

    assert(errors.some((e) => e.stage === "upsert_product_id_truncated"));
    assert(stats.products_upserted < stats.products_seen);
    assertEquals(stats.products_upserted, 200);
    assertEquals(stats.variants_upserted, 200);
    assert(stats.variants_upserted < stats.variants_seen);
    assertEquals(mutations, []);

    const resolved = new Set(
      rows(calls, "products")
        .map((row) => String(row.tilda_uid))
        .filter((uid) =>
          errors.every((e) => e.external_key !== uid)
        ),
    );
    for (const variant of rows(calls, "product_variants")) {
      assert(String(variant.product_id).startsWith("pk-"));
    }
    assertEquals(rows(calls, "product_variants").length, resolved.size);
  },
);
