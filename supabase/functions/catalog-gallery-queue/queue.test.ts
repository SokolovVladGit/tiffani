import { assert, assertEquals } from "https://deno.land/std@0.224.0/assert/mod.ts";
import type { CatalogProductSnapshot, GalleryCatalog } from "../catalog-gallery-recover/catalog.ts";
import type { GalleryInsertRow } from "../catalog-gallery-recover/rows.ts";
import { handleQueueRequest } from "./index.ts";
import { MemoryQueueStore } from "./memory-store.ts";
import { HISTORICAL_AMBIGUOUS, HISTORICAL_NO_EXTRA } from "./historical.ts";
import type { CatalogCandidate } from "./model.ts";
import { bootstrap, executeLive, inspect, prepare, recheck } from "./workflow.ts";
import { CLAIM_TTL_MS, compareUid, iso } from "./model.ts";

const PRIMARY =
  "https://static.tildacdn.com/stor3031-6534-4332-a331-366138303634/dc00819f51e0b7e83aec82ff9301564d.png";
const PRIMARY_ONE = PRIMARY.replace("static.tildacdn.com", "static.tildacdn.one");
const EXTRA =
  "https://static.tildacdn.one/stor6162-6532-4065-b765-306635356438/60941640.png";
const EXTRA_B =
  "https://static.tildacdn.one/stor6235-6538-4761-a633-313636353133/97436353.png";

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

function html(uid: string, gallery: string[], editions = 1, pageUid = uid): string {
  const product = {
    uid: pageUid,
    gallery: gallery.map((img) => ({ img })),
    editions: Array.from({ length: editions }, () => ({ uid: "edition", img: "" })),
  };
  return `<html><script>var product = ${JSON.stringify(product)};</script></html>`;
}

function fetchPages(pages: Record<string, () => Response>): { fetch: typeof fetch; calls: string[] } {
  const calls: string[] = [];
  const fetchImpl: typeof fetch = (input) => {
    const url = String(input);
    calls.push(url);
    if (url.includes("static.tildacdn")) {
      return Promise.resolve(new Response("", {
        status: 200,
        headers: { "content-type": "image/jpeg" },
      }));
    }
    const uid = url.split("/").pop() ?? "";
    const make = pages[uid];
    return Promise.resolve(make ? make() : new Response("missing", { status: 404 }));
  };
  return { fetch: fetchImpl, calls };
}

class MemCatalog implements GalleryCatalog {
  calls = 0;
  failOn = 0;
  constructor(readonly products: Record<string, CatalogProductSnapshot>) {}

  loadProduct(tildaUid: string): Promise<CatalogProductSnapshot | null> {
    return Promise.resolve(this.products[tildaUid] ?? null);
  }

  insertGalleryImage(row: GalleryInsertRow): Promise<"inserted" | { error: string }> {
    this.calls++;
    if (this.calls === this.failOn) return Promise.resolve({ error: "statement_timeout" });
    const snapshot = Object.values(this.products).find((product) => product.id === row.product_id);
    snapshot?.images.push({ url: row.url, position: row.position, source: row.source });
    return Promise.resolve("inserted");
  }
}

function snapshot(uid: string): CatalogProductSnapshot {
  return {
    id: `product-${uid}`,
    tildaUid: uid,
    variantCount: 1,
    variantPhotoUrls: [PRIMARY],
    images: [{ url: PRIMARY, position: 0, source: "yml_variant" }],
  };
}

Deno.test("batch selection is numeric and capped at 20", async () => {
  const store = new MemoryQueueStore();
  store.candidates = Array.from({ length: 25 }, (_, index) =>
    candidate(String(130000000001 + index)));
  await bootstrap(store);
  const first = await prepare(store);
  assertEquals(first.tildaUids.length, 20);
  assertEquals(first.tildaUids[0], "130000000001");
  assertEquals(first.tildaUids[19], "130000000020");
  const claimed = await store.claim(20, "token-one");
  assertEquals(claimed.map((item) => item.tildaUid), first.tildaUids);
});

