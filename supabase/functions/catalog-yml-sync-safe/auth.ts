import { createClient } from "https://esm.sh/@supabase/supabase-js@2";

export type SafeSyncCaller =
  | { ok: true; kind: "service_role" }
  | { ok: true; kind: "admin"; userId: string };

export type SafeSyncAuthFailure = {
  ok: false;
  status: 401 | 403 | 500;
  message: string;
};

export type SafeSyncAuthResult = SafeSyncCaller | SafeSyncAuthFailure;

export interface UserLookup {
  userId: string | null;
  invalidToken: boolean;
  isAdmin: boolean;
  rpcFailed: boolean;
}

/**
 * Decides access from already-resolved facts. `source=cron` is accepted
 * only for the platform service-role secret. A user JWT, including an
 * admin JWT, cannot claim that source.
 */
export function decideSafeSyncAuth(input: {
  bearer: string | null;
  serviceRoleKey: string | null;
  source: string;
  lookup: UserLookup | null;
  /** Set only after `verifyServiceRoleJwt` succeeds. Never taken from the request body. */
  serviceJwt?: boolean;
}): SafeSyncAuthResult {
  const serviceKey = input.serviceRoleKey ?? "";
  if (
    input.serviceJwt ||
    (input.bearer &&
      serviceKey.length > 0 &&
      sameSecret(input.bearer, serviceKey))
  ) {
    return { ok: true, kind: "service_role" };
  }

  if (input.source === "cron") {
    return {
      ok: false,
      status: 403,
      message: "cron source requires the service role",
    };
  }

  if (!input.bearer) {
    return { ok: false, status: 401, message: "Authorization header required" };
  }

  const lookup = input.lookup;
  if (!lookup || lookup.invalidToken || !lookup.userId) {
    return { ok: false, status: 401, message: "Invalid token" };
  }
  if (lookup.rpcFailed || !lookup.isAdmin) {
    return { ok: false, status: 403, message: "Admin access denied" };
  }
  return { ok: true, kind: "admin", userId: lookup.userId };
}

export async function authorizeSafeSync(
  req: Request,
  source: string,
  lookupUser: (bearer: string) => Promise<UserLookup> = lookupSupabaseUser,
  verifyServiceJwt: (bearer: string) => Promise<string> = verifyProjectServiceRoleJwt,
): Promise<SafeSyncAuthResult> {
  const bearer = bearerToken(req);
  const serviceRoleKey = Deno.env.get("SUPABASE_SERVICE_ROLE_KEY") ?? null;
  let serviceJwt = false;
  let jwtCode = "not_checked";
  if (bearer && !sameSecret(bearer, serviceRoleKey ?? "")) {
    try {
      jwtCode = await verifyServiceJwt(bearer);
      serviceJwt = jwtCode === "ok";
    } catch {
      jwtCode = "verify_error";
      serviceJwt = false;
    }
  }
  const preliminary = decideSafeSyncAuth({
    bearer,
    serviceRoleKey,
    source,
    lookup: null,
    serviceJwt,
  });
  if (preliminary.ok || preliminary.status === 403 || !bearer) {
    return preliminary;
  }

  let lookup: UserLookup;
  try {
    lookup = await lookupUser(bearer);
  } catch {
    return { ok: false, status: 401, message: `Invalid token (${jwtCode})` };
  }
  const decided = decideSafeSyncAuth({
    bearer,
    serviceRoleKey,
    source,
    lookup,
  });
  if (!decided.ok && decided.status === 401) {
    return { ok: false, status: 401, message: `Invalid token (${jwtCode})` };
  }
  return decided;
}

export function bearerToken(req: Request): string | null {
  const header = req.headers.get("Authorization");
  if (!header || !/^Bearer\s+\S+/i.test(header)) return null;
  return header.replace(/^Bearer\s+/i, "").trim();
}

