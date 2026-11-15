# TIFFANI baseline deployment

Пакет для пустого проекта `mnjxcoyvomgbdtwdhejq` (eu-central-1, Postgres 17).
Это не история удалённого проекта. `supabase db push` не запускался.
CARZON не использовать.

Файлы в `supabase/deploy/migrations/` побайтово совпадают с `supabase/recovery/0001`–`0009`.
Имена приведены к формату CLI: `YYYYMMDDHHMMSS_name.sql`.

## Порядок

| Файл | Источник | Зависит от |
| --- | --- | --- |
| `20261113190101_catalog_base.sql` | `0001_catalog_base.sql` | пустая `public` |
| `20261113190102_identity_and_orders.sql` | `0002_identity_and_orders.sql` | `auth.users` |
| `20261113190103_content_and_sync.sql` | `0003_content_and_sync.sql` | нет |
| `20261113190104_discounts.sql` | `0004_discounts.sql` | нет |
| `20261113190105_catalog_contract.sql` | `0005_catalog_contract.sql` | таблицы каталога |
| `20261113190106_checkout_rpcs.sql` | `0006_checkout_rpcs.sql` | view, скидки, заказы |
| `20261113190107_admin_rpcs.sql` | `0007_admin_rpcs.sql` | `admin_users`, каталог |
| `20261113190108_security.sql` | `0008_security.sql` | все таблицы и функции выше |
| `20261113190109_seed_info_blocks.sql` | `0009_seed_info_blocks.sql` | `info_blocks` |

Роли `anon`, `authenticated`, `service_role` уже есть на hosted Supabase.
`pg_cron` и `pg_net` эти девять файлов не создают и не вызывают.

## Что появится

Таблицы: `products`, `product_variants`, `product_images`, `profiles`, `admin_users`, `order_requests`, `order_request_items`, `consultation_requests`, `info_blocks`, `stores`, `delivery_rules`, `articles`, `article_blocks`, `catalog_sync_runs`, `catalog_sync_run_errors`, `discount_campaigns`, `discount_campaign_targets`, `discount_redemptions`.

View: `catalog_items` (`is_active AND app_is_visible`).

Функции: `is_admin`, `product_is_publicly_visible`, `get_distinct_brands`, `get_distinct_categories`, `get_distinct_marks`, `set_discount_campaigns_updated_at`, `_discount_text_match`, `quote_order_v1`, `submit_order_v2`, `submit_order_v3`, `submit_consultation_v1`, `admin_set_product_visibility`, `generate_admin_variant_id`, `admin_upsert_native_product`.

Seed: 5 строк `info_blocks`. Магазины, статьи, правила доставки и кампании скидок остаются пустыми.

## Как применять SQL

Только в SQL Editor проекта TIFFANI. Перед первым запросом сверить ref `mnjxcoyvomgbdtwdhejq`.

Вставлять файлы по одному, сверху вниз, каждый целиком. Не останавливаться на ошибке и не перескакивать файл.

Не применять `supabase/migrations/`. Там 34 исторических SQL, включая `20260404120001_setup_catalog_sync_cron.sql`, и `admin_upsert_native_product_contract.test.ts`. Пока эта папка — активный каталог CLI, `supabase db push` прогонит старую цепочку и поставит destructive cron.

Эти файлы из `supabase/migrations/` не переносились:

- все `*.sql` в `supabase/migrations/`
- `supabase/migrations/admin_upsert_native_product_contract.test.ts`

Их нужно убрать из активного каталога только отдельным решением владельца, до того как туда копируются девять файлов из `supabase/deploy/migrations/`. До этого момента hosted-применение — только вставка в SQL Editor. `supabase db push` и `supabase link` не делать.

## Проверка после девятого файла

Только чтение:

```sql
SELECT version, name
FROM supabase_migrations.schema_migrations
ORDER BY version;
```

Если SQL Editor не пишет в `schema_migrations`, эта выборка пустая. Это нормально для ручной вставки. Тогда проверить объекты:

```sql
SELECT c.relname
FROM pg_class c
JOIN pg_namespace n ON n.oid = c.relnamespace
WHERE n.nspname = 'public'
  AND c.relkind IN ('r', 'v')
ORDER BY 1;

SELECT pg_get_viewdef('public.catalog_items'::regclass) ILIKE '%app_is_visible%' AS view_filters_visibility;

SELECT count(*) AS info_blocks FROM public.info_blocks;

SELECT grantee, privilege_type
FROM information_schema.role_table_grants
WHERE table_schema = 'public'
  AND table_name = 'catalog_items'
  AND grantee IN ('anon', 'authenticated')
ORDER BY 1, 2;

SELECT has_schema_privilege('anon', 'public', 'CREATE') AS anon_create,
       has_schema_privilege('authenticated', 'public', 'CREATE') AS auth_create;

SELECT to_regnamespace('cron') AS cron_schema;
```

Ожидание: view фильтрует видимость; `info_blocks` = 5; у `anon` и `authenticated` на `catalog_items` только `SELECT`; `CREATE` на `public` у обеих ролей = false; `cron_schema` = NULL.

Полный поведенческий файл `supabase/recovery/tests/post_apply_contract.sql` откатывает свои вставки только если весь файл идёт одной транзакцией. SQL Editor, который коммитит каждый statement, для него не подходит.

## Политика admin_users и стоимость доставки

`admin_users_select` читает allowlist через `public.is_admin()`. Функция `SECURITY DEFINER`, поэтому политика не вызывает саму себя. Клиентского `INSERT` в `admin_users` нет. `anon` не имеет `SELECT`. Не-админ получает пустой набор.

Для известных `fulfillment_method_code` сервер ставит одну стоимость и в `quote_order_v1`, и в `submit_order_v3`, и в `submit_order_v2`:

| метод | fee |
| --- | --- |
| `pickup_store` | 0 |
| `courier_tiraspol` | 50 |
| `courier_bender` | 40 |
| `express_post` | 40 |
| `moldova_post` | 30 |

Это тариф текущего Flutter-чекаута (`FulfillmentOption`) и прежняя таблица в `submit_order_v2`. Другая сумма, ноль на платном методе и отрицательная сумма отклоняются (`fulfillment_fee_mismatch` / `invalid_fulfillment_fee`). Пропущенная сумма подставляется из таблицы. Пустой, отсутствующий или неизвестный `fulfillment_method_code` отклоняется и в quote, и в обоих submit. Клиентская сумма без метода не сохраняется. Quote не требует магазин и адрес: Flutter уже выбирает метод до первого quote, а адрес и магазин проверяет submit. Текст info-блока про доставку не является этой таблицей.

## Ручные шаги после схемы

1. Email provider и redirect `io.supabase.tiffani://auth-callback`.
2. Создать пользователя администратора.
3. Вставить одну строку, подставив новый Auth UUID:

```sql
INSERT INTO public.admin_users (user_id, email)
VALUES ('<new-auth-user-uuid>', '<admin-email>');
```

4. Flutter пока не переключать. `lib/core/di/core_di.dart` всё ещё указывает на удалённый проект `ebannnxkjtvmhchwjwsz`.
5. Edge Functions не деплоить. Cron не ставить. Секреты не вставлять в SQL.

Поздняя синхронизация YML описана в `YML_SYNC_DESIGN.md` и в этот пакет не входит.
