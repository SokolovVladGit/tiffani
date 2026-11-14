import { assert, assertEquals, assertRejects } from "https://deno.land/std@0.224.0/assert/mod.ts";

import {
  authorizeSafeSync,
  decideSafeSyncAuth,
  confirmHs256ServiceRole,
  verifyServiceRoleJwt,
  type UserLookup,
} from "./auth.ts";
import { handleSafeSyncRequest } from "./index.ts";
import {
  fetchValidatedYml,
  offerIdentity,
  validateTildaCatalog,
  YmlGuardError,
} from "./yml-guard.ts";
import type { TildaCatalog, TildaOffer } from "../catalog-sync/types.ts";

const SERVICE = "test-service-role-secret";

function offer(partial: Partial<TildaOffer> & { id: string }): TildaOffer {
  return {
    available: true,
    price: 10,
    params: [],
    pictures: partial.pictures ?? (partial.picture ? [partial.picture] : []),
    ...partial,
  };
}

function catalog(offers: TildaOffer[]): TildaCatalog {
  return { categories: [], offers };
}

function request(body: unknown, token?: string): Request {
  const headers = new Headers({ "Content-Type": "application/json" });
  if (token) headers.set("Authorization", `Bearer ${token}`);
  return new Request("https://example.test/functions/v1/catalog-yml-sync-safe", {
    method: "POST",
    headers,
    body: JSON.stringify(body),
  });
}

function recordingClient() {
  const ops: string[] = [];
  const query = () => {
    const q = {
      select() {
        return q;
      },
      eq() {
        return q;
      },
      not() {
        return q;
      },
      range() {
        return Promise.resolve({ data: [], error: null });
      },
      single() {
        return Promise.resolve({ data: { id: "run-1" }, error: null });
      },
    };
    return q;
  };
  return {
    ops,
    client: {
      from(table: string) {
        return {
          insert() {
            ops.push(`insert:${table}`);
            const payload = { data: { id: "run-1" }, error: null };
            const promise = Promise.resolve(payload);
            return Object.assign(promise, query());
          },
          update() {
            ops.push(`update:${table}`);
            return { eq: () => Promise.resolve({ error: null }) };
          },
          upsert() {
            ops.push(`upsert:${table}`);
            return {
              select: () =>
                Promise.resolve({
                  data: [{ id: "p1", tilda_uid: "g1" }],
                  error: null,
                }),
            };
          },
          select() {
            ops.push(`select:${table}`);
            return query();
          },
          delete() {
            ops.push(`delete:${table}`);
            return Promise.resolve({ error: null });
          },
        };
      },
    },
  };
}

Deno.test("auth: anonymous and missing token are rejected", () => {
  assertEquals(
    decideSafeSyncAuth({
      bearer: null,
      serviceRoleKey: SERVICE,
      source: "manual",
      lookup: null,
    }).ok,
    false,
  );
  const anon = decideSafeSyncAuth({
    bearer: "anon-key",
    serviceRoleKey: SERVICE,
    source: "manual",
    lookup: { userId: null, invalidToken: true, isAdmin: false, rpcFailed: false },
  });
  assertEquals(anon.ok, false);
  if (!anon.ok) assertEquals(anon.status, 401);
});

Deno.test("auth: normal user and invalid token are rejected", () => {
  const user = decideSafeSyncAuth({
    bearer: "user-jwt",
    serviceRoleKey: SERVICE,
    source: "manual",
    lookup: {
      userId: "user-1",
      invalidToken: false,
      isAdmin: false,
      rpcFailed: false,
    },
  });
  assertEquals(user.ok, false);
  if (!user.ok) assertEquals(user.status, 403);

  const invalid = decideSafeSyncAuth({
    bearer: "not-a-jwt",
    serviceRoleKey: SERVICE,
    source: "manual",
    lookup: { userId: null, invalidToken: true, isAdmin: false, rpcFailed: false },
  });
  assertEquals(invalid.ok, false);
  if (!invalid.ok) assertEquals(invalid.status, 401);
});