async function lookupSupabaseUser(bearer: string): Promise<UserLookup> {
  const supabaseUrl = Deno.env.get("SUPABASE_URL");
  const anonKey = Deno.env.get("SUPABASE_ANON_KEY");
  if (!supabaseUrl || !anonKey) {
    throw new Error("Server auth configuration missing");
  }

  const userClient = createClient(supabaseUrl, anonKey, {
    global: { headers: { Authorization: `Bearer ${bearer}` } },
    auth: { persistSession: false, autoRefreshToken: false },
  });

  const { data: userData, error: userError } = await userClient.auth.getUser(
    bearer,
  );
  if (userError || !userData.user) {
    return {
      userId: null,
      invalidToken: true,
      isAdmin: false,
      rpcFailed: false,
    };
  }

  const { data: isAdmin, error: rpcError } = await userClient.rpc("is_admin");
  if (rpcError) {
    return {
      userId: userData.user.id,
      invalidToken: false,
      isAdmin: false,
      rpcFailed: true,
    };
  }

  return {
    userId: userData.user.id,
    invalidToken: false,
    isAdmin: isAdmin === true,
    rpcFailed: false,
  };
}

/**
 * Accepts a JWT only when its signature checks out and the role claim
 * is exactly `service_role`. An anon key is a valid JWT too, so the
 * gateway check alone is not enough.
 */
type VerifyKey = JsonWebKey & { kid?: string };

function bytes(view: Uint8Array): Uint8Array<ArrayBuffer> {
  const copy = new Uint8Array(view.byteLength);
  copy.set(view);
  return copy;
}

export async function verifyServiceRoleJwt(
  token: string,
  keys: readonly VerifyKey[],
  options?: { hmacSecret?: string; nowMs?: number },
): Promise<string> {
  const parts = token.split(".");
  if (parts.length !== 3) return "not_jwt";
  const [headerPart, payloadPart, signaturePart] = parts;
  let header: { alg?: unknown; kid?: unknown };
  try {
    header = decodeJson(headerPart) as { alg?: unknown; kid?: unknown };
  } catch {
    return "bad_header";
  }
  if (header.alg !== "ES256" && header.alg !== "HS256") {
    return `unsupported_alg:${String(header.alg)}`;
  }

  const data = bytes(new TextEncoder().encode(`${headerPart}.${payloadPart}`));
  const signature = bytes(base64UrlToBytes(signaturePart));
  let verified = false;

  if (header.alg === "HS256") {
    const secret = options?.hmacSecret;
    if (!secret) return "hs256_no_secret";
    verified = await hmacMatches(secret, signature, data);
  } else {
    const kid = typeof header.kid === "string" ? header.kid : null;
    for (const jwk of keys) {
      if (jwk.kty !== "EC" || jwk.crv !== "P-256") continue;
      if (kid && jwk.kid && jwk.kid !== kid) continue;
      try {
        const key = await crypto.subtle.importKey(
          "jwk",
          jwk,
          { name: "ECDSA", namedCurve: "P-256" },
          false,
          ["verify"],
        );
        if (
          await crypto.subtle.verify(
            { name: "ECDSA", hash: "SHA-256" },
            key,
            signature,
            data,
          )
        ) {
          verified = true;
          break;
        }
      } catch {
        continue;
      }
    }
  }

  if (!verified) {
    return header.alg === "ES256" && keys.length === 0
      ? "no_keys"
      : `bad_signature:${String(header.alg)}`;
  }
  try {
    return claimsAreServiceRole(decodeJson(payloadPart), options?.nowMs ?? Date.now())
      ? "ok"
      : "bad_claims";
  } catch {
    return "bad_claims";
  }
}

async function verifyProjectServiceRoleJwt(token: string): Promise<string> {
  const local = await verifyServiceRoleJwt(token, await projectJwks(), {
    hmacSecret: Deno.env.get("SUPABASE_JWT_SECRET") ?? undefined,
  });
  if (local !== "hs256_no_secret") return local;
  return await confirmHs256ServiceRole(token);
}

/**
 * HS256 service-role keys are signed with the project JWT secret, which
 * is not present in the function environment. Auth has already verified
 * that signature when `/auth/v1/user` gets past the signature check and
 * only then reports a missing `sub`. Anon keys fail the role check.
 */
