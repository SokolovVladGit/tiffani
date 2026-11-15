import { assert, assertEquals } from "https://deno.land/std@0.224.0/assert/mod.ts";
import { decideGalleryAuth } from "./auth-gate.ts";
import {
  createGalleryCatalog,
  type CatalogProductSnapshot,
  type GalleryCatalog,
  type GalleryDb,
} from "./catalog.ts";
import { imageIdentity } from "./image-identity.ts";
import { handleGalleryRequest } from "./index.ts";
import { recoverGalleries } from "./recover.ts";
import type { GalleryInsertRow } from "./rows.ts";

const ERBORIAN = "102955626114";
const CELIMAX = "430431167102";
const MULTI = "848933724282";

const ERB_PRIMARY =
  "https://static.tildacdn.com/stor3031-6534-4332-a331-366138303634/dc00819f51e0b7e83aec82ff9301564d.png";
const ERB_A =
  "https://static.tildacdn.one/stor6162-6532-4065-b765-306635356438/60941640.png";
const ERB_B =
  "https://static.tildacdn.one/stor6235-6538-4761-a633-313636353133/97436353.png";
const CEL_PRIMARY =
  "https://static.tildacdn.com/stor3162-3938-4664-b330-336236643437/52670934.jpg";
const CEL_A =
  "https://static.tildacdn.one/stor6164-6562-4763-b537-386465666263/84530445.jpg";
const CEL_B =
  "https://static.tildacdn.one/stor6231-6364-4339-b262-336166616666/39405614.webp";

function pageHtml(uid: string, primary: string, extras: string[]): string {
  const product = {
    uid,
    title: uid,
    gallery: [primary.replace("static.tildacdn.com", "static.tildacdn.one"), ...extras]
      .map((img) => ({ img })),
    editions: [{ uid: "only", img: "" }],
  };
  return `<html><script>var product = ${JSON.stringify(product)};</script></html>`;
}

function snapshot(
  id: string,
  uid: string,
  primary: string,
  variantCount = 1,
): CatalogProductSnapshot & { photo: string; price: number; mark: null; appIsVisible: boolean } {
  return {
    id,
    tildaUid: uid,
    variantCount,
    variantPhotoUrls: [primary],
    photo: primary,
    price: 10,
    mark: null,
    appIsVisible: true,
    images: [{ url: primary, position: 0, source: "yml_variant" }],
  };
}

class MemoryCatalog implements GalleryCatalog {
  readonly products = new Map<string, ReturnType<typeof snapshot>>();
  readonly inserts: GalleryInsertRow[] = [];
  failUrls = new Set<string>();

  async loadProduct(tildaUid: string) {
    return this.products.get(tildaUid) ?? null;
  }

  async insertGalleryImage(row: GalleryInsertRow) {
    this.inserts.push({ ...row });
    if (row.source !== "tilda_gallery") return { error: "source_rejected" };
    const product = [...this.products.values()].find((item) => item.id === row.product_id);
    if (!product) return { error: "product_missing" };
    if (this.failUrls.has(row.url)) {
      this.failUrls.delete(row.url);
      return { error: "statement_timeout" };
    }
    const identity = imageIdentity(row.url);
    if (product.images.some((image) => imageIdentity(image.url) === identity)) {
      return "duplicate";
    }
    product.images.push({ url: row.url, position: row.position, source: row.source });
    return "inserted";
  }
}

function fetchPages(pages: Record<string, string | number>): typeof fetch {
  return async (input) => {
    const url = String(input);
    const uid = Object.keys(pages).find((key) => url.includes(key));
    if (!uid) {
      return new Response("", { status: 200, headers: { "content-type": "image/jpeg" } });
    }
    const page = pages[uid];
    if (typeof page === "number") return new Response("no", { status: page });
    return new Response(page, {
      status: 200,
      headers: { "content-type": "text/html" },
    });
  };
}

function liveBody(uids: string[], allowlist = uids) {
  return {
    mode: "live" as const,
    tilda_uids: uids,
    allowlist,
    known_images: {},
    variant_counts: { [ERBORIAN]: 99, [CELIMAX]: 99 },
  };
}