Deno.test("uid order stays exact past bigint and breaks leading-zero ties", async () => {
  const twelve = "130000000001";
  const aboveBigint = "9223372036854775808";
  const twenty = "99999999999999999999";
  const padded20 = "00000000000000000042";
  const padded18 = "000000000000000042";
  assert(compareUid(padded20, padded18) < 0);
  assert(compareUid(padded18, twelve) < 0);
  assert(compareUid(twelve, aboveBigint) < 0);
  assert(compareUid(aboveBigint, twenty) < 0);
  assertEquals(compareUid(padded20, padded20), 0);
  const store = new MemoryQueueStore();
  store.candidates = [twenty, padded18, twelve, aboveBigint, padded20].map((uid) => candidate(uid));
  await bootstrap(store);
  const claimed = await store.claim(20, "token-wide");
  assertEquals(
    claimed.map((item) => item.tildaUid),
    [padded20, padded18, twelve, aboveBigint, twenty],
  );
  const capped = new MemoryQueueStore();
  capped.candidates = Array.from({ length: 21 }, (_, index) =>
    candidate(String(index + 1).padStart(20, "0")));
  await bootstrap(capped);
  const batch = await capped.claim(20, "token-cap1");
  assertEquals(batch.length, 20);
  assertEquals(batch[0].tildaUid, "00000000000000000001");
  assertEquals(batch[19].tildaUid, "00000000000000000020");
  assertEquals(capped.items.find((item) => item.tildaUid === "00000000000000000021")?.claimToken, null);
});

Deno.test("inspect writes a running row before the page returns", async () => {
  const store = new MemoryQueueStore();
  const uid = "130000000091";
  store.candidates = [candidate(uid)];
  await bootstrap(store);
  let runningDuringFetch = false;
  const pages = fetchPages({
    [uid]: () => {
      const open = store.runs.find((run) => run.mode === "inspect");
      runningDuringFetch = open?.status === "running" &&
        open.finishedAt === null &&
        open.selectedUids.includes(uid);
      return new Response(html(uid, [PRIMARY_ONE]), { status: 200 });
    },
  });
  await inspect(store, { fetch: pages.fetch });
  assert(runningDuringFetch);
  const inspectRuns = store.runs.filter((run) => run.mode === "inspect");
  assertEquals(inspectRuns.length, 1);
  assertEquals(inspectRuns[0].status, "completed");
  assert(inspectRuns[0].finishedAt);
});

Deno.test("a dead running inspect is abandoned and a late finish does not revive it", async () => {
  const store = new MemoryQueueStore();
  store.runs.push({
    id: "dead-inspect",
    mode: "inspect",
    selectedUids: ["130000000092"],
    status: "running",
    result: {},
    errorCount: 0,
    writes: 0,
    startedAt: new Date(store.nowMs - CLAIM_TTL_MS - 1).toISOString(),
    finishedAt: null,
  }, {
    id: "fresh-inspect",
    mode: "inspect",
    selectedUids: ["130000000093"],
    status: "running",
    result: {},
    errorCount: 0,
    writes: 0,
    startedAt: iso(store.nowMs),
    finishedAt: null,
  });
  await inspect(store, { fetch: fetchPages({}).fetch });
  const dead = store.runs.find((run) => run.id === "dead-inspect");
  const fresh = store.runs.find((run) => run.id === "fresh-inspect");
  assertEquals(dead?.status, "abandoned");
  assertEquals(dead?.result.abandoned, "lease_expired");
  assert(dead?.finishedAt);
  assertEquals(fresh?.status, "running");
  assertEquals(fresh?.finishedAt, null);
  await store.finishRun("dead-inspect", {
    status: "completed",
    result: { late: true },
    errorCount: 0,
    writes: 0,
    finishedAt: iso(store.now()),
  });
  assertEquals(store.runs.find((run) => run.id === "dead-inspect")?.status, "abandoned");
});

