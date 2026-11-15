export type PageFetchResult =
  | { ok: true; html: string; finalUrl: string }
  | { ok: false; classification: "access_denied" | "extract_failed"; detail: string };

export function productPageUrl(tildaUid: string): string | null {
  if (!/^\d{6,20}$/.test(tildaUid)) return null;
  return `https://tiffani.md/tproduct/${tildaUid}`;
}

function hostAllowed(hostname: string): boolean {
  const host = hostname.toLowerCase();
  return host === "tiffani.md" || host.endsWith(".tiffani.md");
}

export async function fetchStorePage(
  tildaUid: string,
  deps: {
    fetch: typeof fetch;
    timeoutMs?: number;
    retries?: number;
  },
): Promise<PageFetchResult> {
  const start = productPageUrl(tildaUid);
  if (!start) {
    return { ok: false, classification: "extract_failed", detail: "invalid_uid" };
  }
  const timeoutMs = deps.timeoutMs ?? 8000;
  const retries = deps.retries ?? 2;
  let url = start;
  let redirectHops = 0;

  for (let attempt = 0; attempt <= retries; attempt++) {
    const controller = new AbortController();
    const timer = setTimeout(() => controller.abort(), timeoutMs);
    try {
      const response = await deps.fetch(url, {
        method: "GET",
        redirect: "manual",
        signal: controller.signal,
        headers: {
          Accept: "text/html",
          "User-Agent": "TIFFANIGalleryRecover/1",
        },
      });
      if (response.status === 301 || response.status === 302 ||
        response.status === 307 || response.status === 308) {
        const location = response.headers.get("location");
        if (!location || redirectHops >= 3) {
          return {
            ok: false,
            classification: "extract_failed",
            detail: "redirect_rejected",
          };
        }
        const next = new URL(location, url);
        if (!hostAllowed(next.hostname)) {
          return {
            ok: false,
            classification: "extract_failed",
            detail: "redirect_host_rejected",
          };
        }
        url = next.toString();
        redirectHops++;
        attempt--;
        continue;
      }
      if (response.status === 403) {
        return {
          ok: false,
          classification: "access_denied",
          detail: "HTTP 403",
        };
      }
      if (response.status >= 500 || response.status === 429) {
        if (attempt < retries) {
          await delay(200 * (2 ** attempt));
          continue;
        }
        return {
          ok: false,
          classification: "extract_failed",
          detail: `HTTP ${response.status}`,
        };
      }
      if (!response.ok) {
        return {
          ok: false,
          classification: "extract_failed",
          detail: `HTTP ${response.status}`,
        };
      }
      const finalUrl = response.url || url;
      const finalHost = new URL(finalUrl).hostname;
      if (!hostAllowed(finalHost)) {
        return {
          ok: false,
          classification: "extract_failed",
          detail: "response_host_rejected",
        };
      }
      const html = await response.text();
      if (html.length > 2_000_000) {
        return {
          ok: false,
          classification: "extract_failed",
          detail: "response_too_large",
        };
      }
      return { ok: true, html, finalUrl };
    } catch (error) {
      if (attempt < retries) {
        await delay(200 * (2 ** attempt));
        continue;
      }
      const message = error instanceof Error ? error.name : "fetch_failed";
      return { ok: false, classification: "extract_failed", detail: message };
    } finally {
      clearTimeout(timer);
    }
  }
  return { ok: false, classification: "extract_failed", detail: "retries_exhausted" };
}

function delay(ms: number): Promise<void> {
  return new Promise((resolve) => setTimeout(resolve, ms));
}