Deno.test("auth: service role and admin are allowed; cron cannot be spoofed", () => {
  const service = decideSafeSyncAuth({
    bearer: SERVICE,
    serviceRoleKey: SERVICE,
    source: "cron",
    lookup: null,
  });
  assertEquals(service, { ok: true, kind: "service_role" });

  const admin = decideSafeSyncAuth({
    bearer: "admin-jwt",
    serviceRoleKey: SERVICE,
    source: "manual",
    lookup: {
      userId: "admin-1",
      invalidToken: false,
      isAdmin: true,
      rpcFailed: false,
    },
  });
  assertEquals(admin, { ok: true, kind: "admin", userId: "admin-1" });

  const spoof = decideSafeSyncAuth({
    bearer: "admin-jwt",
    serviceRoleKey: SERVICE,
    source: "cron",
    lookup: {
      userId: "admin-1",
      invalidToken: false,
      isAdmin: true,
      rpcFailed: false,
    },
  });
  assertEquals(spoof.ok, false);
  if (!spoof.ok) assertEquals(spoof.status, 403);
});

Deno.test("auth: authorizeSafeSync uses the lookup only for a non-service caller", async () => {
  Deno.env.set("SUPABASE_SERVICE_ROLE_KEY", SERVICE);
  let lookups = 0;
  const lookup = (_bearer: string): Promise<UserLookup> => {
    lookups++;
    return Promise.resolve({
      userId: "admin-1",
      invalidToken: false,
      isAdmin: true,
      rpcFailed: false,
    });
  };

  const service = await authorizeSafeSync(
    request({ dry_run: true }, SERVICE),
    "manual",
    lookup,
  );
  assertEquals(service.ok, true);
  assertEquals(lookups, 0);

  const admin = await authorizeSafeSync(
    request({ dry_run: true }, "admin-jwt"),
    "manual",
    lookup,
  );
  assertEquals(admin, { ok: true, kind: "admin", userId: "admin-1" });
  assertEquals(lookups, 1);

  const spoof = await authorizeSafeSync(
    request({ dry_run: false, source: "cron" }, "admin-jwt"),
    "cron",
    lookup,
  );
  assertEquals(spoof.ok, false);
  assertEquals(lookups, 1);
});

