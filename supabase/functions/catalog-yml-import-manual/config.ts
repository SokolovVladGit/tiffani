/** Default upload cap when `MAX_MANUAL_YML_UPLOAD_BYTES` is unset (20 MB). */
export const DEFAULT_MAX_MANUAL_YML_UPLOAD_BYTES = 20_000_000;

/**
 * Reads the maximum allowed UTF-8 byte length for `yml_text` from the
 * environment. Invalid or missing values fall back to the default.
 */
export function loadMaxManualYmlUploadBytes(): number {
  const raw = Deno.env.get("MAX_MANUAL_YML_UPLOAD_BYTES");
  if (!raw) return DEFAULT_MAX_MANUAL_YML_UPLOAD_BYTES;
  const n = parseInt(raw, 10);
  return Number.isFinite(n) && n > 0
    ? n
    : DEFAULT_MAX_MANUAL_YML_UPLOAD_BYTES;
}
