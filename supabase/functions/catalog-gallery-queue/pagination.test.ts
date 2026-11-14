import { assert, assertEquals, assertRejects, assertThrows } from "https://deno.land/std@0.224.0/assert/mod.ts";
import { handleQueueRequest } from "./index.ts";
import { MemoryQueueStore } from "./memory-store.ts";
import { HISTORICAL_AMBIGUOUS, HISTORICAL_NO_EXTRA } from "./historical.ts";
import type { CatalogCandidate, QueueItem } from "./model.ts";
import { bootstrap, propose, UPSERT_CHUNK } from "./workflow.ts";
import {
  assertCountMatches,
  assertUniqueIdentities,
  PAGE_SIZE,
  readOrderedPages,
} from "./supabase-store.ts";

const PRIMARY =
  "https://static.tildacdn.com/stor3031-6534-4332-a331-366138303634/dc00819f51e0b7e83aec82ff9301564d.png";
const POSTGREST_MAX = 1000;

function candidate(uid: string, patch: Partial<CatalogCandidate> = {}): CatalogCandidate {
  return {
    productId: `product-${uid}`,
    tildaUid: uid,
    variantCount: 1,
    ymlImageCount: 1,
    galleryImageCount: 0,
    galleryUrls: [],
    primaryUrl: PRIMARY,
    primaryMatches: true,
    hidden: false,
    ...patch,
  };
}

function capped<T>(rows: T[], max = POSTGREST_MAX) {
  return (from: number, to: number): Promise<T[]> => {
    const requested = rows.slice(from, to + 1);
    return Promise.resolve(requested.slice(0, max));
  };
}

function uid(index: number): string {
  return String(index).padStart(12, "0");
}

Deno.test("paged reads cross the 1000 row cap without dropping the tail", async () => {
  for (const count of [999, 1000, 1001, 1883, 2500]) {
    const rows = Array.from({ length: count }, (_, index) => ({ tilda_uid: uid(index + 1) }));
    const loaded = await readOrderedPages(capped(rows), (row) => row.tilda_uid);
    assertEquals(loaded.length, count);
    assertEquals(loaded[0].tilda_uid, uid(1));
    assertEquals(loaded[count - 1].tilda_uid, uid(count));
    assertEquals(loaded[count - 1].tilda_uid, rows[count - 1].tilda_uid);
  }
});

Deno.test("queue item pages stay ordered and keep a 20 digit uid exact", async () => {
  const wide = "9223372036854775808";
  const padded = "00000000000000000042";
  const lexicalBefore = "1000000000000";
  const lexicalAfter = "999999999999";
  const rows = [
    lexicalBefore,
    padded,
    wide,
    lexicalAfter,
    ...Array.from({ length: 1595 }, (_, index) => uid(index + 1)),
  ].sort().map((tildaUid, index) => ({ productId: `p-${index}`, tildaUid }));
  const loaded = await readOrderedPages(capped(rows), (row) => row.tildaUid);
  assertEquals(loaded.length, 1599);
  assertEquals(loaded.map((row) => row.tildaUid), rows.map((row) => row.tildaUid));
  assert(loaded.some((row) => row.tildaUid === wide));
  assert(loaded.some((row) => row.tildaUid === padded));
  const before = loaded.findIndex((row) => row.tildaUid === lexicalBefore);
  const after = loaded.findIndex((row) => row.tildaUid === lexicalAfter);
  assert(before >= 0 && before < after);
  assert(PAGE_SIZE < POSTGREST_MAX);
  const boundary = loaded[PAGE_SIZE - 1].tildaUid < loaded[PAGE_SIZE].tildaUid;
  assert(boundary);
});