Deno.test("Erborian and Celimax live inserts only the two supplementary images", async () => {
  const catalog = new MemoryCatalog();
  const erborian = snapshot("erborian", ERBORIAN, ERB_PRIMARY);
  const celimax = snapshot("celimax", CELIMAX, CEL_PRIMARY);
  catalog.products.set(ERBORIAN, erborian);
  catalog.products.set(CELIMAX, celimax);
  const result = await recoverGalleries(liveBody([ERBORIAN, CELIMAX]), {
    fetch: fetchPages({
      [ERBORIAN]: pageHtml(ERBORIAN, ERB_PRIMARY, [ERB_A, ERB_B]),
      [CELIMAX]: pageHtml(CELIMAX, CEL_PRIMARY, [CEL_A, CEL_B]),
    }),
    retries: 0,
    catalog,
  });
  if (!result.ok) throw new Error(result.error);
  assertEquals(result.report.writes, 4);
  assertEquals(result.report.products.map((product) => product.inserted), [2, 2]);
  assertEquals(result.report.products.map((product) => product.classification), [
    "inserted",
    "inserted",
  ]);
  assertEquals(catalog.inserts.map((row) => [row.product_id, row.position, row.source, row.url]), [
    ["erborian", 1, "tilda_gallery", ERB_A],
    ["erborian", 2, "tilda_gallery", ERB_B],
    ["celimax", 1, "tilda_gallery", CEL_A],
    ["celimax", 2, "tilda_gallery", CEL_B],
  ]);
  assertEquals(erborian.images[0], { url: ERB_PRIMARY, position: 0, source: "yml_variant" });
  assertEquals(celimax.images[0], { url: CEL_PRIMARY, position: 0, source: "yml_variant" });
  assertEquals(erborian.photo, ERB_PRIMARY);
  assertEquals(erborian.price, 10);
  assertEquals(erborian.mark, null);
  assertEquals(erborian.appIsVisible, true);
  assertEquals(catalog.inserts.some((row) => row.url === ERB_PRIMARY), false);
  assertEquals(catalog.inserts.some((row) => row.url.includes("52670934.jpg")), false);
});

Deno.test("a second live run inserts nothing", async () => {
  const catalog = new MemoryCatalog();
  catalog.products.set(CELIMAX, snapshot("celimax", CELIMAX, CEL_PRIMARY));
  const deps = {
    fetch: fetchPages({
      [CELIMAX]: pageHtml(CELIMAX, CEL_PRIMARY, [CEL_A, CEL_B]),
    }),
    retries: 0,
    catalog,
  };
  const first = await recoverGalleries(liveBody([CELIMAX]), deps);
  const second = await recoverGalleries(liveBody([CELIMAX]), deps);
  if (!first.ok || !second.ok) throw new Error("live failed");
  assertEquals(first.report.writes, 2);
  assertEquals(second.report.writes, 0);
  assertEquals(second.report.products[0].classification, "no_extras");
  assertEquals(second.report.products[0].duplicates.length, 3);
  assertEquals(catalog.products.get(CELIMAX)?.images.length, 3);
});

Deno.test("multi-variant galleries are reported and not inserted", async () => {
  let fetches = 0;
  const catalog = new MemoryCatalog();
  catalog.products.set(MULTI, snapshot("shades", MULTI, CEL_PRIMARY, 16));
  const result = await recoverGalleries(liveBody([MULTI]), {
    fetch: async () => {
      fetches++;
      return new Response("no", { status: 200 });
    },
    catalog,
  });
  if (!result.ok) throw new Error(result.error);
  assertEquals(fetches, 0);
  assertEquals(result.report.writes, 0);
  assertEquals(result.report.products[0].classification, "ambiguous_variant_gallery");
  assertEquals(result.report.products[0].editionCount, 16);
  assertEquals(catalog.inserts, []);
});

Deno.test("HTTP 403 does not insert and is not retried", async () => {
  let fetches = 0;
  const catalog = new MemoryCatalog();
  catalog.products.set(ERBORIAN, snapshot("erborian", ERBORIAN, ERB_PRIMARY));
  const result = await recoverGalleries(liveBody([ERBORIAN]), {
    fetch: async () => {
      fetches++;
      return new Response("denied", { status: 403 });
    },
    retries: 2,
    catalog,
  });
  if (!result.ok) throw new Error(result.error);
  assertEquals(fetches, 1);
  assertEquals(result.report.writes, 0);
  assertEquals(result.report.products[0].classification, "access_denied");
  assertEquals(catalog.inserts, []);
});

Deno.test("HTTP 404 and malformed product metadata insert nothing", async () => {
  const catalog = new MemoryCatalog();
  catalog.products.set(ERBORIAN, snapshot("erborian", ERBORIAN, ERB_PRIMARY));
  catalog.products.set(CELIMAX, snapshot("celimax", CELIMAX, CEL_PRIMARY));
  let calls = 0;
  const result = await recoverGalleries(liveBody([ERBORIAN, CELIMAX]), {
    fetch: async (input) => {
      calls++;
      const url = String(input);
      if (url.includes(ERBORIAN)) return new Response("missing", { status: 404 });
      return new Response("<html>no product</html>", {
        status: 200,
        headers: { "content-type": "text/html" },
      });
    },
    retries: 2,
    catalog,
  });
  if (!result.ok) throw new Error(result.error);
  assertEquals(calls, 2);
  assertEquals(result.report.products.map((product) => product.classification), [
    "extract_failed",
    "extract_failed",
  ]);
  assertEquals(result.report.products[0].detail, "HTTP 404");
  assertEquals(result.report.writes, 0);
  assertEquals(catalog.inserts, []);
});

