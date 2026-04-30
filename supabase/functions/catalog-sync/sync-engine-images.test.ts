import {
  assertEquals,
  assert,
} from "https://deno.land/std@0.224.0/assert/mod.ts";

import type { TildaCatalog } from "./types.ts";
import { upsertCatalogSlice } from "./sync-engine.ts";

/**
 * Verifies the multi-image behavior of `upsertCatalogSlice` end-to-end
 * against an in-memory stub Supabase client. The stub records every
 * upsert payload so the test can assert on:
 *   - product_images receives one row per distinct picture URL,
 *   - per-product positions start at 0 and increment monotonically,
 *   - duplicate URLs across offers of the same product are collapsed,
 *   - no row is ever written with `is_active: false`,
 *   - product_variants.photo and products.photo remain the canonical
 *     first picture (backward compatibility).
 */

interface UpsertCall {
  table: string;
  rows: Record<string, unknown>[];
  onConflict?: string;
}

function makeStubClient() {
  const calls: UpsertCall[] = [];
  let nextProductPk = 1;

  const client = {
    from(table: string) {
      return {
        upsert(
          rows: Record<string, unknown> | Record<string, unknown>[],
          opts: { onConflict?: string } = {},
        ) {
          const arr = Array.isArray(rows) ? rows : [rows];
          calls.push({ table, rows: arr, onConflict: opts.onConflict });

          const upsertResult = { data: null, error: null } as const;
          const selectResult = table === "products"
            ? {
              data: arr.map((row) => ({
                id: `pk-${nextProductPk++}`,
                tilda_uid: row.tilda_uid,
              })),
              error: null,
            }
            : { data: null, error: null };

          // Thenable so `await client.from(t).upsert(...)` resolves
          // directly (used by variant + image upserts that don't
          // chain `.select(...)`).
          return {
            select: (_cols: string) => Promise.resolve(selectResult),
            then: <T>(
              resolve: (v: typeof upsertResult) => T,
              reject?: (e: unknown) => T,
            ) => Promise.resolve(upsertResult).then(resolve, reject),
          };
        },
      };
    },
  };

  return { client, calls };
}

const CATALOG: TildaCatalog = {
  categories: [{ id: "c1", name: "Cat" }],
  offers: [
    {
      id: "V1",
      groupId: "G1",
      available: true,
      categoryId: "c1",
      picture: "https://cdn/main.jpg",
      pictures: [
        "https://cdn/main.jpg",
        "https://cdn/g1.jpg",
        "https://cdn/g2.jpg",
      ],
      params: [],
    },
    {
      id: "V2",
      groupId: "G1",
      available: true,
      categoryId: "c1",
      picture: "https://cdn/v2.jpg",
      pictures: [
        "https://cdn/v2.jpg",
        "https://cdn/g1.jpg",
      ],
      params: [],
    },
    {
      id: "V3",
      groupId: "G2",
      available: true,
      categoryId: "c1",
      picture: "https://cdn/solo.jpg",
      pictures: [],
      params: [],
    },
  ],
};

