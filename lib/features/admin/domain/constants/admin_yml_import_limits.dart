/// Client-side cap aligned with Edge Function `MAX_MANUAL_YML_UPLOAD_BYTES`
/// default (20 MB). Server enforces the authoritative limit.
abstract final class AdminYmlImportLimits {
  static const int maxUploadBytes = 20_000_000;
}