Deno.test("duplicate identities and a broken page are rejected", async () => {
  const duplicatedUid = [
    { productId: "a", tildaUid: "000000000001" },
    { productId: "b", tildaUid: "000000000001" },
  ];
  await assertRejects(
    () => readOrderedPages(capped(duplicatedUid), (row) => row.tildaUid),
    Error,
    "page_not_ordered",
  );
  assertThrows(
    () => assertUniqueIdentities([
      { productId: "same", tildaUid: "000000000001" },
      { productId: "same", tildaUid: "000000000002" },
    ]),
    Error,
    "duplicate_product_id",
  );
  const rows = Array.from({ length: 1500 }, (_, index) => ({ tilda_uid: uid(index + 1) }));
  await assertRejects(
    () => readOrderedPages(
      (from, to) => {
        if (from === PAGE_SIZE * 2) return Promise.reject(new Error("page_failed"));
        return capped(rows)(from, to);
      },
      (row) => row.tilda_uid,
    ),
    Error,
    "page_failed",
  );
  const truncated = await readOrderedPages(
    (from, to) => from >= POSTGREST_MAX ? Promise.resolve([]) : capped(rows, POSTGREST_MAX)(from, to),
    (row) => row.tilda_uid,
  );
  assertEquals(truncated.length, POSTGREST_MAX);
  assertThrows(
    () => assertCountMatches(truncated.length, rows.length, "snapshot"),
    Error,
    "snapshot_incomplete:1000/1500",
  );
  assertThrows(
    () => assertCountMatches(10, null, "snapshot"),
    Error,
    "snapshot_count_unavailable",
  );
});

Deno.test("a short snapshot fails before any queue upsert", async () => {
  const store = new MemoryQueueStore();
  store.loadCandidates = () => Promise.reject(new Error("snapshot_incomplete:1000/1883"));
  let saved = 0;
  store.saveItems = (items) => {
    saved += items.length;
    return Promise.resolve();
  };
  await assertRejects(() => bootstrap(store), Error, "snapshot_incomplete:1000/1883");
  assertEquals(saved, 0);
  assertEquals(store.items.length, 0);
  assertEquals(store.runs[0]?.status, "failed");
  assertEquals(store.runs.some((run) => run.status === "completed"), false);
});

Deno.test("repeated bootstrap of 1883 rows preserves completed, no_extra, and ambiguous", async () => {
  const store = new MemoryQueueStore();
  const reserved = new Set<string>([...HISTORICAL_NO_EXTRA, ...HISTORICAL_AMBIGUOUS]);
  const fresh: string[] = [];
  for (let index = 1; fresh.length < 284 + 19 + 1557; index++) {
    const value = uid(index);
    if (reserved.has(value)) continue;
    fresh.push(value);
  }
  const multi = fresh.slice(0, 284).map((value) =>
    candidate(value, { variantCount: 16, ymlImageCount: 16, primaryMatches: false })
  );
  const gallery = fresh.slice(284, 303).map((value) =>
    candidate(value, { galleryImageCount: 2, galleryUrls: [PRIMARY] })
  );
  const pending = fresh.slice(303).map((value, index) => candidate(value, { hidden: index === 0 }));
  store.candidates = [
    ...multi,
    ...gallery,
    ...HISTORICAL_NO_EXTRA.map((value) => candidate(value)),
    candidate(HISTORICAL_AMBIGUOUS[0]),
    ...pending,
  ];
  assertEquals(store.candidates.length, 1883);
  const first = await bootstrap(store);
  assertEquals(first.snapshotRows, 1883);
  assertEquals(first.queueRows, 1599);
  assertEquals(first.counts, {
    completed: 19,
    no_extra: 22,
    ambiguous: 1,
    pending: 1557,
  });
  assertEquals(store.items.some((item) => item.tildaUid === multi[0].tildaUid), false);
  const completed = store.items.find((item) => item.tildaUid === gallery[0].tildaUid)!;
  const deferred = store.items.find((item) => item.tildaUid === HISTORICAL_NO_EXTRA[0])!;
  const ambiguous = store.items.find((item) => item.tildaUid === HISTORICAL_AMBIGUOUS[0])!;
  completed.lastError = "keep-completed";
  deferred.nextCheckAt = "2030-01-01T00:00:00.000Z";
  ambiguous.nextCheckAt = "2031-01-01T00:00:00.000Z";
  const second = await bootstrap(store);
  assertEquals(second.queueRows, 1599);
  assertEquals(second.counts, first.counts);
  assertEquals(store.items.filter((item) => item.tildaUid === gallery[0].tildaUid), [completed]);
  assertEquals(store.items.find((item) => item.tildaUid === HISTORICAL_NO_EXTRA[0])?.nextCheckAt, deferred.nextCheckAt);
  assertEquals(store.items.find((item) => item.tildaUid === HISTORICAL_AMBIGUOUS[0])?.status, "ambiguous");
  assertEquals(store.items.find((item) => item.tildaUid === HISTORICAL_AMBIGUOUS[0])?.nextCheckAt, ambiguous.nextCheckAt);
  assertEquals(store.runs.filter((run) => run.mode === "bootstrap" && run.status === "completed").length, 2);
});

