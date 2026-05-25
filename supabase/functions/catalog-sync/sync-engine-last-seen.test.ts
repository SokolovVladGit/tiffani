import {
  assertEquals,
  assert,
} from "https://deno.land/std@0.224.0/assert/mod.ts";

import type { TildaCatalog } from "./types.ts";
import { upsertCatalogSlice } from "./sync-engine.ts";

interface UpsertCall {
  table: string;
  rows: Record<string, unknown>[];
}

function makeStubClient() {
  const calls: UpsertCall[] = [];
  let nextProductPk = 1;

  const client = {
    from(table: string) {
      return {
        upsert(
          rows: Record<string, unknown> | Record<string, unknown>[],
          opts:  Record<string, unknown> = {},
        ) {
          const arr = Array.isArray(rows) ? rows : [rows];
          calls.push({ table, rows: arr });
          void opts.onConflict;

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

const MINIMAL: TildaCatalog = {
  categories: [{ id: "c1", name: "Cat" }],
  offers: [
    {
      id: "V1",
      groupId: "G1",
      available: true,
      categoryId: "c1",
      params: [],
    },
  ],
};

Deno.test(
  "upsertCatalogSlice includes last_seen_in_yml when syncSeenAt is passed",
  async () => {
    const { client, calls } = makeStubClient();
    const ts = "2026-05-09T10:00:00.000Z";
    // deno-lint-ignore no-explicit-any
    await upsertCatalogSlice(client as any, MINIMAL, "run-ts", {
      syncSeenAt: ts,
    });

    const prod = calls.find((c) => c.table === "products");
    const varCalls = calls.filter((c) => c.table === "product_variants");
    assert(prod, "products upsert");
    assertEquals(prod!.rows[0].last_seen_in_yml, ts);
    assert(varCalls.length > 0, "variants upsert");
    assertEquals(varCalls[0].rows[0].last_seen_in_yml, ts);
  },
);

Deno.test(
  "upsertCatalogSlice omits last_seen_in_yml when syncSeenAt is omitted",
  async () => {
    const { client, calls } = makeStubClient();
    // deno-lint-ignore no-explicit-any
    await upsertCatalogSlice(client as any, MINIMAL, "run-nots");

    const prod = calls.find((c) => c.table === "products");
    const varCalls = calls.filter((c) => c.table === "product_variants");
    assert(prod);
    assert(!("last_seen_in_yml" in prod!.rows[0]));
    assert(varCalls.length > 0);
    assert(!("last_seen_in_yml" in varCalls[0].rows[0]));
  },
);
