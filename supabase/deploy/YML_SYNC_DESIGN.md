# YML sync: разрыв и проект сверки видимости

Схема из `migrations/` этого каталога видимость по отсутствию в YML не меняет.
Функция `catalog-yml-sync-safe` в этом этапе не менялась.

Наблюдение 2026-11-13, GET без редиректа, HTTP 200, `application/xml`, 6 337 986 байт, около 1 с:

- корень `yml_catalog`, `date=2026-11-13T21:22:01+03:00`
- 2900 offer, 2900 уникальных id, 81 категория
- 1567 group_id и 313 offer без group
- размеры групп: чаще 1, максимум 30
- у каждого offer ровно один `<picture>`
- атрибута `available` нет ни у одного offer
- у всех цен два знака после запятой
- offer `901688024194` и group `404334589874` в этом снимке отсутствуют

Снимок 2901 до скрытия в Tilda здесь повторно не скачивался. Текущий фид совпадает с описанным состоянием «после».

## Что уже делает safe sync

`catalog-yml-sync-safe` качает `TILDA_YML_URL` с timeout по умолчанию 30 с и User-Agent `TiffaniCatalogYmlSyncSafe/1.0`. Редиректы Deno `fetch` идут по умолчанию, хост ответа не проверяется. Сегодняшний URL редиректа не дал.

Парсер требует `yml_catalog.shop`. Offer без id выбрасывается. Дубли id не схлопываются. `available` считается истинным, пока строка не равна `false`. Пустой атрибут, как в этом фиде, значит «доступен».

Ключ товара: `group_id`, иначе id offer. Ключ варианта: id offer. Цена, oldprice и count пишутся в variant. Категория — имя из `categories`, без пути. Конфликт: `products.tilda_uid`, `product_variants.variant_id`, `product_images (product_id, url)`.

Повторный прогон обновляет те же ключи. Обрыв на батче не откатывает уже записанные батчи; вариант при ошибке батча повторяется построчно, картинки батча — нет. Следующий успешный прогон догоняет upsert-ом.

Пустой, но формально валидный `<shop>` парсится как 0 offer. Порога полноты нет. Live-режим при этом ничего не удаляет: `deactivateMissingProducts` не вызывается, `is_active: false` не пишется. Отчёт missing-candidates только читает `products.tilda_uid` активных не-native строк и сравнивает его с объединением offer id и group id. Действие отчёта всегда `none`.

Нативный товар (`tilda_uid IS NULL`, `variant_id` с префиксом `admin_`) этим конфликтом не находится. `app_is_visible` в payload нет, админский флаг upsert не затирает. `is_active: true` пишется на каждый присутствующий товар.

Логи: `catalog_sync_runs.source_type = yml_safe_sync`, ошибки в `catalog_sync_run_errors`. Dry-run по умолчанию. Live только при `dry_run: false`. Ручной импорт — отдельная функция `catalog-yml-import-manual`, тот же upsert, `source_type = yml_manual_import`, JWT и `is_admin`.

## Почему `is_active` не годится

`products.is_active` — флаг строки товара. Публичный view уже требует `is_active AND app_is_visible`. Upsert ставит `is_active = true` на весь товар, если в фиде осталась хотя бы одна строка группы.

Один пропавший offer при живых соседях не делает group id отсутствующим. Missing-candidates такой offer не видит: он не читает `product_variants`. Спрятать весь товар из-за одного offer нельзя, и `is_active` для этого слишком крупный.

`app_is_visible` — ручной флаг админа. Его синхронизация не пишет.

Нужна отдельная колонка варианта, не эти два поля.

## Проект сверки, без миграции в этом этапе

Добавить позже, отдельным SQL, не в девятку baseline:

```sql
ALTER TABLE public.product_variants
  ADD COLUMN source_listed boolean NOT NULL DEFAULT true;

COMMENT ON COLUMN public.product_variants.source_listed IS
  'Offer присутствует в подтверждённом полном YML. Не is_active и не app_is_visible.';

CREATE TABLE public.yml_variant_misses (
  variant_id          text        PRIMARY KEY,
  consecutive_feeds   integer     NOT NULL,
  last_run_id         uuid        NULL,
  updated_at          timestamptz NOT NULL DEFAULT now()
);
```