Deno.test("completed gallery products and historical deferrals are not in the first batch", async () => {
  const store = new MemoryQueueStore();
  store.candidates = [
    candidate("100306356882"),
    candidate(HISTORICAL_AMBIGUOUS[0]),
    candidate("102955626114", { galleryImageCount: 2, galleryUrls: [EXTRA, EXTRA_B] }),
    candidate("848933724282", { variantCount: 16, ymlImageCount: 16, primaryMatches: false }),
    candidate("130000000040", { hidden: true }),
    candidate("130000000050"),
  ];
  const built = await bootstrap(store);
  assertEquals(built.writes, 0);
  assert(built.skippedHistorical.includes("101435230961"));
  assertEquals(built.skippedHistorical.includes("100306356882"), false);
  const items = await store.loadItems();
  assertEquals(items.find((item) => item.tildaUid === "100306356882")?.status, "no_extra");
  assert(Date.parse(items.find((item) => item.tildaUid === "100306356882")!.nextCheckAt!) > store.now());
  assertEquals(items.find((item) => item.tildaUid === HISTORICAL_AMBIGUOUS[0])?.status, "ambiguous");
  assert(Date.parse(items.find((item) => item.tildaUid === HISTORICAL_AMBIGUOUS[0])!.nextCheckAt!) > store.now());
  assertEquals(items.find((item) => item.tildaUid === "102955626114")?.status, "completed");
  assertEquals(items.some((item) => item.tildaUid === "848933724282"), false);
  assertEquals((await prepare(store)).tildaUids, ["130000000040", "130000000050"]);
  assertEquals(HISTORICAL_NO_EXTRA.length, 22);
});

Deno.test("historical no_extra is reinspected after next_check_at, not blacklisted", async () => {
  const store = new MemoryQueueStore();
  store.candidates = [candidate("100306356882")];
  await bootstrap(store);
  assertEquals((await store.claim(20, "token-one")).length, 0);
  store.nowMs += 8 * 24 * 60 * 60 * 1000;
  assertEquals((await store.claim(20, "token-two")).map((item) => item.tildaUid), ["100306356882"]);
});

Deno.test("website and database variant mismatch stays ambiguous", async () => {
  const store = new MemoryQueueStore();
  const uid = "130000000061";
  store.candidates = [candidate(uid)];
  await bootstrap(store);
  const pages = fetchPages({
    [uid]: () => new Response(html(uid, [PRIMARY_ONE, EXTRA], 2), { status: 200 }),
  });
  await inspect(store, { fetch: pages.fetch });
  const item = (await store.loadItems()).find((row) => row.tildaUid === uid);
  assertEquals(item?.status, "ambiguous");
  assertEquals(item?.websiteEditionCount, 2);
  assertEquals(item?.dbVariantCount, 1);
  assertEquals(item?.expectedNewImageCount, 0);
});

Deno.test("cdn alias of the primary is excluded from importable extras", async () => {
  const store = new MemoryQueueStore();
  const uid = "130000000062";
  store.candidates = [candidate(uid)];
  await bootstrap(store);
  const pages = fetchPages({
    [uid]: () => new Response(html(uid, [PRIMARY_ONE, EXTRA]), { status: 200 }),
  });
  const result = await inspect(store, { fetch: pages.fetch });
  assertEquals(result.writes, 0);
  const item = (await store.loadItems()).find((row) => row.tildaUid === uid);
  assertEquals(item?.status, "ready_for_review");
  assertEquals(item?.expectedNewImageCount, 1);
  assertEquals(item?.importableUrls, [EXTRA]);
  assertEquals(item?.importableUrls.some((url) => url.includes("dc00819f")), false);
});