Deno.test("a CDN alias of an existing image is not inserted again", async () => {
  const catalog = new MemoryCatalog();
  const product = snapshot("erborian", ERBORIAN, ERB_PRIMARY);
  product.images.push({
    url: ERB_A.replace("static.tildacdn.one", "static.tildacdn.com"),
    position: 4,
    source: null,
  });
  catalog.products.set(ERBORIAN, product);
  const result = await recoverGalleries(liveBody([ERBORIAN]), {
    fetch: fetchPages({
      [ERBORIAN]: pageHtml(ERBORIAN, ERB_PRIMARY, [ERB_A, ERB_B]),
    }),
    retries: 0,
    catalog,
  });
  if (!result.ok) throw new Error(result.error);
  assertEquals(result.report.writes, 1);
  assertEquals(catalog.inserts.map((row) => row.url), [ERB_B]);
  assertEquals(product.images[1].position, 4);
  assertEquals(product.images[1].source, null);
  assertEquals(catalog.inserts[0].position, 5);
});

Deno.test("a database error stops that product and the next run continues", async () => {
  const catalog = new MemoryCatalog();
  catalog.failUrls.add(ERB_B);
  catalog.products.set(ERBORIAN, snapshot("erborian", ERBORIAN, ERB_PRIMARY));
  catalog.products.set(CELIMAX, snapshot("celimax", CELIMAX, CEL_PRIMARY));
  const deps = {
    fetch: fetchPages({
      [ERBORIAN]: pageHtml(ERBORIAN, ERB_PRIMARY, [ERB_A, ERB_B]),
      [CELIMAX]: pageHtml(CELIMAX, CEL_PRIMARY, [CEL_A, CEL_B]),
    }),
    retries: 0,
    catalog,
  };
  const first = await recoverGalleries(liveBody([ERBORIAN, CELIMAX]), deps);
  if (!first.ok) throw new Error(first.error);
  assertEquals(first.report.products[0].classification, "partial_failure");
  assertEquals(first.report.products[0].inserted, 1);
  assertEquals(first.report.products[0].detail, "statement_timeout");
  assertEquals(first.report.products[1].inserted, 2);
  const retry = await recoverGalleries(liveBody([ERBORIAN]), deps);
  if (!retry.ok) throw new Error(retry.error);
  assertEquals(retry.report.writes, 1);
  assertEquals(retry.report.products[0].classification, "inserted");
  assertEquals(catalog.products.get(ERBORIAN)?.images.map((image) => image.position), [0, 1, 2]);
});

Deno.test("missing mode, bad UID, and a UID outside the allowlist do not write", async () => {
  const catalog = new MemoryCatalog();
  catalog.products.set(ERBORIAN, snapshot("erborian", ERBORIAN, ERB_PRIMARY));
  const missing = await recoverGalleries(
    { tilda_uids: [ERBORIAN] },
    { fetch: async () => new Response(""), catalog },
  );
  const badUid = await recoverGalleries(
    { mode: "live", tilda_uids: ["12"], allowlist: ["12"] },
    { fetch: async () => new Response(""), catalog },
  );
  const outside = await recoverGalleries(
    { mode: "live", tilda_uids: [ERBORIAN], allowlist: [CELIMAX] },
    { fetch: async () => new Response(""), catalog },
  );
  const absent = await recoverGalleries(
    { mode: "live", tilda_uids: [CELIMAX], allowlist: [CELIMAX] },
    { fetch: async () => new Response(""), catalog },
  );
  assertEquals(missing.ok && missing.report.writes, false);
  if (missing.ok) throw new Error("missing mode must not run");
  assertEquals(missing.error, "mode_must_be_inspect_dry_run_or_live");
  assertEquals(badUid.ok, false);
  assertEquals(outside.ok, false);
  if (!outside.ok) assertEquals(outside.error, "uid_not_in_allowlist");
  if (!absent.ok) throw new Error(absent.error);
  assertEquals(absent.report.products[0].classification, "missing_product");
  assertEquals(absent.report.writes, 0);
  assertEquals(catalog.inserts, []);
});

