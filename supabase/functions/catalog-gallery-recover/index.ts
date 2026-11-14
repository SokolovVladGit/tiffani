import { authorizeSafeSync, type SafeSyncAuthResult } from "../catalog-yml-sync-safe/auth.ts";
import { auditGalleryReport } from "./audit.ts";
import { galleryCatalogFromEnv, type GalleryCatalog } from "./catalog.ts";
import { recoverGalleries } from "./recover.ts";

/**
 * Gallery recovery. inspect and dry_run write nothing.
 * live inserts verified tilda_gallery rows only when the body says so,
 * the caller is an admin or the service role, and each UID is allowlisted.
 * Not scheduled. catalog-yml-sync-safe does not call this function.
 */
export interface GalleryHandlerDeps {
  authorize?: (req: Request) => Promise<SafeSyncAuthResult>;
  catalog?: GalleryCatalog | null;
  fetch?: typeof fetch;
}

export async function handleGalleryRequest(
  req: Request,
  deps: GalleryHandlerDeps = {},
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

  const mode = body && typeof body === "object" && !Array.isArray(body)
    ? (body as Record<string, unknown>).mode
    : undefined;
  const catalog = mode === "live"
    ? (deps.catalog === undefined ? galleryCatalogFromEnv() : deps.catalog)
    : undefined;
  const result = await recoverGalleries(body, {
    fetch: deps.fetch ?? globalThis.fetch,
    catalog: catalog ?? undefined,
  });
  if (!result.ok) {
    return Response.json({ error: result.error, writes: 0 }, { status: result.status });
  }
  const audit = auditGalleryReport(result.report);
  return Response.json({
    ...result.report,
    writes: audit.writes,
    audit,
  });
}

if (import.meta.main) {
  Deno.serve((req) => handleGalleryRequest(req));
}