Deno.test("a mismatched page uid is an ownership failure", async () => {
  const store = new MemoryQueueStore();
  const uid = "130000000063";
  store.candidates = [candidate(uid)];
  await bootstrap(store);
  const pages = fetchPages({
    [uid]: () => new Response(html(uid, [PRIMARY_ONE, EXTRA], 1, "999999999999"), { status: 200 }),
  });
  await inspect(store, { fetch: pages.fetch });
  const item = (await store.loadItems()).find((row) => row.tildaUid === uid);
  assertEquals(item?.status, "ambiguous");
  assertEquals(item?.errorClassification, "uid_mismatch");
});

Deno.test("a one-image website is no_extra and is not selected again immediately", async () => {
  const store = new MemoryQueueStore();
  const uid = "130000000080";
  store.candidates = [candidate(uid)];
  await bootstrap(store);
  const pages = fetchPages({
    [uid]: () => new Response(html(uid, [PRIMARY_ONE]), { status: 200 }),
  });
  await inspect(store, { fetch: pages.fetch });
  const item = (await store.loadItems()).find((row) => row.tildaUid === uid);
  assertEquals(item?.status, "no_extra");
  assertEquals(item?.expectedNewImageCount, 0);
  assertEquals((await store.claim(20, "token-again")).length, 0);
});

Deno.test("an empty website gallery is an error, not no_extra", async () => {
  const store = new MemoryQueueStore();
  const uid = "130000000064";
  store.candidates = [candidate(uid)];
  await bootstrap(store);
  const pages = fetchPages({
    [uid]: () => new Response(html(uid, []), { status: 200 }),
  });
  await inspect(store, { fetch: pages.fetch });
  const item = (await store.loadItems()).find((row) => row.tildaUid === uid);
  assertEquals(item?.status, "error");
  assertEquals(item?.errorClassification, "zero_gallery");
});

Deno.test("http 403 is access_denied and is not retried in the batch", async () => {
  const store = new MemoryQueueStore();
  const denied = "130000000065";
  const ok = "130000000066";
  store.candidates = [candidate(denied), candidate(ok)];
  await bootstrap(store);
  const pages = fetchPages({
    [denied]: () => new Response("no", { status: 403 }),
    [ok]: () => new Response(html(ok, [PRIMARY_ONE, EXTRA]), { status: 200 }),
  });
  await inspect(store, { fetch: pages.fetch });
  const items = await store.loadItems();
  assertEquals(items.find((item) => item.tildaUid === denied)?.status, "access_denied");
  assertEquals(items.find((item) => item.tildaUid === denied)?.retryCount, 1);
  assertEquals(items.find((item) => item.tildaUid === ok)?.status, "ready_for_review");
  assertEquals(pages.calls.filter((url) => url.endsWith(denied)).length, 1);
  assertEquals((await store.claim(20, "token-next")).length, 0);
});

Deno.test("an invalid image url blocks ready_for_review", async () => {
  const store = new MemoryQueueStore();
  const uid = "130000000067";
  store.candidates = [candidate(uid)];
  await bootstrap(store);
  const pages = fetchPages({
    [uid]: () => new Response(html(uid, [PRIMARY_ONE, "https://evil.example/a.jpg"]), { status: 200 }),
  });
  await inspect(store, { fetch: pages.fetch });
  const item = (await store.loadItems()).find((row) => row.tildaUid === uid);
  assertEquals(item?.status, "error");
  assertEquals(item?.errorClassification, "invalid_url");
});

Deno.test("a stale claim can be recovered and a fresh claim cannot", async () => {
  const store = new MemoryQueueStore();
  store.candidates = [candidate("130000000068")];
  await bootstrap(store);
  assertEquals((await store.claim(20, "token-one")).length, 1);
  store.nowMs += 1000;
  assertEquals((await store.claim(20, "token-two")).length, 0);
  store.nowMs += 16 * 60 * 1000;
  assertEquals((await store.claim(20, "token-three")).map((item) => item.tildaUid), ["130000000068"]);
});

