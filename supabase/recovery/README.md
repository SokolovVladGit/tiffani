# TIFFANI recovery baseline

Staged schema for a **new empty Supabase project**. These files are not in `supabase/migrations/` and are not applied by `supabase db push`.

Historical files in `supabase/migrations/` stay as reference. Do not replay them onto a new project.

## Migration order

Apply in filename order, as the database owner (SQL editor or local `psql`), on a database that already has Supabase `auth.users` and the roles `anon`, `authenticated`, `service_role`:

1. `0001_catalog_base.sql`
2. `0002_identity_and_orders.sql`
3. `0003_content_and_sync.sql`
4. `0004_discounts.sql`
5. `0005_catalog_contract.sql`
6. `0006_checkout_rpcs.sql`
7. `0007_admin_rpcs.sql`
8. `0008_security.sql`
9. `0009_seed_info_blocks.sql`

`0009` inserts the existing Info screen copy. A second apply skips a row when the same `block_type` and `sort_order` already exist. It does not update changed copy.

## Dependencies

- Supabase Auth schema. `profiles`, `admin_users`, `order_requests.user_id`, consultation and redemption user ids reference `auth.users`.
- Roles `anon`, `authenticated`, `service_role`.
- No `pg_cron`, no Vault, no Edge Function deploy, no storage buckets.

`catalog_items` is the public read contract. Base catalog tables are admin-only under RLS. The view is owner-rights (`security_invoker` left off, and pinned off on PostgreSQL 15+).

## Manual actions before any app traffic

1. Create the Supabase project. Do not link it to the deleted project.
2. Apply this directory only, after it is the sole active migration set (see strategy below).
3. Enable the Email provider.
4. Allow redirect `io.supabase.tiffani://auth-callback`.
5. Create a new Auth user.
6. Insert the first admin. There is no client insert policy:

```sql
INSERT INTO public.admin_users (user_id, email)
VALUES ('<new-auth-user-uuid>', '<admin-email>');
```

7. Replace the Flutter URL and publishable key in a later change. Do not reuse the deleted project key.
8. Do not schedule cron. Do not deploy `catalog-sync`.

`stores`, `delivery_rules`, `articles`, and `article_blocks` are created empty. Checkout pickup ids are app constants (`store_central`, `store_balka`, `store_bendery`) and are not foreign keys.

## Objects included

Tables: `products`, `product_variants`, `product_images`, `profiles`, `admin_users`, `order_requests`, `order_request_items`, `consultation_requests`, `info_blocks`, `stores`, `delivery_rules`, `articles`, `article_blocks`, `catalog_sync_runs`, `catalog_sync_run_errors`, `discount_campaigns`, `discount_campaign_targets`, `discount_redemptions`.

View: `catalog_items`.

Functions: `is_admin`, `product_is_publicly_visible`, `get_distinct_brands`, `get_distinct_categories`, `get_distinct_marks`, `set_discount_campaigns_updated_at`, `_discount_text_match`, `quote_order_v1`, `submit_order_v2`, `submit_order_v3`, `submit_consultation_v1`, `admin_set_product_visibility`, `generate_admin_variant_id`, `admin_upsert_native_product`.

Trigger: `trg_discount_campaigns_updated_at`.

Seed: `info_blocks` only.

## Excluded legacy objects

- Cron job `catalog-sync-every-10min`.
- Any call to Edge Function `catalog-sync` or `deactivateMissingProducts`.
- `pg_cron` and `pg_net`.
- A schedule for `catalog-yml-sync-safe` (later phase).
- `count_orphan_products` and `create_order_request_with_items` (not used by the current Flutter client).
- Historical open `INSERT` policies on `order_requests`, `order_request_items`, and `consultation_requests`.
- Product rows, orders, auth users, discount campaigns, store rows, articles.

## Security choices

