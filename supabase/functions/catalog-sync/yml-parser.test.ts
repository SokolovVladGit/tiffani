import {
  assertEquals,
  assert,
} from "https://deno.land/std@0.224.0/assert/mod.ts";

import { parseTildaYml } from "./yml-parser.ts";

/**
 * Pins parser behavior for offer images. Tilda YML exports place
 * multiple `<picture>` tags per offer (main + gallery). The parser
 * MUST preserve all of them in source order, deduplicated, while
 * still exposing a single `picture` accessor for backward-
 * compatible code paths (e.g. `products.photo`).
 */

function ymlWithOffer(picturesXml: string): string {
  return `<?xml version="1.0" encoding="UTF-8"?>
<yml_catalog date="2026-04-30">
  <shop>
    <name>t</name>
    <company>t</company>
    <url>https://t.example</url>
    <currencies><currency id="MDL" rate="1"/></currencies>
    <categories>
      <category id="c1">Cat</category>
    </categories>
    <offers>
      <offer id="111" group_id="G1" available="true">
        <name>Sample</name>
        <price>100</price>
        <currencyId>MDL</currencyId>
        <categoryId>c1</categoryId>
        ${picturesXml}
      </offer>
    </offers>
  </shop>
</yml_catalog>`;
}

Deno.test("parseTildaYml extracts a single picture", () => {
  const xml = ymlWithOffer("<picture>https://cdn.example/a.jpg</picture>");
  const cat = parseTildaYml(xml);
  assertEquals(cat.offers.length, 1);
  const offer = cat.offers[0];
  assertEquals(offer.picture, "https://cdn.example/a.jpg");
  assertEquals(offer.pictures, ["https://cdn.example/a.jpg"]);
});

Deno.test("parseTildaYml preserves all pictures in source order", () => {
  const xml = ymlWithOffer(
    [
      "<picture>https://cdn.example/main.jpg</picture>",
      "<picture>https://cdn.example/g1.jpg</picture>",
      "<picture>https://cdn.example/g2.jpg</picture>",
      "<picture>https://cdn.example/g3.jpg</picture>",
    ].join("\n"),
  );
  const cat = parseTildaYml(xml);
  const offer = cat.offers[0];
  assertEquals(offer.picture, "https://cdn.example/main.jpg");
  assertEquals(offer.pictures, [
    "https://cdn.example/main.jpg",
    "https://cdn.example/g1.jpg",
    "https://cdn.example/g2.jpg",
    "https://cdn.example/g3.jpg",
  ]);
});

Deno.test("parseTildaYml deduplicates pictures while preserving order", () => {
  const xml = ymlWithOffer(
    [
      "<picture>https://cdn.example/main.jpg</picture>",
      "<picture>https://cdn.example/g1.jpg</picture>",
      "<picture>https://cdn.example/main.jpg</picture>",
      "<picture>https://cdn.example/g2.jpg</picture>",
    ].join("\n"),
  );
  const cat = parseTildaYml(xml);
  const offer = cat.offers[0];
  assertEquals(offer.pictures, [
    "https://cdn.example/main.jpg",
    "https://cdn.example/g1.jpg",
    "https://cdn.example/g2.jpg",
  ]);
});

Deno.test("parseTildaYml returns empty pictures when no <picture> present", () => {
  const xml = ymlWithOffer("");
  const cat = parseTildaYml(xml);
  const offer = cat.offers[0];
  assertEquals(offer.pictures, []);
  assertEquals(offer.picture, undefined);
});

Deno.test("parseTildaYml trims whitespace inside picture text nodes", () => {
  const xml = ymlWithOffer(
    "<picture>   https://cdn.example/a.jpg   </picture>",
  );
  const cat = parseTildaYml(xml);
  const offer = cat.offers[0];
  assertEquals(offer.pictures, ["https://cdn.example/a.jpg"]);
  assertEquals(offer.picture, "https://cdn.example/a.jpg");
});

Deno.test("parseTildaYml exposes pictures alongside picture for back-compat", () => {
  const xml = ymlWithOffer(
    [
      "<picture>https://cdn.example/main.jpg</picture>",
      "<picture>https://cdn.example/g1.jpg</picture>",
    ].join("\n"),
  );
  const cat = parseTildaYml(xml);
  const offer = cat.offers[0];
  assert(offer.pictures && offer.pictures.length === 2);
  assertEquals(offer.picture, offer.pictures[0]);
});

Deno.test("parseTildaYml maps available=false on offer", () => {
  const xml = `<?xml version="1.0" encoding="UTF-8"?>
<yml_catalog date="2026-05-09">
  <shop>
    <name>t</name>
    <company>t</company>
    <url>https://t.example</url>
    <currencies><currency id="MDL" rate="1"/></currencies>
    <categories><category id="c1">Cat</category></categories>
    <offers>
      <offer id="999" group_id="G9" available="false">
        <name>Hidden sample</name>
        <price>1</price>
        <currencyId>MDL</currencyId>
        <categoryId>c1</categoryId>
      </offer>
    </offers>
  </shop>
</yml_catalog>`;
  const cat = parseTildaYml(xml);
  assertEquals(cat.offers.length, 1);
  assertEquals(cat.offers[0].available, false);
});

Deno.test("parseTildaYml defaults available to true when attribute omitted", () => {
  const xml = `<?xml version="1.0" encoding="UTF-8"?>
<yml_catalog date="2026-05-09">
  <shop>
    <name>t</name>
    <company>t</company>
    <url>https://t.example</url>
    <currencies><currency id="MDL" rate="1"/></currencies>
    <categories><category id="c1">Cat</category></categories>
    <offers>
      <offer id="112" group_id="G1">
        <name>No available attr</name>
        <price>10</price>
        <currencyId>MDL</currencyId>
        <categoryId>c1</categoryId>
      </offer>
    </offers>
  </shop>
</yml_catalog>`;
  const cat = parseTildaYml(xml);
  assertEquals(cat.offers.length, 1);
  assertEquals(cat.offers[0].available, true);
});
