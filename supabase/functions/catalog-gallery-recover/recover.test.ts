import { assertEquals } from "https://deno.land/std@0.224.0/assert/mod.ts";

import { extractStoreProduct } from "./extract.ts";
import { imageIdentity } from "./image-identity.ts";
import { planProductGallery } from "./plan.ts";
import { recoverGalleries } from "./recover.ts";
import { supplementalRows } from "./rows.ts";

const PRIMARY_COM =
  "https://static.tildacdn.com/stor3162-3938-4664-b330-336236643437/52670934.jpg";
const PRIMARY_ONE =
  "https://static.tildacdn.one/stor3162-3938-4664-b330-336236643437/52670934.jpg";
const EXTRA_A =
  "https://static.tildacdn.one/stor1111-2222-3333-4444-555566667777/84530445.jpg";
const EXTRA_B =
  "https://static.tildacdn.one/stor1111-2222-3333-4444-555566667777/39405614.webp";
const SAME_BASENAME_OTHER_DIR =
  "https://static.tildacdn.one/stor9999-0000-1111-2222-333344445555/84530445.jpg";

function productHtml(product: Record<string, unknown>): string {
  return `<html><script>var product = ${JSON.stringify(product)};</script></html>`;
}

function celimaxProduct() {
  return {
    uid: "430431167102",
    title: "Celimax",
    gallery: [
      { img: PRIMARY_ONE },
      { img: EXTRA_A },
      { img: EXTRA_B },
    ],
    editions: [{ uid: "only", img: "" }],
  };
}

function shadeProduct() {
  const editions = Array.from({ length: 16 }, (_, i) => ({
    uid: `e${i}`,
    img: `https://static.tildacdn.com/stor3437-6134-4230-a135-306662326366/${100 + i}.jpg`,
  }));
  return {
    uid: "848933724282",
    title: "Bless Beauty",
    gallery: [
      ...editions.map((edition) => ({ img: edition.img })),
      { img: "https://static.tildacdn.one/stor3437-6134-4230-a135-306662326366/68879651.jpg" },
    ],
    editions,
  };
}

Deno.test("CDN alias shares identity and a different directory does not", () => {
  assertEquals(imageIdentity(PRIMARY_COM), imageIdentity(PRIMARY_ONE));
  assertEquals(
    imageIdentity(EXTRA_A) === imageIdentity(SAME_BASENAME_OTHER_DIR),
    false,
  );
});

Deno.test("extract reads the embedded product object without executing it", () => {
  const extracted = extractStoreProduct(productHtml(celimaxProduct()));
  assertEquals(extracted.ok, true);
  if (!extracted.ok) return;
  assertEquals(extracted.product.gallery.length, 3);
  assertEquals(extracted.product.editions.length, 1);
});

Deno.test("single-variant extras are prepared and the YML photo is not repeated", () => {
  const extracted = extractStoreProduct(productHtml(celimaxProduct()));
  if (!extracted.ok) throw new Error("extract");
  const plan = planProductGallery({
    tildaUid: "430431167102",
    product: extracted.product,
    knownImageUrls: [PRIMARY_COM],
    variantCount: 1,
  });
  assertEquals(plan.classification, "importable");
  assertEquals(plan.extras.map((extra) => extra.url), [EXTRA_A, EXTRA_B]);
  assertEquals(plan.skippedAmbiguous, []);
  assertEquals(plan.duplicates.length, 1);
});

Deno.test("multi-variant extra images are skipped as ambiguous", () => {
  const extracted = extractStoreProduct(productHtml(shadeProduct()));
  if (!extracted.ok) throw new Error("extract");
  const plan = planProductGallery({
    tildaUid: "848933724282",
    product: extracted.product,
    knownImageUrls: [],
    variantCount: 16,
  });
  assertEquals(plan.classification, "ambiguous");
  assertEquals(plan.importable, []);
  assertEquals(plan.skippedAmbiguous.length, 1);
  assertEquals(plan.editionCount, 16);
});

