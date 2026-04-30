# catalog-refill

Targeted, idempotent refill of Tilda products into Supabase. Uses the
existing YML feed as the single canonical content source; `/tproduct/<uid>`
is used only as a UID-existence probe.

## Modes

### Dry run (default)

Classifies UIDs. Writes nothing to catalog tables. Optionally logs a
`catalog_sync_runs` row with `source_type='refill'` and
`status='dry_run_completed'`.

### Live (`dry_run: false`)

- Classifies UIDs.
- Synthesizes a `TildaCatalog` slice containing only offers for UIDs in
  the `found_in_yml_offer` and `found_in_yml_group` buckets.
- Calls `upsertCatalogSlice` (from `catalog-sync/sync-engine.ts`) which
  runs phases 1–3 only (products → variants → images).
- **Never** calls `deactivateMissingProducts`.
- Updates the run row with counters + status, and persists any per-row
  errors into `catalog_sync_run_errors`.

## Buckets

| bucket | dry-run action | live action |
|---|---|---|
| `found_in_yml_offer` | counted | upsert via YML offer |
| `found_in_yml_group` | counted | upsert all YML offers in the group |
| `needs_manual_review` | counted | **skipped** — present on `/tproduct` but absent from YML |
| `tilda_gone` | counted | **skipped** — 404 on `/tproduct`, delisted |
| `probe_error` | counted | **skipped** — probe failure; retry separately |
| `invalid_uid` | counted | **skipped** — failed `^\d{6,20}$` |

## Safety invariants

Enforced structurally and by tests:

1. `upsertCatalogSlice` does not import, reference, or invoke
   `deactivateMissingProducts`. Verified by static test
   `upsert-slice-contract.test.ts`.
2. `is_active` is only ever written as `true` (via
   `buildProductRow`). Verified by the same static test.
3. Admin-curated products have `tilda_uid IS NULL` and therefore
   cannot match `ON CONFLICT (tilda_uid)`; upsert cannot reach them.
4. `variant_id` is carried from the YML offer id; never randomized
   by the refill path.
5. `dry_run` defaults to `true`. Live writes require an explicit
   `dry_run: false`.
6. Re-running with the same UID list is idempotent — upserts collapse
   to no-ops when data has not changed.
7. No refill path ever issues DELETE; rollback is achieved by not
   re-running and, if needed, re-running the full YML sync.

## Request

```http
POST /functions/v1/catalog-refill
Authorization: Bearer <service-role-key>
Content-Type: application/json

{
  "uids": ["184192311111", "235435906681", "..."],
  "dry_run": true
}
```

- `dry_run` defaults to `true`.
- `uids` is required, non-empty; max `REFILL_MAX_UIDS` (default 2000).

## Response (live mode)

```jsonc
{
  "mode": "live",
  "run_id": "…",
  "status": "completed",           // or "completed_with_errors" | "failed"
  "classifier": {
    "total": 100,
    "counts": { "found_in_yml_offer": 80, "found_in_yml_group": 5,
                "needs_manual_review": 3, "tilda_gone": 10,
                "probe_error": 2, "invalid_uid": 0 },
    "samples": { /* up to REFILL_SAMPLE_LIMIT per bucket */ },
    "yml_meta": { "offers_count": 2431, "groups_count": 1203,
                  "categories_count": 38 },
    "dry_run": false,
    "generated_at": "…"
  },
  "slice_metrics": {
    "offers_included": 92,
    "products_included": 85,
    "duplicates_collapsed": 3,
    "invalid_offers_skipped": 0,
    "unresolved_classifications": 0,
    "skipped_by_bucket": { "needs_manual_review": 3, "tilda_gone": 10,
                            "probe_error": 2 }
  },
  "upsert": {
    "products_seen": 85,
    "variants_seen": 92,
    "images_seen": 80,
    "products_upserted": 85,
    "variants_upserted": 92,
    "images_upserted": 80,
    "error_count": 0,
    "error_sample": []
  }
}
```

## Environment

Required:
- `TILDA_YML_URL`
- `SUPABASE_URL` (auto-set inside Supabase runtime)
- `SUPABASE_SERVICE_ROLE_KEY` (auto-set inside Supabase runtime)

Optional:
- `REFILL_TIMEOUT_MS` (default `20000`)
- `REFILL_USER_AGENT` (default `TiffaniCatalogRefill/0.1`)
- `REFILL_PROBE_CONCURRENCY` (default `3`)
- `REFILL_TPRODUCT_BASE_URL` (default `https://tiffani.md`)
- `REFILL_SAMPLE_LIMIT` (default `20`)
- `REFILL_MAX_UIDS` (default `2000`)

## Local invocation

```bash
supabase functions serve catalog-refill \
  --env-file supabase/functions/.env.local
# env file must set TILDA_YML_URL; SUPABASE_URL + SUPABASE_SERVICE_ROLE_KEY
# are injected by the CLI.

# Dry run (safe default):
curl -X POST http://127.0.0.1:54321/functions/v1/catalog-refill \
  -H 'Authorization: Bearer <local-service-role-key>' \
  -H 'Content-Type: application/json' \
  -d '{"uids":["184192311111","235435906681"], "dry_run": true}'

# Live (writes to DB, but ONLY for YML-found UIDs; never deactivates):
curl -X POST http://127.0.0.1:54321/functions/v1/catalog-refill \
  -H 'Authorization: Bearer <local-service-role-key>' \
  -H 'Content-Type: application/json' \
  -d '{"uids":["184192311111","235435906681"], "dry_run": false}'
```

## Production invocation

```bash
curl -X POST \
  "https://<project-ref>.supabase.co/functions/v1/catalog-refill" \
  -H 'Authorization: Bearer <service-role-key>' \
  -H 'Content-Type: application/json' \
  -d @- <<'JSON'
{"uids":[...1858 UIDs from failed_uids.txt...], "dry_run": true}
JSON
```

Once the dry-run summary looks correct (`found_in_yml_*` counts match
expectations; `needs_manual_review` is small and acceptable), re-run
with `"dry_run": false`. The same call is safe to retry.

## Rollback expectation

- Refill never deletes or deactivates rows.
- Re-running is idempotent (upsert + stable `variant_id` contract).
- If refill worsens data, run the full YML sync once (`catalog-sync`),
  which is the authoritative source and will reconcile.

## Local tests

```bash
cd supabase/functions/catalog-refill
deno test --allow-env --allow-net --allow-read
```

`--allow-read` is required by `upsert-slice-contract.test.ts`, which
performs a structural guard against regression of the deactivation
invariant.
