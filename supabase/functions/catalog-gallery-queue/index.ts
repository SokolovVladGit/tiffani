import { authorizeSafeSync, type SafeSyncAuthResult } from "../catalog-yml-sync-safe/auth.ts";
import { galleryCatalogFromEnv, type GalleryCatalog } from "../catalog-gallery-recover/catalog.ts";
import type { QueueStore } from "./memory-store.ts";
import {
  bootstrap,
  executeLive,
  inspect,
  prepare,
  propose,
  recheck,
} from "./workflow.ts";

/**
 * Operator queue for gallery recovery. Modes:
 *   stats, bootstrap, prepare, inspect, propose, recheck, history, live.
 * live inserts tilda_gallery rows only when authorize_live is true
 * and the fresh inspection still matches the stored fingerprint.
 * Missing mode is not live. This function is not scheduled.
 */
export interface QueueHandlerDeps {
  authorize?: (req: Request) => Promise<SafeSyncAuthResult>;
  store?: QueueStore;
  catalog?: GalleryCatalog | null;
  fetch?: typeof fetch;
}

export async function handleQueueRequest(
  req: Request,
  deps: QueueHandlerDeps = {},
): Promise<Response> {
  if (req.method !== "POST") {
    return Response.json({ error: "method_not_allowed", writes: 0 }, { status: 405 });
  }
  const authorize = deps.authorize ??
    ((request: Request) => authorizeSafeSync(request, "manual"));
  const auth = await authorize(req);
  if (!auth.ok) {
    return Response.json({ error: auth.message, writes: 0 }, { status: auth.status });
  }

  let body: unknown;
  try {
    body = await req.json();
  } catch {
    return Response.json({ error: "invalid_json", writes: 0 }, { status: 400 });
  }
  if (!body || typeof body !== "object" || Array.isArray(body)) {
    return Response.json({ error: "body_must_be_object", writes: 0 }, { status: 400 });
  }
  const record = body as Record<string, unknown>;
  const mode = record.mode;
  if (mode === "live" && record.authorize_live !== true) {
    return Response.json({ error: "authorize_live_required", writes: 0 }, { status: 400 });
  }
  if (
    mode !== "stats" && mode !== "bootstrap" && mode !== "prepare" &&
    mode !== "inspect" && mode !== "propose" && mode !== "recheck" &&
    mode !== "history" && mode !== "live"
  ) {
    return Response.json({ error: "mode_not_supported", writes: 0 }, { status: 400 });
  }

  const store = deps.store ?? await storeFromEnv();
  const fetchImpl = deps.fetch ?? globalThis.fetch;
  if (mode === "stats") {
    const items = await store.loadItems();
    const counts: Record<string, number> = {};
    for (const item of items) counts[item.status] = (counts[item.status] ?? 0) + 1;
    return Response.json({ counts, writes: 0 });
  }
  if (mode === "bootstrap") return Response.json(await bootstrap(store));
  if (mode === "prepare") return Response.json(await prepare(store));
  if (mode === "inspect") {
    return Response.json(await inspect(store, { fetch: fetchImpl }));
  }
  if (mode === "propose") return Response.json(await propose(store));
  if (mode === "history") {
    return Response.json({ runs: await store.listRuns(20), writes: 0 });
  }
  if (mode === "recheck") {
    if (typeof record.tilda_uid !== "string") {
      return Response.json({ error: "tilda_uid_required", writes: 0 }, { status: 400 });
    }
    return Response.json(await recheck(store, record.tilda_uid, { fetch: fetchImpl }));
  }

  const allowlist = stringList(record.allowlist);
  const expected = numberMap(record.expected);
  if (!allowlist || !expected) {
    return Response.json({ error: "live_contract_invalid", writes: 0 }, { status: 400 });
  }
  const catalog = deps.catalog === undefined ? galleryCatalogFromEnv() : deps.catalog;
  return Response.json(await executeLive(store, {
    authorizeLive: true,
    allowlist,
    expected,
  }, { fetch: fetchImpl, catalog: catalog ?? undefined }));
}

function stringList(value: unknown): string[] | null {
  if (!Array.isArray(value)) return null;
  const out: string[] = [];
  for (const item of value) {
    if (typeof item !== "string") return null;
    out.push(item);
  }
  return out;
}

function numberMap(value: unknown): Record<string, number> | null {
  if (!value || typeof value !== "object" || Array.isArray(value)) return null;
  const out: Record<string, number> = {};
  for (const [key, entry] of Object.entries(value)) {
    if (typeof entry !== "number" || !Number.isInteger(entry)) return null;
    out[key] = entry;
  }
  return out;
}

async function storeFromEnv(): Promise<QueueStore> {
  const { supabaseQueueStoreFromEnv } = await import("./supabase-store.ts");
  const store = supabaseQueueStoreFromEnv();
  if (!store) throw new Error("queue_store_unavailable");
  return store;
}

if (import.meta.main) {
  Deno.serve((req) => handleQueueRequest(req));
}