Deno.test("concurrent claims do not take the same product", async () => {
  const store = new MemoryQueueStore();
  store.candidates = Array.from({ length: 25 }, (_, index) =>
    candidate(String(140000000001 + index)));
  await bootstrap(store);
  const [left, right] = await Promise.all([
    store.claim(20, "token-left"),
    store.claim(20, "token-right"),
  ]);
  const uids = [...left, ...right].map((item) => item.tildaUid);
  assertEquals(new Set(uids).size, 25);
  assertEquals(left.length + right.length, 25);
});

Deno.test("bootstrap does not create a second queue row", async () => {
  const store = new MemoryQueueStore();
  store.candidates = [candidate("130000000069"), candidate("100306356882")];
  await bootstrap(store);
  await bootstrap(store);
  const items = await store.loadItems();
  assertEquals(items.length, 2);
  await store.saveItems([{ ...items[0], tildaUid: items[1].tildaUid }]).then(() => {
    throw new Error("duplicate uid was accepted");
  }, (error) => {
    assertEquals(error.message, "duplicate_tilda_uid");
  });
});

Deno.test("stale inspection aborts the whole live batch before any insert", async () => {
  const store = new MemoryQueueStore();
  const stable = "130000000070";
  const changed = "130000000071";
  store.candidates = [candidate(stable), candidate(changed)];
  await bootstrap(store);
  let changedExtra = EXTRA;
  const fetchImpl: typeof fetch = (input) => {
    const url = String(input);
    if (url.includes("static.tildacdn")) {
      return Promise.resolve(new Response("", {
        status: 200,
        headers: { "content-type": "image/jpeg" },
      }));
    }
    const uid = url.split("/").pop() ?? "";
    const extra = uid === changed ? changedExtra : EXTRA;
    return Promise.resolve(new Response(html(uid, [PRIMARY_ONE, extra]), { status: 200 }));
  };
  await inspect(store, { fetch: fetchImpl });
  changedExtra = EXTRA_B;
  const catalog = new MemCatalog({ [stable]: snapshot(stable), [changed]: snapshot(changed) });
  const live = await executeLive(store, {
    authorizeLive: true,
    allowlist: [stable, changed],
    expected: { [stable]: 1, [changed]: 1 },
  }, { fetch: fetchImpl, catalog });
  assertEquals(live.executed, false);
  assertEquals(live.writes, 0);
  assertEquals(catalog.calls, 0);
  const items = await store.loadItems();
  assertEquals(items.find((item) => item.tildaUid === stable)?.status, "ready_for_review");
  assertEquals(items.find((item) => item.tildaUid === changed)?.errorClassification, "stale_inspection");
});

Deno.test("partial live failure stops the batch and does not retry", async () => {
  const store = new MemoryQueueStore();
  const uids = ["130000000072", "130000000073", "130000000074"];
  store.candidates = uids.map((uid) => candidate(uid));
  await bootstrap(store);
  const pages = fetchPages(Object.fromEntries(uids.map((uid) => [
    uid,
    () => new Response(html(uid, [PRIMARY_ONE, EXTRA]), { status: 200 }),
  ])));
  await inspect(store, { fetch: pages.fetch });
  const catalog = new MemCatalog(Object.fromEntries(uids.map((uid) => [uid, snapshot(uid)])));
  catalog.failOn = 2;
  const live = await executeLive(store, {
    authorizeLive: true,
    allowlist: uids,
    expected: Object.fromEntries(uids.map((uid) => [uid, 1])),
  }, { fetch: pages.fetch, catalog });
  assertEquals(live.status, "failed");
  assertEquals(live.writes, 1);
  assertEquals(live.inserted[uids[0]], 1);
  assertEquals(live.inserted[uids[2]], undefined);
  const items = await store.loadItems();
  assertEquals(items.find((item) => item.tildaUid === uids[0])?.status, "completed");
  assertEquals(items.find((item) => item.tildaUid === uids[1])?.errorClassification, "partial_failure");
  assertEquals(items.find((item) => item.tildaUid === uids[2])?.status, "ready_for_review");
  const again = await executeLive(store, {
    authorizeLive: true,
    allowlist: uids,
    expected: Object.fromEntries(uids.map((uid) => [uid, 1])),
  }, { fetch: pages.fetch, catalog });
  assertEquals(again.executed, false);
  assertEquals(catalog.calls, 2);
});

