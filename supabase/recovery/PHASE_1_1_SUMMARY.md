# Phase 1.1 — что изменено

Только `supabase/recovery/`. Исторические миграции не менялись. SQL на PostgreSQL не прогонялся: Docker daemon и `psql` на этой машине отсутствуют.

## Каталог

- `catalog_items` возвращает только строки с `products.is_active AND products.app_is_visible`. Колонка `is_active` в DTO остаётся и для этих строк равна true.
- Скрытый товар больше не даёт `inactive_variant`. `quote_order_v1` / `submit_order_v3` возвращают `unknown_variant`. `submit_order_v2` бросает `Variants not found`. Заказ в обоих случаях отклоняется.
- Аноним читает `product_images` только если `product_is_publicly_visible(product_id)`. Админ по-прежнему видит все картинки через `is_admin()`.
- Прямого `SELECT` на `products` и `product_variants` у `anon` нет.

## Заказы

- Подписанный заказчик: владелец = `auth.uid()`. Чужой или невалидный `user_id` в payload — отказ (`user_id_mismatch`).
- Гость: `user_id` заказа = NULL. Любой переданный `user_id` — отказ (`user_id_not_allowed`).
- Сигнатуры `submit_order_v2(jsonb, jsonb)` и `submit_order_v3(jsonb, jsonb)` те же. `quote_order_v1` владельца не пишет.

## Деньги

- `product_variants.price` / `old_price` и `order_request_items.price` / `old_price` — `numeric(12,2)`.
- `order_requests.total_price`, `order_request_items.line_total`, `fulfillment_fee` остаются `double precision`: история заказов кастует `total_price` как JSON number.
- Скидка делится на `100`, не на `100.0`.

## Seed

- `0009` не вставляет повтор, если уже есть строка с тем же `block_type` и `sort_order`. Уникального ограничения нет. Текст не обновляется.

## Phase 1.2

Локальный реплей на Postgres 17 прошёл. Комментарий `order_request_items.price` перенесён ниже `CREATE TABLE`. С view `catalog_items` у `anon` и `authenticated` снят лишний `TRIGGER`/`TRUNCATE`/`REFERENCES`.

