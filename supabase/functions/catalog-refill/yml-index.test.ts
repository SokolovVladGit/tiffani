import {
  assertEquals,
  assertStrictEquals,
} from "https://deno.land/std@0.224.0/assert/mod.ts";

import type { TildaCatalog } from "../catalog-sync/types.ts";
import { buildYmlIndex, lookupUid } from "./yml-index.ts";

// Fixture group IDs are numeric 12-digit strings to mirror real Tilda shape
// (YML @_group_id is numeric in the live feed).
const GROUP_A = "900000000001";
const GROUP_B = "900000000002";

function catalog(): TildaCatalog {
  return {
    categories: [
      { id: "c1", name: "Category A" },
      { id: "c2", name: "Category B" },
    ],
    offers: [
      { id: "111111111111", groupId: GROUP_A, available: true, params: [] },
      { id: "222222222222", groupId: GROUP_A, available: true, params: [] },
      { id: "333333333333", available: true, params: [] },
      { id: "444444444444", groupId: GROUP_B, available: true, params: [] },
    ],
  };
}

Deno.test("buildYmlIndex counts offers, groups and categories", () => {
  const idx = buildYmlIndex(catalog());
  assertEquals(idx.offersCount, 4);
  assertEquals(idx.groupsCount, 2);
  assertEquals(idx.categoriesCount, 2);
  assertEquals(idx.byOfferId.size, 4);
});

Deno.test("buildYmlIndex groups multiple offers under the same group_id", () => {
  const idx = buildYmlIndex(catalog());
  const groupA = idx.byGroupId.get(GROUP_A);
  assertEquals(groupA?.length, 2);
  assertEquals(
    groupA!.map((o) => o.id).sort(),
    ["111111111111", "222222222222"],
  );
});

Deno.test("lookupUid resolves offer UID", () => {
  const idx = buildYmlIndex(catalog());
  const r = lookupUid(idx, "111111111111");
  assertEquals(r.offer?.id, "111111111111");
  assertStrictEquals(r.groupOffers, undefined);
});

Deno.test("lookupUid resolves group UID", () => {
  const idx = buildYmlIndex(catalog());
  const r = lookupUid(idx, GROUP_A);
  assertStrictEquals(r.offer, undefined);
  assertEquals(r.groupOffers?.length, 2);
});

Deno.test("lookupUid returns both undefined for unknown UID", () => {
  const idx = buildYmlIndex(catalog());
  const r = lookupUid(idx, "NOT_A_REAL_UID");
  assertStrictEquals(r.offer, undefined);
  assertStrictEquals(r.groupOffers, undefined);
});

Deno.test("buildYmlIndex tolerates offers without group_id", () => {
  const idx = buildYmlIndex(catalog());
  const orphan = lookupUid(idx, "333333333333");
  assertEquals(orphan.offer?.id, "333333333333");
  assertStrictEquals(orphan.groupOffers, undefined);
});
