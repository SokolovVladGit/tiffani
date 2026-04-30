import {
  assertEquals,
  assertStrictEquals,
} from "https://deno.land/std@0.224.0/assert/mod.ts";

import type { TildaCatalog } from "../catalog-sync/types.ts";
import type { RefillConfig } from "./config.ts";
import type { UidClassification } from "./types.ts";
import type { ProbeResult } from "./tproduct-probe.ts";
import { buildYmlIndex } from "./yml-index.ts";
import { classifyUids, summarize } from "./classifier.ts";

const CONFIG: RefillConfig = {
  tildaYmlUrl: "https://example.invalid/yml",
  requestTimeoutMs: 1_000,
  userAgent: "test/1.0",
  probeConcurrency: 2,
  tproductBaseUrl: "https://example.invalid",
  sampleLimitPerBucket: 10,
  maxUidsPerRequest: 2_000,
};

const GROUP_A = "900000000001";
const GROUP_B = "900000000002";

const CATALOG: TildaCatalog = {
  categories: [],
  offers: [
    { id: "111111111111", groupId: GROUP_A, available: true, params: [] },
    { id: "222222222222", groupId: GROUP_A, available: true, params: [] },
    { id: "444444444444", groupId: GROUP_B, available: true, params: [] },
  ],
};

Deno.test("YML-only resolution does not trigger the probe", async () => {
  const idx = buildYmlIndex(CATALOG);
  const probe = () => {
    throw new Error("probe must not be called");
  };
  const results = await classifyUids(
    ["111111111111", GROUP_A, "not-a-uid"],
    idx,
    CONFIG,
    { probe },
  );
  assertEquals(results.map((r) => r.bucket), [
    "found_in_yml_offer",
    "found_in_yml_group",
    "invalid_uid",
  ]);
  assertEquals(results[1].variants_count, 2);
  assertEquals(results[0].offer_id, "111111111111");
  assertEquals(results[0].group_id, GROUP_A);
});

Deno.test("YML misses are routed to probe and classified by outcome", async () => {
  const idx = buildYmlIndex(CATALOG);
  const probe = (uid: string): Promise<ProbeResult> => {
    if (uid === "999000000001") {
      return Promise.resolve({
        status: "ok",
        http_status: 200,
        product: {
          uid: "999000000001",
          parentuid: "888000000001",
          title: "sanitized",
        },
      });
    }
    if (uid === "999000000002") {
      return Promise.resolve({ status: "not_found", http_status: 404 });
    }
    if (uid === "999000000003") {
      return Promise.resolve({ status: "fetch_error", message: "boom" });
    }
    return Promise.resolve({
      status: "parse_error",
      http_status: 200,
      message: "malformed",
    });
  };

  const results = await classifyUids(
    ["999000000001", "999000000002", "999000000003", "999000000004"],
    idx,
    CONFIG,
    { probe },
  );

  assertEquals(results.map((r) => r.bucket), [
    "needs_manual_review",
    "tilda_gone",
    "probe_error",
    "probe_error",
  ]);
  assertEquals(results[0].probe?.parent_uid, "888000000001");
  assertEquals(results[0].probe?.title_len, "sanitized".length);
});

Deno.test("input order is preserved and duplicates collapsed", async () => {
  const idx = buildYmlIndex(CATALOG);
  const results = await classifyUids(
    ["111111111111", "111111111111", GROUP_A],
    idx,
    CONFIG,
    { probe: () => Promise.reject(new Error("not used")) },
  );
  assertEquals(results.length, 2);
  assertEquals(results[0].uid, "111111111111");
  assertEquals(results[1].uid, GROUP_A);
});

Deno.test("thrown probe errors are caught and reported as probe_error", async () => {
  const idx = buildYmlIndex(CATALOG);
  const probe = () => {
    throw new Error("synchronous boom");
  };
  const results = await classifyUids(["999000099999"], idx, CONFIG, {
    probe,
  });
  assertEquals(results[0].bucket, "probe_error");
  assertEquals(results[0].probe?.status, "fetch_error");
});

Deno.test("summarize groups results by bucket and applies sample limit", () => {
  const results: UidClassification[] = [
    { uid: "a", bucket: "found_in_yml_offer" },
    { uid: "b", bucket: "found_in_yml_offer" },
    { uid: "c", bucket: "found_in_yml_offer" },
    { uid: "d", bucket: "tilda_gone" },
    { uid: "e", bucket: "invalid_uid" },
  ];
  const s = summarize(results, 2);
  assertEquals(s.counts.found_in_yml_offer, 3);
  assertEquals(s.counts.tilda_gone, 1);
  assertEquals(s.counts.invalid_uid, 1);
  assertEquals(s.counts.needs_manual_review, 0);
  assertEquals(s.samples.found_in_yml_offer?.length, 2);
  assertEquals(s.samples.tilda_gone?.length, 1);
  assertStrictEquals(s.samples.needs_manual_review, undefined);
});

Deno.test("short-and-non-numeric UIDs classify as invalid_uid; blanks dedup", async () => {
  const idx = buildYmlIndex(CATALOG);
  const results = await classifyUids(
    ["", "   ", "abc", "12345"],
    idx,
    CONFIG,
    {
      probe: () => {
        throw new Error("probe must not be called for invalid UIDs");
      },
    },
  );
  // After trimming, "" and "   " collapse to the same normalized key; dedup
  // keeps the first occurrence only. Expect 3 distinct classifications.
  assertEquals(results.length, 3);
  assertEquals(results.map((r) => r.bucket), [
    "invalid_uid",
    "invalid_uid",
    "invalid_uid",
  ]);
});