Deno.test(
  "upsertCatalogSlice writes every distinct picture per product with stable positions",
  async () => {
    const { client, calls } = makeStubClient();
    // deno-lint-ignore no-explicit-any
    const { stats, errors } = await upsertCatalogSlice(client as any, CATALOG, "run-1");

    assertEquals(errors.length, 0, JSON.stringify(errors));

    const imageCalls = calls.filter((c) => c.table === "product_images");
    assert(imageCalls.length > 0, "expected product_images upsert calls");

    const flat = imageCalls.flatMap((c) =>
      c.rows.map((r) => ({
        product_id: String(r.product_id),
        url: String(r.url),
        position: Number(r.position),
      }))
    );

    const productIds = [...new Set(flat.map((r) => r.product_id))];
    assertEquals(productIds.length, 2, "two distinct products expected");

    for (const pid of productIds) {
      const rows = flat.filter((r) => r.product_id === pid);
      const urls = rows.map((r) => r.url);
      assertEquals(
        urls.length,
        new Set(urls).size,
        `duplicate URLs detected for product ${pid}`,
      );
      const positions = rows.map((r) => r.position).sort((a, b) => a - b);
      const expected = positions.map((_, i) => i);
      assertEquals(
        positions,
        expected,
        `positions for product ${pid} must be 0..N-1`,
      );
    }

    // Group G1 (covers V1 + V2): main, g1, g2, v2  -> 4 distinct urls
    const g1Rows = flat.filter((r) => {
      const matches = imageCalls.find((c) =>
        c.rows.some((x) =>
          String(x.product_id) === r.product_id &&
          String(x.url) === "https://cdn/main.jpg"
        )
      );
      return Boolean(matches);
    });
    const g1ProductId = g1Rows[0]?.product_id;
    if (g1ProductId) {
      const urls = flat
        .filter((r) => r.product_id === g1ProductId)
        .map((r) => r.url)
        .sort();
      assertEquals(
        urls,
        [
          "https://cdn/g1.jpg",
          "https://cdn/g2.jpg",
          "https://cdn/main.jpg",
          "https://cdn/v2.jpg",
        ],
      );
    }

    assertEquals(stats.products_upserted, 2);
    assertEquals(stats.variants_upserted, 3);
    assert(stats.images_upserted >= 5, "expected at least 5 distinct images");
  },
);

Deno.test(
  "upsertCatalogSlice never writes is_active: false",
  async () => {
    const { client, calls } = makeStubClient();
    // deno-lint-ignore no-explicit-any
    await upsertCatalogSlice(client as any, CATALOG, "run-2");

    for (const call of calls) {
      for (const row of call.rows) {
        if ("is_active" in row) {
          assertEquals(
            row.is_active,
            true,
            `row in ${call.table} must never set is_active=false`,
          );
        }
      }
    }
  },
);

Deno.test(
  "upsertCatalogSlice keeps the first picture as canonical product/variant photo",
  async () => {
    const { client, calls } = makeStubClient();
    // deno-lint-ignore no-explicit-any
    await upsertCatalogSlice(client as any, CATALOG, "run-3");

    const productCalls = calls.filter((c) => c.table === "products");
    const variantCalls = calls.filter((c) => c.table === "product_variants");

    const productPhotos = productCalls.flatMap((c) =>
      c.rows.map((r) => r.photo)
    );
    assert(
      productPhotos.includes("https://cdn/main.jpg"),
      "products.photo must equal the first picture for the representative offer",
    );

    const variantPhotos = variantCalls.flatMap((c) =>
      c.rows.map((r) => ({ id: r.variant_id, photo: r.photo }))
    );
    const v1 = variantPhotos.find((v) => v.id === "V1");
    const v3 = variantPhotos.find((v) => v.id === "V3");
    assertEquals(v1?.photo, "https://cdn/main.jpg");
    assertEquals(v3?.photo, "https://cdn/solo.jpg");
  },
);

Deno.test(
  "upsertCatalogSlice falls back to legacy single picture when pictures array is absent",
  async () => {
    const legacyCatalog: TildaCatalog = {
      categories: [{ id: "c1", name: "Cat" }],
      offers: [
        {
          id: "L1",
          groupId: "GL",
          available: true,
          categoryId: "c1",
          picture: "https://cdn/legacy.jpg",
          // pictures intentionally omitted (back-compat shape)
          params: [],
        },
      ],
    };

    const { client, calls } = makeStubClient();
    // deno-lint-ignore no-explicit-any
    await upsertCatalogSlice(client as any, legacyCatalog, "run-4");

    const imageRows = calls
      .filter((c) => c.table === "product_images")
      .flatMap((c) => c.rows);
    assertEquals(imageRows.length, 1);
    assertEquals(imageRows[0].url, "https://cdn/legacy.jpg");
    assertEquals(imageRows[0].position, 0);
  },
);