- Anon can select `catalog_items` and images of visible products only.
- Anon cannot select `products` or `product_variants`.
- Hidden products are absent from `catalog_items`. Checkout therefore returns `unknown_variant` (v3) or `Variants not found` (v2), not `inactive_variant`.
- `product_images` public rows are gated by `product_is_publicly_visible()`. Admins still select every image through `is_admin()`.
- Order `user_id` is `auth.uid()` for a signed-in caller. A different client id returns `user_id_mismatch`. A guest who sends `user_id` gets `user_id_not_allowed`. `quote_order_v1` does not store an owner.
- Anon cannot execute admin RPCs or `is_admin`.
- Authenticated users can execute `is_admin`. Catalog and discount table policies still require a row in `admin_users`.
- `admin_users_select` is `USING (public.is_admin())`. The function is `SECURITY DEFINER`, so the policy does not query `admin_users` under its own RLS. There is still no client `INSERT` policy.
- `pickup_store` is 0, `courier_tiraspol` is 50, `courier_bender` is 40, `express_post` is 40, `moldova_post` is 30. `quote_order_v1`, `submit_order_v3`, and `submit_order_v2` share that table. A missing, empty, or unknown method is rejected. A different fee is `fulfillment_fee_mismatch`. A negative or non-numeric fee is `invalid_fulfillment_fee`. An omitted fee is filled from the method. There is no client fallback fee. Quote does not require a store id or a delivery address; submit does. Flutter always has a method selected before the first quote.
- Order and consultation rows are selectable only when `user_id = auth.uid()`.
- Guest checkout is the SECURITY DEFINER RPC, not a table insert.
- `submit_consultation_v1` stores `auth.uid()` and ignores a payload user id.
- Sync log tables have RLS and no policies. `service_role` can write them later.
- `is_admin`, `product_is_publicly_visible`, the three `get_distinct_*` functions, and `set_discount_campaigns_updated_at` use `search_path = pg_catalog` and schema-qualified names.
- `quote_order_v1`, `submit_order_v2`, and `submit_order_v3` keep `search_path = public, pg_temp`. Their SQL is unqualified and uses temp tables. An empty search_path would not resolve those names. Admin write RPCs stay on `search_path = public` for the same reason.
- Table owner is not `FORCE ROW LEVEL SECURITY`, so SECURITY DEFINER RPCs owned by the migration role can insert orders.

## Unresolved assumptions

- `products.price` / `old_price` and `order_request_items.price` / `old_price` are `numeric(12,2)`. YML numbers with more than two fraction digits round on write. No three-decimal price appeared in the parser tests.
- `total_price`, `line_total`, and `fulfillment_fee` stay `double precision`. Account history casts `total_price` as a JSON number, and that cast does not accept a numeric string.
- Discount math uses `numeric`. The old `/ 100.0` float divisor in `quote_order_v1` is now `/ 100`.
- `variant_id` has no `gen_random_uuid()` default. Current writers always pass it. A random default would mint non-canonical ids.
- `stores.id`, `delivery_rules.id`, `articles.id`, and `article_blocks.id` are `uuid`. Flutter only requires JSON strings.
- `article_blocks.items` is `text[]`. The DTO reads a list of strings. A historical jsonb column is not in the repo.
- `admin_users.user_id` references `auth.users`. The old table did not declare that foreign key.
- `product_images.id` is an internal uuid. Clients read `url` and `position`.
- Multiple `products.tilda_uid` NULLs are allowed. That is required for more than one native product.

## Local replay

Checked with Supabase CLI 2.106.0, Docker 29.4.0 via OrbStack, Postgres 17. The disposable project was outside this repo. `carzon` containers were left running. Nothing was linked to a hosted project.

```bash
mkdir -p "$HOME/tmp/tiffani-recovery-replay"
cd "$HOME/tmp/tiffani-recovery-replay"
supabase init --yes
```

Copy only `0001` through `0009` into that project's `supabase/migrations/`. Do not copy `supabase/migrations/` from this repo. In the disposable `config.toml`, set a unique `project_id` and move every host port off 54321–54329 if another local stack is up. This replay used `tiffani-recovery-replay-12`, API `55421`, database `55422`.

