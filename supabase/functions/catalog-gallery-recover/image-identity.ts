const TILDA_CDN_HOSTS = new Set([
  "static.tildacdn.com",
  "static.tildacdn.one",
]);

const IMAGE_EXTENSIONS = [".jpg", ".jpeg", ".png", ".webp", ".gif"];

/** Same storage path on the two Tilda CDN hosts is one file. */
export function imageIdentity(raw: string): string | null {
  let url: URL;
  try {
    url = new URL(raw.trim());
  } catch {
    return null;
  }
  if (url.protocol !== "https:" && url.protocol !== "http:") return null;
  const host = url.hostname.toLowerCase();
  if (!url.pathname || url.pathname === "/") return null;
  if (TILDA_CDN_HOSTS.has(host)) return `tildacdn:${url.pathname}`;
  return `${host}${url.pathname}`;
}

export function isAllowedImageUrl(raw: string): boolean {
  let url: URL;
  try {
    url = new URL(raw.trim());
  } catch {
    return false;
  }
  if (url.protocol !== "https:") return false;
  if (!TILDA_CDN_HOSTS.has(url.hostname.toLowerCase())) return false;
  const path = url.pathname.toLowerCase();
  return IMAGE_EXTENSIONS.some((ext) => path.endsWith(ext));
}

/** Swap only the known CDN alias. Does not invent a new path. */
export function aliasImageUrl(raw: string): string | null {
  let url: URL;
  try {
    url = new URL(raw.trim());
  } catch {
    return null;
  }
  const host = url.hostname.toLowerCase();
  if (host === "static.tildacdn.one") {
    url.hostname = "static.tildacdn.com";
  } else if (host === "static.tildacdn.com") {
    url.hostname = "static.tildacdn.one";
  } else {
    return null;
  }
  return url.toString();
}
