# catalog-yml-sync-safe

Safe automatic Tilda YML sync for the TIFFANI catalog. Pulls the full
YML feed, parses it, and upserts products / variants / images via the
already-safe `upsertCatalogSlice` path.

## Status

v1 — implemented in repo, **not yet deployed**, **not yet scheduled**.
Manual dry-run and live verification must pass before any cron is
enabled.

## Purpose

When new products are added in Tilda, this function (once scheduled)
brings them into Supabase, where Flutter clients pick them up through
the `catalog_items` view. v1 is upsert-only: it never deactivates,
never deletes, and never modifies admin-curated rows.

## Safety guarantees

The function is structurally constrained — `safety-contract.test.ts`
fails the build if any of these is violated:

- No import or call to `syncCatalog`.
- No reference to `deactivateMissingProducts`.
- No `is_active: false` write anywhere.
- No call to the legacy `/functions/v1/catalog-sync` endpoint.
- No call to any Tilda REST product API endpoint.
- The `missing-candidates` helper uses only `select` — never
  `update`, `delete`, `upsert`, `insert`, or `rpc`.
- Only products with `tilda_uid IS NOT NULL` are inspected by the
  diff; admin products with `tilda_uid IS NULL` are unreachable by
  the `ON CONFLICT (tilda_uid)` upsert key as well.
- The dry-run is the default; live writes require the request body to
  contain literally `"dry_run": false`.
- Every run is stamped with `metadata.no_deactivation = true` for
  monitoring.

## Endpoint

```
POST /functions/v1/catalog-yml-sync-safe
Authorization: Bearer <SUPABASE_SERVICE_ROLE_KEY>
Content-Type: application/json
```

`verify_jwt = true` is pinned in `supabase/config.toml`, so anonymous
invocation is rejected before the function body runs.

### Request body

```json
{ "dry_run": true,  "source": "manual" }
```

| Field     | Type    | Required | Default       | Notes                                                              |
|-----------|---------|----------|---------------|--------------------------------------------------------------------|
| `dry_run` | boolean | no       | `true`        | Live writes require **exactly** `false`. Any other value is dry-run. |
| `source`  | string  | no       | `"manual"`    | Informational. Stored in `catalog_sync_runs.metadata.source`.       |

### Dry-run response (truncated example)

```json
{
  "mode": "dry_run",
  "run_id": "uuid",
  "status": "dry_run_completed",
  "duration_ms": 1234,
  "yml": {
    "size_bytes": 12345678,
    "categories_count": 81,
    "groups_count": 1353,
    "offers_count": 2640,
    "offers_with_picture": 2200,
    "images_in_yml": 5500
  },
  "products_seen": 1353,
  "products_upserted": 0,
  "variants_seen": 2640,
  "variants_upserted": 0,
  "images_seen": 5500,
  "images_upserted": 0,
  "error_count": 0,
  "error_sample": [],
  "missing_candidates": {
    "active_products_with_tilda_uid_in_db": 1234,
    "absent_from_current_yml": 12,
    "sample": ["1841...", "2354..."],
    "action_taken": "none"
  },
  "verdict": "safe_to_proceed_to_live"
}
```

### Live response (truncated example)

```json
{
  "mode": "live",
  "run_id": "uuid",
  "status": "completed",
  "duration_ms": 18342,
  "yml": { "categories_count": 81, "groups_count": 1353, "offers_count": 2640 },
  "products_seen": 1353,
  "products_upserted": 1353,
  "variants_seen": 2640,
  "variants_upserted": 2640,
  "images_seen": 5500,
  "images_upserted": 5500,
  "error_count": 0,
  "error_sample": [],
  "missing_candidates": {
    "active_products_with_tilda_uid_in_db": 1234,
    "absent_from_current_yml": 12,
    "sample": ["..."],
    "action_taken": "none"
  }
}
```

## Environment variables

| Name                            | Required | Default                          | Notes |
|---------------------------------|----------|----------------------------------|-------|
| `TILDA_YML_URL`                 | yes      | —                                | Full URL to the Tilda YML feed. |
| `SUPABASE_URL`                  | yes (auto)| set by Supabase platform        | Auto-set on every Edge Function. |
| `SUPABASE_SERVICE_ROLE_KEY`     | yes (auto)| set by Supabase platform        | Auto-set; required for upsert + log writes. |
| `SYNC_REQUEST_TIMEOUT_MS`       | no       | `30000`                          | HTTP timeout for the YML fetch. |
| `SYNC_USER_AGENT`               | no       | `TiffaniCatalogYmlSyncSafe/1.0`  | UA header used for the YML fetch. |
| `SAFE_SYNC_REPORT_MISSING`      | no       | enabled                          | Set to `false` or `0` to skip the missing-candidates diff. |
| `SAFE_SYNC_MISSING_SAMPLE_LIMIT`| no       | `20` (max `100`)                 | UID samples returned in the response. |

Secrets are configured via `supabase secrets set` and never stored in
the repo.

## Manual dry-run (placeholder token only)