Confirm the target before reset:

- `supabase status -o json` shows `127.0.0.1` and the disposable port.
- There is no `project-ref` file.
- `docker port` for `supabase_db_<project_id>` is that same database port.

```bash
supabase start --yes
supabase db reset --local --yes --no-seed
docker exec -i supabase_db_<project_id> \
  psql -U postgres -d postgres -v ON_ERROR_STOP=1 \
  < /path/to/tiffani/supabase/recovery/tests/post_apply_contract.sql
```

`db reset --linked` and `db push` talk to a remote project. Do not use them here.

Phase 1.2 replay applied all nine files. `0006` prints a notice that `quote_order_v1` and `submit_order_v3` do not exist yet; those are the `DROP FUNCTION IF EXISTS` lines on a fresh database, not a failed migration.

## Verification

Static, no database:

```bash
python3 supabase/recovery/tests/static_contract_check.py
```

After a local apply:

```bash
psql "$LOCAL_DB_URL" -v ON_ERROR_STOP=1 -f supabase/recovery/tests/post_apply_contract.sql
```

That script checks types, grants, hidden catalog rows, public image visibility, legacy variant quotes, guest checkout, forged `user_id`, discount math, duplicate `variant_id`, and non-admin RPC rejection. It rolls back its inserts. It does not call Telegram. On local Supabase, `auth.uid()` reads `request.jwt.claim.sub`, so the signed-in mismatch case runs instead of skipping. A positive admin path needs a real Auth user and is covered by a JWT call, not by this file.

Useful queries:

```sql
SELECT column_name, data_type
FROM information_schema.columns
WHERE table_schema = 'public'
  AND table_name = 'order_request_items'
  AND column_name IN ('product_id', 'variant_id');

SELECT variant_id, product_id, legacy_variant_uuid, is_active
FROM public.catalog_items
LIMIT 5;

SELECT tablename, policyname, cmd, roles
FROM pg_policies
WHERE schemaname = 'public'
ORDER BY tablename, policyname;
```

If `cron` exists, this must return no rows:

```sql
SELECT jobname, schedule FROM cron.job
WHERE jobname ILIKE '%catalog-sync%' OR command ILIKE '%catalog-sync%';
```

## Local tooling checked with this baseline

- Supabase CLI `2.106.0`. `supabase db push` and `supabase db reset --linked` are remote. `supabase db reset --local` applies only the migrations directory of the project you point at.
- Docker was started with OrbStack. The isolated database did start, and the nine recovery files were applied there.
- `anon` and `authenticated` have `SELECT` only on `catalog_items`. `TRIGGER` / `TRUNCATE` / `REFERENCES` from Supabase default privileges are revoked in `0008`.

## How this becomes the active migration history

Do this only after review, and only on a project with an empty migration history:

1. Archive `supabase/migrations/*.sql` outside the active directory (for example `supabase/migrations_archive/`). Do not delete the git history.
2. Move `supabase/recovery/0001` through `0009` into `supabase/migrations/`. Leave `README.md` and `tests/` out of that directory so the CLI does not treat them as migrations.
3. Confirm `supabase/migrations/` contains only those nine files. If any `2026*.sql` file remains, the CLI will run the old chain after this baseline and fail or schedule the legacy sync.
4. Apply with the reviewed Supabase CLI command for that CLI version, or paste the nine files in order into the SQL editor.

Do not apply this baseline and the historical chain to the same database.

## Rollback

On a brand-new project that has no orders or catalog yet, drop the project or drop schema `public` objects and re-apply. Do not point a populated app database at this script. These files use `CREATE`, not `DROP TABLE`, so they do not wipe an existing schema; a second apply fails on the first existing table.

`0009` skips an info block when the same `block_type` and `sort_order` already exist. It does not refresh edited copy. The other files use `CREATE`, so a second apply of the whole chain fails on the first existing table.