Deno.test("a failed middle upsert does not report success and the next bootstrap continues", async () => {
  const store = new MemoryQueueStore();
  store.candidates = Array.from({ length: UPSERT_CHUNK + 20 }, (_, index) => candidate(uid(index + 1)));
  const seen: number[] = [];
  let fail = true;
  const original = store.saveItems.bind(store);
  store.saveItems = (items: QueueItem[]) => {
    seen.push(items.length);
    if (fail && seen.length === 2) {
      fail = false;
      return Promise.reject(new Error("chunk_failed"));
    }
    return original(items);
  };
  await assertRejects(() => bootstrap(store), Error, "chunk_failed");
  assertEquals(seen.slice(0, 2), [UPSERT_CHUNK, 20]);
  assertEquals(store.items.length, UPSERT_CHUNK);
  assertEquals(store.runs[0]?.status, "failed");
  const again = await bootstrap(store);
  assertEquals(again.queueRows, UPSERT_CHUNK + 20);
  assertEquals(again.counts.pending, UPSERT_CHUNK + 20);
  assertEquals(store.items.length, UPSERT_CHUNK + 20);
  assertEquals(store.runs.at(-1)?.status, "completed");
});

Deno.test("stats and propose see a ready row past the first thousand", async () => {
  const store = new MemoryQueueStore();
  store.candidates = Array.from({ length: 1599 }, (_, index) => candidate(uid(index + 1)));
  await bootstrap(store);
  const late = store.items[1500];
  late.status = "ready_for_review";
  late.expectedNewImageCount = 2;
  const response = await handleQueueRequest(new Request("https://queue.local", {
    method: "POST",
    body: JSON.stringify({ mode: "stats" }),
  }), {
    authorize: () => Promise.resolve({ ok: true, kind: "admin", userId: "admin" }),
    store,
  });
  const body = await response.json();
  assertEquals(body.counts.pending, 1598);
  assertEquals(body.counts.ready_for_review, 1);
  assertEquals(body.writes, 0);
  const proposed = await propose(store);
  assertEquals(proposed.allowlist, [late.tildaUid]);
  assertEquals(proposed.expected[late.tildaUid], 2);
});

Deno.test("the hosted store pages both reads and does not touch catalog tables", async () => {
  const source = await Deno.readTextFile(new URL("./supabase-store.ts", import.meta.url));
  assert(source.includes("readOrderedPages"));
  assert(source.includes('order("tilda_uid", { ascending: true })'));
  assert(source.includes("PAGE_SIZE"));
  assert(source.includes('count: "exact"'));
  assertEquals(source.includes('from("products")'), false);
  assertEquals(source.includes('from("product_images")'), false);
  assertEquals(source.includes('from("product_variants")'), false);
  assertEquals(source.includes("Number(row.tilda_uid"), false);
});
