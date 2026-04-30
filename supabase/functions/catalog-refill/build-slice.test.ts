import {
  assertEquals,
  assertStrictEquals,
} from "https://deno.land/std@0.224.0/assert/mod.ts";

import type { TildaCatalog } from "../catalog-sync/types.ts";
import { buildYmlIndex } from "./yml-index.ts";
import { buildUpsertSlice } from "./build-slice.ts";
import type { UidClassification } from "./types.ts";

const GROUP_A = "900000000001";
const GROUP_B = "900000000002";

const CATALOG: TildaCatalog = {
  categories: [
    { id: "c1", name: "Category A" },
    { id: "c2", name: "Category B" },
  ],
  offers: [
    { id: "111111111111", groupId: GROUP_A, available: true, params: [] },
    { id: "222222222222", groupId: GROUP_A, available: true, params: [] },
    { id: "333333333333", groupId: GROUP_B, available: true, params: [] },
    { id: "444444444444", available: true, params: [] },
  ],
};

Deno.test("includes offers for found_in_yml_offer bucket", () => {
  const idx = buildYmlIndex(CATALOG);
  const results: UidClassification[] = [
    {
      uid: "111111111111",
      bucket: "found_in_yml_offer",
      offer_id: "111111111111",
      group_id: GROUP_A,
    },
  ];
  const { slice, metrics } = buildUpsertSlice(results, idx, CATALOG);
  assertEquals(slice.offers.length, 1);
  assertEquals(slice.offers[0].id, "111111111111");
  assertEquals(metrics.offers_included, 1);
  assertEquals(metrics.products_included, 1);
  assertEquals(metrics.duplicates_collapsed, 0);
});

Deno.test("expands found_in_yml_group bucket into all variants", () => {
  const idx = buildYmlIndex(CATALOG);
  const results: UidClassification[] = [
    {
      uid: GROUP_A,
      bucket: "found_in_yml_group",
      group_id: GROUP_A,
      variants_count: 2,
    },
  ];
  const { slice, metrics } = buildUpsertSlice(results, idx, CATALOG);
  assertEquals(slice.offers.length, 2);
  assertEquals(metrics.products_included, 1);
  assertEquals(
    slice.offers.map((o) => o.id).sort(),
    ["111111111111", "222222222222"],
  );
});

Deno.test("skips non-upsert buckets and counts them", () => {
  const idx = buildYmlIndex(CATALOG);
  const results: UidClassification[] = [
    {
      uid: "111111111111",
      bucket: "found_in_yml_offer",
      offer_id: "111111111111",
      group_id: GROUP_A,
    },
    { uid: "999000000001", bucket: "needs_manual_review" },
    { uid: "999000000002", bucket: "tilda_gone" },
    { uid: "999000000003", bucket: "probe_error" },
    { uid: "abc", bucket: "invalid_uid" },
  ];
  const { slice, metrics } = buildUpsertSlice(results, idx, CATALOG);
  assertEquals(slice.offers.length, 1);
  assertEquals(metrics.skipped_by_bucket.needs_manual_review, 1);
  assertEquals(metrics.skipped_by_bucket.tilda_gone, 1);
  assertEquals(metrics.skipped_by_bucket.probe_error, 1);
  assertEquals(metrics.skipped_by_bucket.invalid_uid, 1);
});

Deno.test("deduplicates offers when offer UID and its group both appear", () => {
  const idx = buildYmlIndex(CATALOG);
  const results: UidClassification[] = [
    {
      uid: "111111111111",
      bucket: "found_in_yml_offer",
      offer_id: "111111111111",
      group_id: GROUP_A,
    },
    {
      uid: GROUP_A,
      bucket: "found_in_yml_group",
      group_id: GROUP_A,
      variants_count: 2,
    },
  ];
  const { slice, metrics } = buildUpsertSlice(results, idx, CATALOG);
  assertEquals(slice.offers.length, 2); // both 111 and 222 included exactly once
  assertEquals(metrics.duplicates_collapsed, 1); // 111 was also emitted by group
});

Deno.test("carries all source categories into the slice", () => {
  const idx = buildYmlIndex(CATALOG);
  const results: UidClassification[] = [
    { uid: GROUP_A, bucket: "found_in_yml_group", group_id: GROUP_A, variants_count: 2 },
  ];
  const { slice } = buildUpsertSlice(results, idx, CATALOG);
  assertEquals(slice.categories.length, CATALOG.categories.length);
});

Deno.test("unresolved classifications are counted, not upserted", () => {
  const idx = buildYmlIndex(CATALOG);
  const results: UidClassification[] = [
    {
      uid: "111111111111",
      bucket: "found_in_yml_offer",
      offer_id: "999999999999", // not present in index
    },
  ];
  const { slice, metrics } = buildUpsertSlice(results, idx, CATALOG);
  assertEquals(slice.offers.length, 0);
  assertEquals(metrics.unresolved_classifications, 1);
});

Deno.test("offer included without group_id falls back to its own id for tilda_uid key", () => {
  const idx = buildYmlIndex(CATALOG);
  const results: UidClassification[] = [
    {
      uid: "444444444444",
      bucket: "found_in_yml_offer",
      offer_id: "444444444444",
    },
  ];
  const { slice, metrics } = buildUpsertSlice(results, idx, CATALOG);
  assertEquals(slice.offers.length, 1);
  assertStrictEquals(slice.offers[0].groupId, undefined);
  assertEquals(metrics.products_included, 1);
});