Без FK на заказы и без `ON DELETE` товаров. Строки каталога эта таблица не удаляет.

Правило, которое поддерживается наблюдением «offer исчезает целиком, флага false нет»:

- Считать фид полным только после HTTP 200, успешного parse, `offers > 0`, уникальных id = числу offer и падения числа offer не больше заданного порога относительно прошлого полного прогона. Первый полный прогон порог только запоминает и никого не прячет.
- Порог не хардкодить как 2900. Каталог растёт. Стартовое значение снять с первого полного фида.
- 0 offer, обрыв HTTP, timeout, не-XML и чужой хост после редиректа — не полный фид. Счётчик пропусков не растёт.
- Для варианта с `products.tilda_uid IS NOT NULL` и `variant_id` не `admin_%`: id есть в фиде — сразу `source_listed = true` и удалить строку пропуска. Id нет — увеличить `consecutive_feeds` один раз на этот прогон.
- `source_listed = false` только когда `consecutive_feeds` достиг N. N минимум 2: одного отсутствия мало. Конкретное N — параметр, не измеренная задержка Tilda.
- Возврат offer в полном фиде восстанавливает `source_listed` сразу, без ожидания N.
- Соседние варианты той же группы не трогать.
- `is_active`, `app_is_visible`, native-строки, картинки, заказы не менять и не удалять.
- Публичный `catalog_items` в этой девятке колонку не читает. Пока view не сузят отдельно, флаг на витрину не влияет. Это сознательно отдельный шаг.

## Картинки

Сейчас в фиде одна картинка на offer. Парсер уже умеет несколько `<picture>` по порядку и без дублей, но вторичных URL в этом снимке нет. Добирать галерею со страниц Tilda не нужно.

Первичное `products.photo` — первая картинка первого offer группы в порядке XML. `product_variants.photo` — первая картинка своего offer. `product_images` — все картинки всех offer группы, позиция растёт по offer и по `<picture>`. Повтор обновляет позицию по ключу `(product_id, url)`.

Старые URL не удаляются. После смены картинки прежняя строка остаётся, и позиция может совпасть с новой. Flutter сортирует по `position`. Если `group_id` offer сменится, upsert варианта перенесёт `product_id`, а старая картинка останется на прежнем товаре.

Публичная политика картинок смотрит на товар (`is_active AND app_is_visible`), не на вариант. Скрытие одного offer само по себе не уберёт его URL из галереи группы. Для этого нужна отдельная связь картинки с offer. Пока её нет, безопаснее не удалять `product_images`.

## Cron на 15 минут, не включать

Не создавать job. Не вызывать `catalog-sync`. Не планировать `catalog-sync-every-10min`.

Когда синхронизацию разрешат отдельно:

- функция остаётся `catalog-yml-sync-safe`, тело `{"dry_run":false,"source":"cron"}`
- `verify_jwt = true`, поэтому cron-вызов несёт ключ из Vault, не из SQL в репозитории и не из клиента
- перед live проверить, что нет незавершённого `catalog_sync_runs` этой функции; два параллельных прогона сейчас не запрещены
- неполный фид не двигает `source_listed`
- `app_is_visible` cron не пишет
- ошибка fetch/parse уже пишет `status = failed` и не делает upsert
- старый `catalog-sync` не деплоить

Секреты нового проекта, значения не записывать в репозиторий: `TILDA_YML_URL` на постоянный YML, платформенные `SUPABASE_URL` и `SUPABASE_SERVICE_ROLE_KEY`, для уведомлений `TELEGRAM_BOT_TOKEN`, `TELEGRAM_CHAT_ID` и `ORDER_NOTIFY_WORKER_SECRET`. `consultation-notify` ждёт `verify_jwt = false`. `order-notify` тоже деплоится с `verify_jwt = false`, но вызывается только сервером и без worker secret заказ не читает. Это настройка деплоя функций, не этой схемы.
