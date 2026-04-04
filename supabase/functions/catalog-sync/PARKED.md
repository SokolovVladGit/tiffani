# Tilda Catalog Sync — PARKED

**Status**: Parked / Experimental
**Parked date**: 2026-04-04
**Reason**: Catalog management moved to internal admin panel.

## What this is

Autonomous server-side sync from Tilda YML export into:
- `products` (base table)
- `product_variants` (base table)
- `product_images` (base table)

## Current state

- Code is complete and tested
- Edge Function is deployed but should NOT be invoked automatically
- Cron job must be **disabled** in production

## How to disable cron (if active)

```sql
SELECT cron.unschedule('catalog-sync-every-10min');
```

## How to re-enable (if ever needed)

1. Re-apply the cron schedule from `20260404120001_setup_catalog_sync_cron.sql`
2. Ensure secrets are set: `TILDA_YML_URL`, `app.settings.service_role_key`, `app.settings.supabase_url`
3. Optionally set `ENABLE_GALLERY_ENRICHMENT=true`

## Safe manual invocation (for testing only)

```bash
curl -X POST \
  "https://<project-ref>.supabase.co/functions/v1/catalog-sync" \
  -H "Authorization: Bearer <service-role-key>" \
  -H "Content-Type: application/json" \
  -d '{"source":"manual-test"}'
```

## Files

| File | Purpose |
|------|---------|
| `index.ts` | Edge Function entry point |
| `config.ts` | Environment config loader |
| `sync-engine.ts` | Product/variant/image upsert logic |
| `yml-parser.ts` | Tilda YML XML parser |
| `gallery-enricher.ts` | Gallery image scraper (disabled by default) |
| `types.ts` | TypeScript interfaces |