Deno.test("dry-run keeps writes at zero even when a catalog is available", async () => {
  const catalog = new MemoryCatalog();
  catalog.products.set(CELIMAX, snapshot("celimax", CELIMAX, CEL_PRIMARY));
  const result = await recoverGalleries(
    {
      mode: "dry_run",
      tilda_uids: [CELIMAX],
      known_images: { [CELIMAX]: [CEL_PRIMARY] },
      variant_counts: { [CELIMAX]: 1 },
    },
    {
      fetch: fetchPages({
        [CELIMAX]: pageHtml(CELIMAX, CEL_PRIMARY, [CEL_A, CEL_B]),
      }),
      retries: 0,
      catalog,
    },
  );
  if (!result.ok) throw new Error(result.error);
  assertEquals(result.report.mode, "dry_run");
  assertEquals(result.report.writes, 0);
  assertEquals(result.report.products[0].importable.length, 2);
  assertEquals(catalog.inserts, []);
});

Deno.test("unauthorized and non-admin live requests do not touch the catalog", async () => {
  let loads = 0;
  const catalog: GalleryCatalog = {
    loadProduct: async () => {
      loads++;
      return null;
    },
    insertGalleryImage: async () => {
      throw new Error("insert must not run");
    },
  };
  const body = JSON.stringify(liveBody([ERBORIAN]));
  for (const auth of [
    { ok: false as const, status: 401 as const, message: "Authorization header required" },
    { ok: false as const, status: 403 as const, message: "Admin access denied" },
  ]) {
    const response = await handleGalleryRequest(
      new Request("https://example.test/gallery", { method: "POST", body }),
      { authorize: async () => auth, catalog },
    );
    assertEquals(response.status, auth.status);
    assertEquals(await response.json(), { error: auth.message, writes: 0 });
  }
  assertEquals(loads, 0);
});

Deno.test("gallery auth ignores client admin flags and accepts admin or service role", () => {
  assertEquals(
    decideGalleryAuth({ bearer: null, serviceRoleKey: "secret", lookup: null }).ok,
    false,
  );
  const user = decideGalleryAuth({
    bearer: "user-jwt",
    serviceRoleKey: "secret",
    lookup: { userId: "u1", invalidToken: false, isAdmin: false, rpcFailed: false },
  });
  assertEquals(user.ok, false);
  const admin = decideGalleryAuth({
    bearer: "admin-jwt",
    serviceRoleKey: "secret",
    lookup: { userId: "admin", invalidToken: false, isAdmin: true, rpcFailed: false },
  });
  assertEquals(admin.ok && admin.kind, "admin");
  const service = decideGalleryAuth({
    bearer: "secret",
    serviceRoleKey: "secret",
    lookup: { userId: null, invalidToken: true, isAdmin: false, rpcFailed: false },
  });
  assertEquals(service.ok && service.kind, "service_role");
});

Deno.test("catalog adapter only inserts tilda_gallery image rows", async () => {
  const calls: string[] = [];
  const db: GalleryDb = {
    from(table) {
      return {
        select() {
          return {
            async eq() {
              calls.push(`select ${table}`);
              if (table === "products") {
                return { data: [{ id: "p1", tilda_uid: ERBORIAN }], error: null };
              }
              if (table === "product_variants") {
                return { data: [{ photo: ERB_PRIMARY }], error: null };
              }
              return { data: [{ url: ERB_PRIMARY, position: 0, source: "yml_variant" }], error: null };
            },
          };
        },
        async insert(row) {
          calls.push(`insert ${table} ${row.source}`);
          if (row.url.endsWith("60941640.png")) {
            return { error: { message: "duplicate", code: "23505" } };
          }
          return { error: null };
        },
      };
    },
  };
  const catalog = createGalleryCatalog(db);
  const loaded = await catalog.loadProduct(ERBORIAN);
  assert(loaded && typeof loaded !== "string");
  if (!loaded || typeof loaded === "string") return;
  assertEquals(loaded.variantCount, 1);
  assertEquals(await catalog.insertGalleryImage({
    product_id: "p1",
    url: ERB_B,
    position: 1,
    source: "tilda_gallery",
  }), "inserted");
  assertEquals(await catalog.insertGalleryImage({
    product_id: "p1",
    url: ERB_A,
    position: 2,
    source: "tilda_gallery",
  }), "duplicate");
  assertEquals(calls.filter((call) => call.startsWith("insert")), [
    "insert product_images tilda_gallery",
    "insert product_images tilda_gallery",
  ]);
  const source = await Deno.readTextFile(new URL("./catalog.ts", import.meta.url));
  assertEquals(source.includes(".update("), false);
  assertEquals(source.includes(".upsert("), false);
  assertEquals(source.includes(".delete("), false);
  assertEquals(source.includes("app_is_visible"), false);
  const config = await Deno.readTextFile(new URL("../../config.toml", import.meta.url));
  assert(config.includes("[functions.catalog-gallery-recover]\nverify_jwt = true"));
});