Deno.test("unauthorized and implicit modes do not insert images", async () => {
  const store = new MemoryQueueStore();
  const uid = "130000000075";
  store.candidates = [candidate(uid)];
  await bootstrap(store);
  const catalog = new MemCatalog({ [uid]: snapshot(uid) });
  const denied = await handleQueueRequest(new Request("https://queue.local", {
    method: "POST",
    body: JSON.stringify({ mode: "live", authorize_live: true, allowlist: [uid], expected: { [uid]: 1 } }),
  }), {
    authorize: () => Promise.resolve({ ok: false, status: 403, message: "Admin access denied" }),
    store,
    catalog,
  });
  assertEquals(denied.status, 403);
  const implicit = await handleQueueRequest(new Request("https://queue.local", {
    method: "POST",
    body: JSON.stringify({ mode: "live", allowlist: [uid], expected: { [uid]: 1 } }),
  }), {
    authorize: () => Promise.resolve({ ok: true, kind: "admin", userId: "admin" }),
    store,
    catalog,
  });
  assertEquals(implicit.status, 400);
  const missing = await handleQueueRequest(new Request("https://queue.local", {
    method: "POST",
    body: JSON.stringify({}),
  }), {
    authorize: () => Promise.resolve({ ok: true, kind: "admin", userId: "admin" }),
    store,
    catalog,
  });
  assertEquals(missing.status, 400);
  assertEquals(catalog.calls, 0);
  assertEquals((await store.loadItems())[0].status, "pending");
});

Deno.test("explicit recheck can reopen an ambiguous product", async () => {
  const store = new MemoryQueueStore();
  const uid = HISTORICAL_AMBIGUOUS[0];
  store.candidates = [candidate(uid)];
  await bootstrap(store);
  const pages = fetchPages({
    [uid]: () => new Response(html(uid, [PRIMARY_ONE, EXTRA]), { status: 200 }),
  });
  const result = await recheck(store, uid, { fetch: pages.fetch });
  assertEquals(result.writes, 0);
  assertEquals(result.status, "ready_for_review");
  const fingerprint = (await store.loadItems()).find((item) => item.tildaUid === uid)?.contentFingerprint;
  await bootstrap(store);
  const again = (await store.loadItems()).find((item) => item.tildaUid === uid);
  assertEquals(again?.status, "ready_for_review");
  assertEquals(again?.contentFingerprint, fingerprint);
});

Deno.test("a worker cannot overwrite a claim it no longer owns", async () => {
  const store = new MemoryQueueStore();
  store.candidates = [candidate("130000000081")];
  await bootstrap(store);
  const [owned] = await store.claim(20, "token-owner");
  store.items[0].claimToken = "token-other";
  const saved = await store.saveOwned([{
    ...owned,
    status: "no_extra",
    claimToken: null,
  }], "token-owner");
  assertEquals(saved, []);
  assertEquals(store.items[0].claimToken, "token-other");
  assertEquals(store.items[0].status, "pending");
});

Deno.test("a second live request cannot enter a batch already claimed", async () => {
  const store = new MemoryQueueStore();
  const uid = "130000000082";
  store.candidates = [candidate(uid)];
  await bootstrap(store);
  const pages = fetchPages({
    [uid]: () => new Response(html(uid, [PRIMARY_ONE, EXTRA]), { status: 200 }),
  });
  await inspect(store, { fetch: pages.fetch });
  assertEquals((await store.claimLive([uid], "live-token-held"))?.length, 1);
  const catalog = new MemCatalog({ [uid]: snapshot(uid) });
  const live = await executeLive(store, {
    authorizeLive: true,
    allowlist: [uid],
    expected: { [uid]: 1 },
  }, { fetch: pages.fetch, catalog });
  assertEquals(live.executed, false);
  assertEquals(live.error, "live_claim_held");
  assertEquals(live.writes, 0);
  assertEquals(catalog.calls, 0);
});