```bash
curl -X POST \
  "https://<project-ref>.supabase.co/functions/v1/catalog-yml-sync-safe" \
  -H "Authorization: Bearer <SERVICE_ROLE_KEY_PLACEHOLDER>" \
  -H "Content-Type: application/json" \
  -d '{ "dry_run": true, "source": "manual" }'
```

## Manual live invocation (placeholder token only)

Run this only after the dry-run returns `verdict: "safe_to_proceed_to_live"`
and all verification SQL below passes.

```bash
curl -X POST \
  "https://<project-ref>.supabase.co/functions/v1/catalog-yml-sync-safe" \
  -H "Authorization: Bearer <SERVICE_ROLE_KEY_PLACEHOLDER>" \
  -H "Content-Type: application/json" \
  -d '{ "dry_run": false, "source": "manual" }'
```

## Verification SQL

Run **before** the live invocation; record the values.

```sql
-- 1. Duplicate Tilda product UIDs (must be 0)
SELECT count(*) AS dup_tilda_uid
FROM (
  SELECT tilda_uid FROM products
  WHERE tilda_uid IS NOT NULL
  GROUP BY tilda_uid HAVING count(*) > 1
) d;

-- 2. Duplicate variant_id (must be 0)
SELECT count(*) AS dup_variant_id
FROM (
  SELECT variant_id FROM product_variants
  WHERE variant_id IS NOT NULL
  GROUP BY variant_id HAVING count(*) > 1
) d;

-- 3. Orphan variants (must be 0)
SELECT count(*) AS orphan_variants
FROM product_variants pv
LEFT JOIN products p ON p.id = pv.product_id
WHERE p.id IS NULL;

-- 4. Admin products snapshot (record this value)
SELECT count(*) AS admin_products_pre
FROM products WHERE tilda_uid IS NULL;

-- 5. Inactive products snapshot (record this value)
SELECT count(*) AS inactive_products_pre
FROM products WHERE is_active = false;

-- 6. catalog_items canonical contract smoke
SELECT variant_id, product_id, legacy_variant_uuid, title, is_active
FROM catalog_items
WHERE variant_id = '184192311111';
```

Run **after** the live invocation:

```sql
-- 7. Admin products invariant — MUST equal pre-snapshot
SELECT count(*) AS admin_products_post
FROM products WHERE tilda_uid IS NULL;

-- 8. Inactive products — MUST be ≤ pre-snapshot
SELECT count(*) AS inactive_products_post
FROM products WHERE is_active = false;

-- 9. Latest yml_safe_sync runs
SELECT id, status, started_at, finished_at,
       products_seen, products_upserted,
       variants_seen, variants_upserted,
       images_seen,   images_upserted,
       error_count,   metadata
FROM catalog_sync_runs
WHERE source_type = 'yml_safe_sync'
ORDER BY started_at DESC LIMIT 5;

-- 10. Errors of the most recent yml_safe_sync run
WITH last AS (
  SELECT id FROM catalog_sync_runs
  WHERE source_type = 'yml_safe_sync'
  ORDER BY started_at DESC LIMIT 1
)
SELECT stage, external_key, left(message, 200) AS msg, created_at
FROM catalog_sync_run_errors
WHERE run_id = (SELECT id FROM last)
ORDER BY created_at DESC LIMIT 50;
```

`products` has no `updated_at` in production. Verification relies on
`created_at` and run logs only.

## Image handling

The YML parser preserves every `<picture>` URL per offer in source
order and deduplicates them. `upsertCatalogSlice` writes one row to
`product_images` per distinct URL with stable per-product positions
(`0` for the first picture, then incrementing). The conflict key is
`(product_id, url)`, so subsequent runs are idempotent: positions are
updated in place without creating duplicates.

`products.photo` and `product_variants.photo` keep the legacy
single-image semantics — they store the first picture URL, preserving
backward compatibility with the Flutter DTO and `catalog_items`.

## Operational reminders

- **Cron must NOT be enabled** until at least one manual dry-run and
  one manual live invocation pass with all verification SQL clean.
- The legacy `catalog-sync-every-10min` cron job (if present) MUST be
  unscheduled before any new schedule is created. The legacy job
  invokes the parked `catalog-sync` function which deactivates missing
  products.
- Disable schedule (when eventually enabled):
  ```sql
  SELECT cron.unschedule('catalog-yml-sync-safe-every-30min');
  ```
- Disable the function entirely:
  ```bash
  supabase functions delete catalog-yml-sync-safe --project-ref <ref>
  ```

## Files

| File | Purpose |
|------|---------|
| `index.ts` | Edge Function entry point. |
| `config.ts` | Environment config loader. |
| `run-logger.ts` | `catalog_sync_runs` / `catalog_sync_run_errors` lifecycle. |
| `missing-candidates.ts` | Read-only diff between active DB rows and current YML keys. |
| `safety-contract.test.ts` | Structural guards (no syncCatalog, no deactivation, no Tilda REST). |
| `missing-candidates.test.ts` | Unit tests for the read-only diff helper. |
