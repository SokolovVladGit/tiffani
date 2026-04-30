import {
  assertEquals,
  assertStrictEquals,
} from "https://deno.land/std@0.224.0/assert/mod.ts";

import { parseVarProduct } from "./parse-var-product.ts";

Deno.test("parses a minimal var product block", () => {
  const html = [
    "<html><body>",
    '<script>var product = {"uid":184192311111,"parentuid":530255999631,',
    '"title":"Sanitized Title","price":"100","externalid":"ABCD1234567890123456"};</script>',
    "</body></html>",
  ].join("");

  const r = parseVarProduct(html);
  assertEquals(r, {
    uid: "184192311111",
    parentuid: "530255999631",
    title: "Sanitized Title",
    price: "100",
    externalid: "ABCD1234567890123456",
  });
});

Deno.test("handles string values containing braces", () => {
  const html = '<script>var product = {"uid":"1","title":"has } inside"};</script>';
  const r = parseVarProduct(html);
  assertEquals(r?.uid, "1");
  assertEquals(r?.title, "has } inside");
});

Deno.test("handles escaped quotes inside strings", () => {
  const html = '<script>var product = {"uid":"1","title":"quote \\"inside"};</script>';
  const r = parseVarProduct(html);
  assertEquals(r?.uid, "1");
  assertEquals(r?.title, 'quote "inside');
});

Deno.test("returns null when var product is absent", () => {
  assertStrictEquals(parseVarProduct("<html><body>no var</body></html>"), null);
});

Deno.test("returns null on malformed JSON payload", () => {
  assertStrictEquals(
    parseVarProduct("<script>var product = {unterminated"),
    null,
  );
});

Deno.test("returns null when uid is missing", () => {
  const html = '<script>var product = {"title":"no uid"};</script>';
  assertStrictEquals(parseVarProduct(html), null);
});

Deno.test("skips optional fields without failing", () => {
  const html = '<script>var product = {"uid":"999000000001","title":"t"};</script>';
  const r = parseVarProduct(html);
  assertEquals(r, {
    uid: "999000000001",
    parentuid: undefined,
    title: "t",
    price: undefined,
    externalid: undefined,
  });
});

Deno.test("accepts numeric uid coerced to string", () => {
  const html = '<script>var product = {"uid":123456789012};</script>';
  const r = parseVarProduct(html);
  assertEquals(r?.uid, "123456789012");
});