export async function confirmHs256ServiceRole(
  token: string,
  options?: {
    fetchImpl?: typeof fetch;
    supabaseUrl?: string;
    anonKey?: string;
    nowMs?: number;
  },
): Promise<string> {
  const supabaseUrl = options?.supabaseUrl ?? Deno.env.get("SUPABASE_URL") ?? "";
  const anonKey = options?.anonKey ?? Deno.env.get("SUPABASE_ANON_KEY") ?? "";
  if (!supabaseUrl || !anonKey) return "hs256_no_secret";
  const fetchImpl = options?.fetchImpl ?? fetch;
  let response: Response;
  try {
    response = await fetchImpl(
      `${supabaseUrl.replace(/\/$/, "")}/auth/v1/user`,
      {
        headers: {
          Authorization: `Bearer ${token}`,
          apikey: anonKey,
        },
      },
    );
  } catch {
    return "hs256_no_secret";
  }
  const body = await response.text();
  if (
    response.status === 401 ||
    /invalid jwt|unable to parse or verify signature/i.test(body)
  ) {
    return "bad_signature:HS256";
  }
  if (response.status === 200 || !/missing sub/i.test(body)) {
    return "bad_claims";
  }
  try {
    const payload = decodeJson(token.split(".")[1] ?? "");
    return claimsAreServiceRole(payload, options?.nowMs ?? Date.now())
      ? "ok"
      : "bad_claims";
  } catch {
    return "bad_claims";
  }
}

async function projectJwks(): Promise<JsonWebKey[]> {
  const raw = Deno.env.get("SUPABASE_JWKS");
  if (raw) {
    try {
      const parsed = parseJwks(raw);
      if (parsed.length > 0) return parsed;
    } catch {
      // Fall through to the published JWKS.
    }
  }
  const supabaseUrl = Deno.env.get("SUPABASE_URL");
  if (!supabaseUrl) return [];
  const response = await fetch(
    `${supabaseUrl.replace(/\/$/, "")}/auth/v1/.well-known/jwks.json`,
  );
  if (!response.ok) return [];
  return parseJwks(await response.text());
}

function parseJwks(raw: string): JsonWebKey[] {
  let parsed: unknown = JSON.parse(raw);
  if (typeof parsed === "string") parsed = JSON.parse(parsed);
  if (Array.isArray(parsed)) return parsed as JsonWebKey[];
  if (
    parsed &&
    typeof parsed === "object" &&
    Array.isArray((parsed as { keys?: unknown }).keys)
  ) {
    return (parsed as { keys: JsonWebKey[] }).keys;
  }
  return [];
}

function claimsAreServiceRole(payload: unknown, nowMs: number): boolean {
  if (!payload || typeof payload !== "object") return false;
  const { role, exp } = payload as { role?: unknown; exp?: unknown };
  if (role !== "service_role") return false;
  if (typeof exp !== "number" || exp * 1000 <= nowMs) return false;
  return true;
}

async function hmacMatches(
  secret: string,
  signature: Uint8Array<ArrayBuffer>,
  data: Uint8Array<ArrayBuffer>,
): Promise<boolean> {
  const key = await crypto.subtle.importKey(
    "raw",
    new TextEncoder().encode(secret),
    { name: "HMAC", hash: "SHA-256" },
    false,
    ["verify"],
  );
  return await crypto.subtle.verify("HMAC", key, signature, data);
}

function decodeJson(segment: string): unknown {
  return JSON.parse(new TextDecoder().decode(base64UrlToBytes(segment)));
}

function base64UrlToBytes(segment: string): Uint8Array {
  const padded = segment.replace(/-/g, "+").replace(/_/g, "/").padEnd(
    Math.ceil(segment.length / 4) * 4,
    "=",
  );
  const binary = atob(padded);
  const bytes = new Uint8Array(binary.length);
  for (let i = 0; i < binary.length; i++) bytes[i] = binary.charCodeAt(i);
  return bytes;
}

function sameSecret(left: string, right: string): boolean {
  const a = new TextEncoder().encode(left);
  const b = new TextEncoder().encode(right);
  const length = Math.max(a.length, b.length);
  let diff = a.length === b.length ? 0 : 1;
  for (let i = 0; i < length; i++) {
    diff |= (a[i] ?? 0) ^ (b[i] ?? 0);
  }
  return diff === 0;
}