Deno.test("recheck does not take a row another worker holds", async () => {
  const store = new MemoryQueueStore();
  const uid = "130000000083";
  store.candidates = [candidate(uid)];
  await bootstrap(store);
  await store.claim(20, "token-owner");
  const pages = fetchPages({
    [uid]: () => new Response(html(uid, [PRIMARY_ONE, EXTRA]), { status: 200 }),
  });
  const result = await recheck(store, uid, { fetch: pages.fetch });
  assertEquals(result.error, "claim_held");
  assertEquals(store.items[0].claimToken, "token-owner");
  assertEquals(store.items[0].status, "pending");
  assertEquals(pages.calls.length, 0);
});

Deno.test("queue files do not schedule cron or write catalog tables", async () => {
  const sql = await Deno.readTextFile(new URL(
    "../../deploy/migrations/20261114155036_gallery_recovery_queue.sql",
    import.meta.url,
  ));
  const index = await Deno.readTextFile(new URL("./index.ts", import.meta.url));
  const store = await Deno.readTextFile(new URL("./supabase-store.ts", import.meta.url));
  const workflow = await Deno.readTextFile(new URL("./workflow.ts", import.meta.url));
  const config = await Deno.readTextFile(new URL("../../config.toml", import.meta.url));
  for (const source of [sql, index, store, workflow, config]) {
    assertEquals(source.includes("cron.schedule"), false);
  }
  assertEquals(sql.includes("UPDATE public.products"), false);
  assertEquals(sql.includes("DELETE FROM public.product"), false);
  assertEquals(sql.includes("SET app_is_visible"), false);
  assert(sql.includes("FOR UPDATE SKIP LOCKED"));
  assert(sql.includes("tilda_uid ~ '^[0-9]{6,20}$'"));
  assert(sql.includes("source = 'yml_variant'"));
  assert(sql.includes("source = 'tilda_gallery'"));
  assert(sql.includes("ENABLE ROW LEVEL SECURITY"));
  assert(sql.includes("public.is_admin()"));
  assert(sql.includes("UNIQUE (tilda_uid)"));
  assertEquals(sql.includes("::bigint"), false);
  assert(sql.includes("(tilda_uid::numeric), tilda_uid"));
  assert(sql.includes("ORDER BY q.tilda_uid::numeric, q.tilda_uid"));
  assert(sql.includes("ORDER BY updated.tilda_uid::numeric, updated.tilda_uid"));
  assert(sql.includes("'running'"));
  assert(sql.includes("'abandoned'"));
  assertEquals(sql.includes("GRANT ALL ON TABLE public.gallery_recovery_items TO anon"), false);
  assertEquals(sql.includes("GRANT EXECUTE ON FUNCTION public.gallery_recovery_claim_batch(integer, text) TO anon"), false);
  assert(index.includes("authorize_live !== true"));
  assertEquals(store.includes('from("products")'), false);
  assertEquals(store.includes('from("product_images")'), false);
  assertEquals(store.includes('from("product_variants")'), false);
  assertEquals(workflow.includes("app_is_visible"), false);
  assertEquals(sql.includes("SECURITY DEFINER"), false);
  assert(sql.includes("SECURITY INVOKER"));
  assert(sql.includes("gallery_recovery_claim_live"));
  assertEquals(sql.includes("EXECUTE format"), false);
  assertEquals(workflow.includes("timeoutMs:"), false);
  assert(workflow.includes("claimLive"));
  assert(workflow.includes("saveOwned"));
  assert(config.includes("[functions.catalog-gallery-queue]\nverify_jwt = true"));
});
