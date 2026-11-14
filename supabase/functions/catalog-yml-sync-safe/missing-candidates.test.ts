import {
  assert,
  assertEquals,
  assertRejects,
} from "https://deno.land/std@0.224.0/assert/mod.ts";

import type { TildaCatalog } from "../catalog-sync/types.ts";
import {
  collectYmlKeys,
  computeMissingCandidates,
  MISSING_CANDIDATES_PAGE_SIZE,
} from "./missing-candidates.ts";

/**
 * collectYmlKeys is a pure helper used by the missing-candidates
 * diff. These tests pin its behavior so future YML shape changes
 * cannot silently weaken the safe-sync invariant.
 */

const CATALOG: TildaCatalog = {
  categories: [{ id: "c1", name: "A" }],
  offers: [
    { id: "1001", groupId: "G1", available: true, params: [] },
    { id: "1002", groupId: "G1", available: true, params: [] },
    { id: "1003", available: true, params: [] },
  ],
};

Deno.test("collectYmlKeys returns union of offer ids and group ids", () => {
  const keys = collectYmlKeys(CATALOG);
  assertEquals(keys.size, 4);
  assert(keys.has("1001"));
  assert(keys.has("1002"));
  assert(keys.has("1003"));
  assert(keys.has("G1"));
});

Deno.test("collectYmlKeys is empty for empty catalog", () => {
  const keys = collectYmlKeys({ categories: [], offers: [] });
  assertEquals(keys.size, 0);
});

/**
 * Lightweight stand-in for the Supabase service-role client. It
 * implements only the chain `from(...).select(...).eq(...).not(...)
 * .range(...)` and asserts that no mutating method is ever called.
 *
 * If `computeMissingCandidates` ever attempted to issue an UPDATE
 * or DELETE the test would throw at the access site, providing a
 * runtime safety net in addition to the structural test.
 */
type StubRow = { tilda_uid: string };

function makeStubClient(rows: StubRow[]) {
  const calls: { from: string; eq: unknown; not: unknown[] }[] = [];

  function trap(name: string) {
    return () => {
      throw new Error(
        `forbidden mutation: missing-candidates called ${name}`,
      );
    };
  }

  const client = {
    from(table: string) {
      calls.push({ from: table, eq: null, not: [] });
      const last = calls[calls.length - 1];
      const builder = {
        select(_cols: string) {
          return builder;
        },
        eq(col: string, val: unknown) {
          last.eq = { col, val };
          return builder;
        },
        not(col: string, op: string, val: unknown) {
          last.not.push({ col, op, val });
          return builder;
        },
        range(from: number, to: number) {
          const slice = rows.slice(from, to + 1);
          return Promise.resolve({
            data: slice,
            error: null,
            count: rows.length,
          });
        },
        update: trap("update"),
        delete: trap("delete"),
        upsert: trap("upsert"),
        insert: trap("insert"),
      };
      return builder;
    },
  };

  return { client, calls };
}

Deno.test(
  "computeMissingCandidates returns zero when YML covers every active uid",
  async () => {
    const rows: StubRow[] = [
      { tilda_uid: "1001" },
      { tilda_uid: "1002" },
      { tilda_uid: "G1" },
    ];
    const { client, calls } = makeStubClient(rows);

    // deno-lint-ignore no-explicit-any
    const result = await computeMissingCandidates(client as any, CATALOG, 20);

    assertEquals(result.active_products_with_tilda_uid_in_db, 3);
    assertEquals(result.absent_from_current_yml, 0);
    assertEquals(result.sample, []);
    assertEquals(result.action_taken, "none");
    assertEquals(calls[0].from, "products");
    assertEquals(calls[0].eq, { col: "is_active", val: true });
  },
);

Deno.test(
  "computeMissingCandidates flags uids absent from the YML",
  async () => {
    const rows: StubRow[] = [
      { tilda_uid: "1001" },
      { tilda_uid: "GHOST_1" },
      { tilda_uid: "GHOST_2" },
      { tilda_uid: "G1" },
    ];
    const { client } = makeStubClient(rows);

    // deno-lint-ignore no-explicit-any
    const result = await computeMissingCandidates(client as any, CATALOG, 20);

    assertEquals(result.active_products_with_tilda_uid_in_db, 4);
    assertEquals(result.absent_from_current_yml, 2);
    assertEquals(result.sample.sort(), ["GHOST_1", "GHOST_2"]);
    assertEquals(result.action_taken, "none");
  },
);