function b64url(bytes: Uint8Array): string {
  let binary = "";
  for (const byte of bytes) binary += String.fromCharCode(byte);
  return btoa(binary).replace(/\+/g, "-").replace(/\//g, "_").replace(/=+$/g, "");
}

function jwtPart(value: unknown): string {
  return b64url(new TextEncoder().encode(JSON.stringify(value)));
}

Deno.test("auth: signed service-role JWT passes; anon, expired, and forged do not", async () => {
  const pair = await crypto.subtle.generateKey(
    { name: "ECDSA", namedCurve: "P-256" },
    true,
    ["sign", "verify"],
  );
  const jwk = await crypto.subtle.exportKey("jwk", pair.publicKey);
  jwk.alg = "ES256";
  (jwk as JsonWebKey & { kid?: string }).kid = "test";
  const now = 1_700_000_000_000;

  async function sign(payload: Record<string, unknown>): Promise<string> {
    const header = jwtPart({ alg: "ES256", typ: "JWT", kid: "test" });
    const body = jwtPart(payload);
    const signature = await crypto.subtle.sign(
      { name: "ECDSA", hash: "SHA-256" },
      pair.privateKey,
      new TextEncoder().encode(`${header}.${body}`),
    );
    return `${header}.${body}.${b64url(new Uint8Array(signature))}`;
  }

  const service = await sign({
    role: "service_role",
    exp: Math.floor(now / 1000) + 3600,
  });
  assertEquals(await verifyServiceRoleJwt(service, [jwk], { nowMs: now }), "ok");

  const anon = await sign({ role: "anon", exp: Math.floor(now / 1000) + 3600 });
  assertEquals(await verifyServiceRoleJwt(anon, [jwk], { nowMs: now }), "bad_claims");

  const expired = await sign({
    role: "service_role",
    exp: Math.floor(now / 1000) - 10,
  });
  assertEquals(await verifyServiceRoleJwt(expired, [jwk], { nowMs: now }), "bad_claims");

  const [h, , s] = service.split(".");
  const forged = `${h}.${jwtPart({
    role: "service_role",
    exp: Math.floor(now / 1000) + 3600,
    sub: "forged",
  })}.${s}`;
  assertEquals(
    await verifyServiceRoleJwt(forged, [jwk], { nowMs: now }),
    "bad_signature:ES256",
  );

  const hmacKey = await crypto.subtle.importKey(
    "raw",
    new TextEncoder().encode("hmac-secret"),
    { name: "HMAC", hash: "SHA-256" },
    false,
    ["sign"],
  );
  const hsHeader = jwtPart({ alg: "HS256", typ: "JWT" });
  const hsBody = jwtPart({
    role: "service_role",
    exp: Math.floor(now / 1000) + 60,
  });
  const hsSig = await crypto.subtle.sign(
    "HMAC",
    hmacKey,
    new TextEncoder().encode(`${hsHeader}.${hsBody}`),
  );
  const hsJwt = `${hsHeader}.${hsBody}.${b64url(new Uint8Array(hsSig))}`;
  assertEquals(
    await verifyServiceRoleJwt(hsJwt, [], { hmacSecret: "hmac-secret", nowMs: now }),
    "ok",
  );
  assertEquals(
    await verifyServiceRoleJwt(hsJwt, [], { hmacSecret: "other-secret", nowMs: now }),
    "bad_signature:HS256",
  );
  assertEquals(
    await verifyServiceRoleJwt(hsJwt, [], { nowMs: now }),
    "hs256_no_secret",
  );

  Deno.env.set("SUPABASE_SERVICE_ROLE_KEY", SERVICE);
  let lookups = 0;
  const verified = await authorizeSafeSync(
    request({ dry_run: true }, service),
    "manual",
    () => {
      lookups++;
      return Promise.resolve({
        userId: null,
        invalidToken: true,
        isAdmin: false,
        rpcFailed: false,
      });
    },
    async (bearer) =>
      (await verifyServiceRoleJwt(bearer, [jwk], { nowMs: now })) === "ok"
        ? "ok"
        : "bad_signature:ES256",
  );
  assertEquals(verified, { ok: true, kind: "service_role" });
  assertEquals(lookups, 0);

  const authUrl = "https://mnjxcoyvomgbdtwdhejq.supabase.co";
  const serviceHs = `${jwtPart({ alg: "HS256" })}.${jwtPart({
    role: "service_role",
    exp: Math.floor(now / 1000) + 60,
  })}.sig`;
  const anonHs = `${jwtPart({ alg: "HS256" })}.${jwtPart({
    role: "anon",
    exp: Math.floor(now / 1000) + 60,
  })}.sig`;
  const missingSub = () =>
    Promise.resolve(new Response(
      JSON.stringify({ msg: "invalid claim: missing sub claim" }),
      { status: 400 },
    ));
  assertEquals(
    await confirmHs256ServiceRole(serviceHs, {
      supabaseUrl: authUrl,
      anonKey: "anon",
      nowMs: now,
      fetchImpl: missingSub,
    }),
    "ok",
  );
  assertEquals(
    await confirmHs256ServiceRole(anonHs, {
      supabaseUrl: authUrl,
      anonKey: "anon",
      nowMs: now,
      fetchImpl: missingSub,
    }),
    "bad_claims",
  );
  assertEquals(
    await confirmHs256ServiceRole(serviceHs, {
      supabaseUrl: authUrl,
      anonKey: "anon",
      nowMs: now,
      fetchImpl: () =>
        Promise.resolve(new Response(
          JSON.stringify({ msg: "invalid JWT: unable to parse or verify signature" }),
          { status: 401 },
        )),
    }),
    "bad_signature:HS256",
  );

  const cron = decideSafeSyncAuth({
    bearer: service,
    serviceRoleKey: SERVICE,
    source: "cron",
    lookup: null,
    serviceJwt: true,
  });
  assertEquals(cron, { ok: true, kind: "service_role" });
});

Deno.test("handler: unauthorized live and dry-run do not fetch or open a client", async () => {
  for (const body of [{ dry_run: false, source: "cron" }, { dry_run: true }]) {
    let fetched = false;
    let opened = false;
    const response = await handleSafeSyncRequest(request(body), {
      authorize: () =>
        Promise.resolve({ ok: false, status: 401, message: "Invalid token" }),
      fetchYml: () => {
        fetched = true;
        return Promise.reject(new Error("fetch should not run"));
      },
      createSupabase: () => {
        opened = true;
        throw new Error("client should not open");
      },
    });
    assertEquals(response.status, 401);
    assertEquals(fetched, false);
    assertEquals(opened, false);
  }
});

Deno.test("handler: service and admin dry-runs write no catalog rows", async () => {
  Deno.env.set("SUPABASE_URL", "https://mnjxcoyvomgbdtwdhejq.supabase.co");
  Deno.env.set("SUPABASE_SERVICE_ROLE_KEY", SERVICE);
  Deno.env.set("TILDA_YML_URL", "https://tiffani.md/tstore/yml/feed.yml");
  const sample = catalog([
    offer({
      id: "o1",
      groupId: "g1",
      price: 50,
      picture: "https://cdn.test/a.jpg",
      name: "Cream",
    }),
  ]);

  for (const caller of [
    { ok: true as const, kind: "service_role" as const },
    { ok: true as const, kind: "admin" as const, userId: "admin-1" },
  ]) {
    const db = recordingClient();
    const response = await handleSafeSyncRequest(request({ dry_run: true }), {
      authorize: () => Promise.resolve(caller),
      fetchYml: () =>
        Promise.resolve({
          catalog: sample,
          sizeBytes: 100,
          finalUrl: "https://tiffani.md/tstore/yml/feed.yml",
        }),
      createSupabase: () => db.client as never,
    });
    const payload = await response.json();
    assertEquals(response.status, 200);
    assertEquals(payload.mode, "dry_run");
    assertEquals(payload.products_upserted, 0);
    assertEquals(payload.variants_upserted, 0);
    assertEquals(payload.images_upserted, 0);
    assertEquals(payload.variants_seen, 1);
    assertEquals(db.ops.some((op) => op.startsWith("upsert:")), false);
    assertEquals(db.ops.some((op) => op.startsWith("delete:")), false);
  }
});

Deno.test("handler: authorized live upsert does not delete", async () => {
  Deno.env.set("SUPABASE_URL", "https://mnjxcoyvomgbdtwdhejq.supabase.co");
  Deno.env.set("SUPABASE_SERVICE_ROLE_KEY", SERVICE);
  Deno.env.set("TILDA_YML_URL", "https://tiffani.md/tstore/yml/feed.yml");
  const db = recordingClient();
  const response = await handleSafeSyncRequest(
    request({ dry_run: false, source: "manual" }),
    {
      authorize: () => Promise.resolve({ ok: true, kind: "service_role" }),
      fetchYml: () =>
        Promise.resolve({
          catalog: catalog([
            offer({
              id: "o1",
              groupId: "g1",
              price: 40,
              picture: "https://cdn.test/a.jpg",
              pictures: ["https://cdn.test/a.jpg", "https://cdn.test/b.jpg"],
            }),
          ]),
          sizeBytes: 80,
          finalUrl: "https://tiffani.md/tstore/yml/feed.yml",
        }),
      createSupabase: () => db.client as never,
    },
  );
  assertEquals(response.status, 200);
  assertEquals(db.ops.includes("upsert:products"), true);
  assertEquals(db.ops.includes("upsert:product_variants"), true);
  assertEquals(db.ops.includes("upsert:product_images"), true);
  assertEquals(db.ops.some((op) => op.startsWith("delete:")), false);
  assertEquals(db.ops.some((op) => op.includes("is_active")), false);
});

Deno.test("yml: malformed XML, duplicate ids, and bad prices fail closed", async () => {
  const url = "https://tiffani.md/tstore/yml/feed.yml";
  await assertRejects(
    () =>
      fetchValidatedYml(url, {
        timeoutMs: 1000,
        userAgent: "test",
        fetchImpl: () => Promise.resolve(new Response("<not-yml></not-yml>")),
      }),
    YmlGuardError,
    "Invalid YML",
  );

  await assertRejects(
    async () =>
      validateTildaCatalog(catalog([
        offer({ id: "o1", price: 10 }),
        offer({ id: "o1", price: 12 }),
      ])),
    YmlGuardError,
    "duplicate offer id",
  );
  await assertRejects(
    async () => validateTildaCatalog(catalog([offer({ id: "o1", price: undefined })])),
    YmlGuardError,
    "no parseable price",
  );
  await assertRejects(
    async () => validateTildaCatalog(catalog([offer({ id: "o1", price: -1 })])),
    YmlGuardError,
    "no parseable price",
  );
  await assertRejects(
    () =>
      fetchValidatedYml("http://tiffani.md/feed.yml", {
        timeoutMs: 1000,
        userAgent: "test",
        fetchImpl: () => Promise.reject(new Error("should not fetch")),
      }),
    YmlGuardError,
    "HTTPS",
  );
});

Deno.test("yml: redirect must stay on the configured HTTPS origin", async () => {
  const calls: string[] = [];
  await assertRejects(
    () =>
      fetchValidatedYml("https://tiffani.md/tstore/yml/feed.yml", {
        timeoutMs: 1000,
        userAgent: "test",
        fetchImpl: (input) => {
          calls.push(String(input));
          return Promise.resolve(
            new Response(null, {
              status: 302,
              headers: { location: "https://evil.example/feed.yml" },
            }),
          );
        },
      }),
    YmlGuardError,
    "configured HTTPS origin",
  );
  assertEquals(calls.length, 1);
});

Deno.test("yml: missing pictures stay empty and mapping is stable", () => {
  const bare = offer({ id: "o1", groupId: "g1", price: 30, pictures: [] });
  validateTildaCatalog(catalog([bare]));
  const first = offerIdentity(bare);
  const second = offerIdentity(bare);
  assertEquals(first, second);
  assertEquals(first, {
    tildaUid: "g1",
    variantId: "o1",
    productPhoto: null,
    variantPhoto: null,
    gallery: [],
  });

  const pictured = offer({
    id: "o2",
    price: 30.5,
    pictures: ["https://cdn.test/only.jpg"],
    picture: "https://cdn.test/only.jpg",
  });
  assertEquals(offerIdentity(pictured), {
    tildaUid: "o2",
    variantId: "o2",
    productPhoto: "https://cdn.test/only.jpg",
    variantPhoto: "https://cdn.test/only.jpg",
    gallery: ["https://cdn.test/only.jpg"],
  });
  assertEquals(offerIdentity(pictured), offerIdentity(pictured));
});

Deno.test("yml: same-origin redirect and a valid feed pass", async () => {
  const xml = `<?xml version="1.0"?>
<yml_catalog><shop><offers>
  <offer id="o1" group_id="g1"><price>10.00</price><name>Cream</name>
    <picture>https://cdn.test/a.jpg</picture></offer>
</offers></shop></yml_catalog>`;
  let hop = 0;
  const loaded = await fetchValidatedYml("https://tiffani.md/tstore/yml/feed.yml", {
    timeoutMs: 1000,
    userAgent: "test",
    fetchImpl: (input) => {
      hop++;
      if (hop === 1) {
        return Promise.resolve(
          new Response(null, {
            status: 302,
            headers: { location: "/tstore/yml/final.yml" },
          }),
        );
      }
      assertEquals(String(input), "https://tiffani.md/tstore/yml/final.yml");
      return Promise.resolve(new Response(xml));
    },
  });
  assertEquals(loaded.finalUrl, "https://tiffani.md/tstore/yml/final.yml");
  assertEquals(loaded.catalog.offers.length, 1);
  assertEquals(offerIdentity(loaded.catalog.offers[0]).tildaUid, "g1");
});

Deno.test("yml: oversized content-length is rejected before use", async () => {
  await assertRejects(
    () =>
      fetchValidatedYml("https://tiffani.md/feed.yml", {
        timeoutMs: 1000,
        userAgent: "test",
        maxBytes: 8,
        fetchImpl: () =>
          Promise.resolve(
            new Response("0123456789", { headers: { "content-length": "9" } }),
          ),
      }),
    YmlGuardError,
    "size limit",
  );
});