Deno.test("repeated preparation does not emit duplicate rows", () => {
  const importable = [
    { url: EXTRA_A, identity: imageIdentity(EXTRA_A)! },
    { url: EXTRA_B, identity: imageIdentity(EXTRA_B)! },
  ];
  const first = supplementalRows({
    productId: "product-1",
    importable,
    existing: [{ url: PRIMARY_COM, position: 0 }],
  });
  assertEquals(first.map((row) => row.position), [1, 2]);
  assertEquals(first.every((row) => row.source === "tilda_gallery"), true);
  const second = supplementalRows({
    productId: "product-1",
    importable,
    existing: [
      { url: PRIMARY_COM, position: 0 },
      ...first.map((row) => ({ url: row.url, position: row.position })),
    ],
  });
  assertEquals(second, []);
  const aliased = supplementalRows({
    productId: "product-1",
    importable: [{
      url: EXTRA_A.replace("static.tildacdn.one", "static.tildacdn.com"),
      identity: imageIdentity(EXTRA_A)!,
    }],
    existing: first.map((row) => ({ url: row.url, position: row.position })),
  });
  assertEquals(aliased, []);
});

Deno.test("HTTP 403 is access_denied and writes nothing", async () => {
  let calls = 0;
  const fetchImpl: typeof fetch = async () => {
    calls++;
    return new Response("no", { status: 403 });
  };
  const result = await recoverGalleries(
    { mode: "dry_run", tilda_uids: ["430431167102"] },
    { fetch: fetchImpl, retries: 2, timeoutMs: 1000 },
  );
  if (!result.ok) throw new Error(result.error);
  assertEquals(result.report.writes, 0);
  assertEquals(result.report.products[0].classification, "access_denied");
  assertEquals(result.report.products[0].importable, []);
  assertEquals(calls, 1);
});

Deno.test("dry-run validates two Celimax extras and does not write", async () => {
  const html = productHtml(celimaxProduct());
  const fetchImpl: typeof fetch = async (input) => {
    const url = String(input);
    if (url.includes("tiffani.md")) {
      return new Response(html, {
        status: 200,
        headers: { "content-type": "text/html" },
      });
    }
    return new Response("", {
      status: 200,
      headers: { "content-type": "image/jpeg" },
    });
  };
  const result = await recoverGalleries(
    {
      mode: "dry_run",
      tilda_uids: ["430431167102"],
      known_images: { "430431167102": [PRIMARY_COM] },
      variant_counts: { "430431167102": 1 },
    },
    { fetch: fetchImpl, retries: 0, timeoutMs: 1000 },
  );
  if (!result.ok) throw new Error(result.error);
  assertEquals(result.report.writes, 0);
  assertEquals(result.report.products[0].classification, "importable");
  assertEquals(result.report.products[0].importable.length, 2);
  const rows = supplementalRows({
    productId: "celimax",
    importable: result.report.products[0].importable,
    existing: [{ url: PRIMARY_COM, position: 0 }],
  });
  assertEquals(rows.length, 2);
  assertEquals(rows[0].source, "tilda_gallery");
});

Deno.test("ambiguous multi-variant dry-run prepares no rows", async () => {
  const html = productHtml(shadeProduct());
  const fetchImpl: typeof fetch = async () =>
    new Response(html, { status: 200, headers: { "content-type": "text/html" } });
  const result = await recoverGalleries(
    {
      mode: "dry_run",
      tilda_uids: ["848933724282"],
      variant_counts: { "848933724282": 16 },
    },
    { fetch: fetchImpl, retries: 0 },
  );
  if (!result.ok) throw new Error(result.error);
  assertEquals(result.report.writes, 0);
  assertEquals(result.report.products[0].classification, "ambiguous");
  assertEquals(result.report.products[0].importable, []);
  assertEquals(result.report.products[0].skippedAmbiguous.length, 1);
});
