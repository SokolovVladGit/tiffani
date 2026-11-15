import { aliasImageUrl, isAllowedImageUrl } from "./image-identity.ts";

export type ProbeReason =
  | "ok"
  | "host_not_allowed"
  | "http_403"
  | "not_an_image"
  | "http_error"
  | "probe_failed";

async function probe(
  url: string,
  fetchImpl: typeof fetch,
  timeoutMs: number,
): Promise<ProbeReason> {
  if (!isAllowedImageUrl(url)) return "host_not_allowed";
  const controller = new AbortController();
  const timer = setTimeout(() => controller.abort(), timeoutMs);
  try {
    let response = await fetchImpl(url, {
      method: "HEAD",
      redirect: "manual",
      signal: controller.signal,
    });
    if (response.status === 405 || response.status === 501) {
      response = await fetchImpl(url, {
        method: "GET",
        redirect: "manual",
        signal: controller.signal,
        headers: { Range: "bytes=0-0" },
      });
    }
    if (response.status === 301 || response.status === 302 ||
      response.status === 307 || response.status === 308) {
      return "http_error";
    }
    if (response.status === 403) return "http_403";
    if (response.status !== 200 && response.status !== 206) return "http_error";
    const type = (response.headers.get("content-type") ?? "").toLowerCase();
    if (type.includes("text/html")) return "not_an_image";
    if (type && !type.includes("image/") && !type.includes("octet-stream")) {
      return "not_an_image";
    }
    return "ok";
  } catch {
    return "probe_failed";
  } finally {
    clearTimeout(timer);
  }
}

/**
 * Accept the original URL when it probes as an image.
 * The other Tilda CDN host is used only after that exact URL probes ok.
 */
export async function confirmImageUrl(
  raw: string,
  deps: { fetch: typeof fetch; timeoutMs?: number },
): Promise<{ ok: true; url: string } | { ok: false; reason: ProbeReason }> {
  const timeoutMs = deps.timeoutMs ?? 8000;
  const direct = await probe(raw, deps.fetch, timeoutMs);
  if (direct === "ok") return { ok: true, url: raw };
  if (direct === "http_403" || direct === "host_not_allowed") {
    return { ok: false, reason: direct };
  }
  const alias = aliasImageUrl(raw);
  if (!alias || alias === raw) return { ok: false, reason: direct };
  const alternate = await probe(alias, deps.fetch, timeoutMs);
  if (alternate === "ok") return { ok: true, url: alias };
  return { ok: false, reason: alternate };
}