Deno.test(
  "computeMissingCandidates respects the sampleLimit cap",
  async () => {
    const rows: StubRow[] = Array.from({ length: 25 }, (_, i) => ({
      tilda_uid: `GHOST_${i.toString().padStart(2, "0")}`,
    }));
    const { client } = makeStubClient(rows);

    // deno-lint-ignore no-explicit-any
    const result = await computeMissingCandidates(client as any, CATALOG, 5);

    assertEquals(result.active_products_with_tilda_uid_in_db, 25);
    assertEquals(result.absent_from_current_yml, 25);
    assertEquals(result.sample.length, 5);
  },
);

Deno.test(
  "computeMissingCandidates filter chain is admin-product-safe",
  async () => {
    const rows: StubRow[] = [{ tilda_uid: "1001" }];
    const { client, calls } = makeStubClient(rows);

    // deno-lint-ignore no-explicit-any
    await computeMissingCandidates(client as any, CATALOG, 20);

    const filters = calls[0].not as { col: string; op: string }[];
    const hasNotNullTildaUid = filters.some(
      (f) => f.col === "tilda_uid" && f.op === "is",
    );
    assert(
      hasNotNullTildaUid,
      "must apply .not('tilda_uid', 'is', null) to exclude admin products",
    );
  },
);

Deno.test("missing-candidates page size stays under the 1000 row cap", () => {
  assertEquals(MISSING_CANDIDATES_PAGE_SIZE, 500);
  assert(MISSING_CANDIDATES_PAGE_SIZE <= 1000);
});

Deno.test(
  "missing-candidates pages through more than 1800 rows when the API caps at 1000",
  async () => {
    const rows: StubRow[] = Array.from({ length: 1850 }, (_, i) => ({
      tilda_uid: `p-${i}`,
    }));
    const ranges: Array<[number, number]> = [];
    const client = {
      from() {
        const builder = {
          select() {
            return builder;
          },
          eq() {
            return builder;
          },
          not() {
            return builder;
          },
          range(from: number, to: number) {
            ranges.push([from, to]);
            const requested = rows.slice(from, to + 1);
            const capped = requested.slice(0, 1000);
            return Promise.resolve({
              data: capped,
              error: null,
              count: rows.length,
            });
          },
          update() {
            throw new Error("forbidden mutation: update");
          },
          delete() {
            throw new Error("forbidden mutation: delete");
          },
          upsert() {
            throw new Error("forbidden mutation: upsert");
          },
          insert() {
            throw new Error("forbidden mutation: insert");
          },
        };
        return builder;
      },
    };

    const result = await computeMissingCandidates(
      // deno-lint-ignore no-explicit-any
      client as any,
      { categories: [], offers: [] },
      3,
    );

    assertEquals(result.active_products_with_tilda_uid_in_db, 1850);
    assertEquals(result.absent_from_current_yml, 1850);
    assertEquals(result.sample.length, 3);
    assertEquals(result.action_taken, "none");
    assert(ranges.length > 1);
    for (const [from, to] of ranges) {
      assert(to - from + 1 <= MISSING_CANDIDATES_PAGE_SIZE);
    }
    const seen = ranges.reduce((n, [from, to]) => {
      return n + rows.slice(from, to + 1).length;
    }, 0);
    assertEquals(seen, rows.length);
  },
);

Deno.test(
  "missing-candidates rejects a short page that is not the full count",
  async () => {
    const rows: StubRow[] = Array.from({ length: 1850 }, (_, i) => ({
      tilda_uid: `p-${i}`,
    }));
    const client = {
      from() {
        const builder = {
          select() {
            return builder;
          },
          eq() {
            return builder;
          },
          not() {
            return builder;
          },
          range() {
            return Promise.resolve({
              data: rows.slice(0, 100),
              error: null,
              count: rows.length,
            });
          },
        };
        return builder;
      },
    };

    await assertRejects(
      () =>
        computeMissingCandidates(
          // deno-lint-ignore no-explicit-any
          client as any,
          { categories: [], offers: [] },
          5,
        ),
      Error,
      "truncated",
    );
  },
);
