import { parseTildaYml } from "../catalog-sync/yml-parser.ts";
import type { TildaCatalog, TildaOffer } from "../catalog-sync/types.ts";

/** 16 MiB. The live feed is about 6 MiB; the cap is not an offer count. */
export const DEFAULT_MAX_YML_BYTES = 16 * 1024 * 1024;
const MAX_REDIRECTS = 3;

export class YmlGuardError extends Error {
  constructor(message: string) {
    super(message);
    this.name = "YmlGuardError";
  }
}

export interface FetchValidatedYmlOptions {
  timeoutMs: number;
  userAgent: string;
  maxBytes?: number;
  fetchImpl?: typeof fetch;
}

export interface ValidatedYml {
  catalog: TildaCatalog;
  sizeBytes: number;
  finalUrl: string;
}

export interface OfferIdentity {
  tildaUid: string;
  variantId: string;
  productPhoto: string | null;
  variantPhoto: string | null;
  gallery: string[];
}

/**
 * Product key is the Tilda group id, otherwise the offer id.
 * That key is `products.tilda_uid`. The offer id is `variant_id`.
 * The first picture is the product and variant photo. Every picture
 * is a gallery URL. Missing pictures stay null and do not invent URLs.
 */
export function offerIdentity(offer: TildaOffer): OfferIdentity {
  const gallery = offer.pictures && offer.pictures.length > 0
    ? [...offer.pictures]
    : (offer.picture ? [offer.picture] : []);
  const primary = gallery[0] ?? null;
  return {
    tildaUid: offer.groupId ?? offer.id,
    variantId: offer.id,
    productPhoto: primary,
    variantPhoto: primary,
    gallery,
  };
}

export function validateTildaCatalog(catalog: TildaCatalog): void {
  if (!Array.isArray(catalog.offers) || catalog.offers.length === 0) {
    throw new YmlGuardError("Invalid YML: shop has no offers");
  }

  const seen = new Set<string>();
  for (const offer of catalog.offers) {
    if (!offer.id) {
      throw new YmlGuardError("Invalid YML: offer is missing an id");
    }
    if (seen.has(offer.id)) {
      throw new YmlGuardError(`Invalid YML: duplicate offer id ${offer.id}`);
    }
    seen.add(offer.id);
    if (!validMoney(offer.price)) {
      throw new YmlGuardError(
        `Invalid YML: offer ${offer.id} has no parseable price`,
      );
    }
    if (offer.oldPrice !== undefined && !validMoney(offer.oldPrice)) {
      throw new YmlGuardError(
        `Invalid YML: offer ${offer.id} has an invalid old price`,
      );
    }
  }
}

/**
 * Fetches the configured feed and refuses anything that is not HTTPS
 * on that URL's origin, including redirects. Does not write catalog rows.
 */
export async function fetchValidatedYml(
  rawUrl: string,
  options: FetchValidatedYmlOptions,
): Promise<ValidatedYml> {
  const start = parseHttpsUrl(rawUrl);
  const fetchImpl = options.fetchImpl ?? fetch;
  const maxBytes = options.maxBytes ?? DEFAULT_MAX_YML_BYTES;
  const origin = start.origin;

  let current = start;
  let response: Response | null = null;
  for (let hop = 0; hop <= MAX_REDIRECTS; hop++) {
    response = await fetchImpl(current.href, {
      redirect: "manual",
      headers: { "User-Agent": options.userAgent },
      signal: AbortSignal.timeout(options.timeoutMs),
    });
    if (response.status < 300 || response.status >= 400) break;
    if (hop === MAX_REDIRECTS) {
      throw new YmlGuardError("YML fetch failed: too many redirects");
    }
    const location = response.headers.get("location");
    if (!location) {
      throw new YmlGuardError("YML fetch failed: redirect without location");
    }
    const next = new URL(location, current);
    if (next.protocol !== "https:" || next.origin !== origin) {
      throw new YmlGuardError(
        "YML fetch failed: redirect left the configured HTTPS origin",
      );
    }
    current = next;
  }

  if (!response) {
    throw new YmlGuardError("YML fetch failed: no response");
  }
  if (!response.ok) {
    throw new YmlGuardError(`YML fetch failed: HTTP ${response.status}`);
  }
  if (current.origin !== origin || current.protocol !== "https:") {
    throw new YmlGuardError(
      "YML fetch failed: final URL left the configured HTTPS origin",
    );
  }

  const declared = Number(response.headers.get("content-length") ?? "");
  if (Number.isFinite(declared) && declared > maxBytes) {
    throw new YmlGuardError("YML fetch failed: response exceeds size limit");
  }

  const bytes = new Uint8Array(await response.arrayBuffer());
  if (bytes.byteLength > maxBytes) {
    throw new YmlGuardError("YML fetch failed: response exceeds size limit");
  }

  let catalog: TildaCatalog;
  try {
    catalog = parseTildaYml(new TextDecoder().decode(bytes));
  } catch (e) {
    const message = e instanceof Error ? e.message : String(e);
    throw new YmlGuardError(
      message.startsWith("Invalid YML") ? message : `Invalid YML: ${message}`,
    );
  }
  validateTildaCatalog(catalog);
  return {
    catalog,
    sizeBytes: bytes.byteLength,
    finalUrl: current.href,
  };
}

function parseHttpsUrl(raw: string): URL {
  let url: URL;
  try {
    url = new URL(raw);
  } catch {
    throw new YmlGuardError("TILDA_YML_URL is not a valid URL");
  }
  if (url.protocol !== "https:") {
    throw new YmlGuardError("TILDA_YML_URL must use HTTPS");
  }
  return url;
}

function validMoney(value: number | undefined): boolean {
  if (value === undefined || !Number.isFinite(value) || value < 0) return false;
  const cents = Math.round(value * 100);
  return Math.abs(value * 100 - cents) < 1e-6;
}
