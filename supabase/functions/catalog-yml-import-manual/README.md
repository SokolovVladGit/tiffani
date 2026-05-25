# catalog-yml-import-manual

Admin-only fallback to import a **downloaded** Tilda YML/XML export when the public
`TILDA_YML_URL` feed is unavailable.

Automatic cron sync (`catalog-yml-sync-safe`) is unchanged.

## Safety policy

- Uses `parseTildaYml` + `upsertCatalogSlice` only.
- **No** `syncCatalog`, **no** `deactivateMissingProducts`.
- **No** deletes; **no** `is_active: false`; **no** variant hiding.
- Every run logs `metadata.no_deactivation: true`.
- `source_type`: `yml_manual_import`.

## Auth

- `verify_jwt = true` (see `supabase/config.toml`).
- Caller must send `Authorization: Bearer <user access token>` (admin session).
- Handler calls `rpc('is_admin')` with the user JWT — **not** email allowlist.
- DB writes use **service role** server-side only; never put service role in the app.

## Request

```http
POST /functions/v1/catalog-yml-import-manual
Authorization: Bearer <USER_ACCESS_TOKEN>
Content-Type: application/json
```

```json
{
  "yml_text": "<full XML string>",
  "dry_run": true,
  "filename": "export.xml",
  "source": "manual_admin_upload"
}
```

| Field       | Default               | Notes                                      |
|-------------|-----------------------|--------------------------------------------|
| `yml_text`  | —                     | Required, non-empty UTF-8 XML              |
| `dry_run`   | `true`                | Live only when **exactly** `false`           |
| `filename`  | `null`                | Metadata only                              |
| `source`    | `manual_admin_upload` | Stored in run metadata                     |

**Size limit:** `MAX_MANUAL_YML_UPLOAD_BYTES` env (default **20_000_000**). Exceeding
returns **413** with a hint that Storage-based import may be added later.

## Response (success)

Stable JSON with `run_id`, `mode`, `status`, `yml` metrics, seen/upserted counts,
`error_count`, `error_sample`, `warnings`, `no_deactivation: true`, and
`verdict: safe_to_proceed_to_live` on dry-run.

## Deploy

From repo root (so `config.toml` applies):

```bash
supabase functions deploy catalog-yml-import-manual --project-ref <ref>
```

Optional secret:

```bash
supabase secrets set MAX_MANUAL_YML_UPLOAD_BYTES=20000000 --project-ref <ref>
```

## Manual smoke checklist

1. Sign in as a user in `admin_users`.
2. In the app admin tab **Импорт YML**, pick a small valid Tilda export.
3. **Проверить файл** (dry-run) — counters > 0, `verdict` present, upserted = 0.
4. **Применить импорт** (confirm) — `status` completed, upserted > 0.
5. SQL: latest `catalog_sync_runs` with `source_type = 'yml_manual_import'`.
6. Invariants: duplicate `tilda_uid` / `variant_id` = 0.
7. Spot-check `catalog_items` for a known `variant_id`.
8. Confirm cron job `catalog-yml-sync-safe-every-30min` still active and unchanged.

## Tests

```bash
cd supabase/functions/catalog-yml-import-manual && deno task test
```
