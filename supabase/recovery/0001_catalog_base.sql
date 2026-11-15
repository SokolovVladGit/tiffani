-- TIFFANI recovery baseline 0001
-- Base catalog tables. Historical migrations never created these.
-- Column types are taken from the final RPCs, Flutter DTOs, and the YML upsert payload.
--
-- Assumptions (no historical CREATE TABLE exists):
--   products.id / product_variants.id / product_images.product_id are uuid
--   price / old_price are numeric(12,2). YML values with extra fraction digits round.
--   Flutter price parsers accept JSON numbers and numeric strings.
--   quantity is integer (CatalogItemDto `as int?`, submit_order `::INT`)
--   variant_id has no random default: sync and admin_upsert always supply it
--   multiple NULL products.tilda_uid values are allowed (native products)

CREATE TABLE public.products (
  id                uuid        PRIMARY KEY DEFAULT gen_random_uuid(),
  tilda_uid         text        NULL,
  title             text        NOT NULL,
  brand             text        NULL,
  category          text        NULL,
  mark              text        NULL,
  description       text        NULL,
  text              text        NULL,
  photo             text        NULL,
  external_id       text        NULL,
  is_active         boolean     NOT NULL DEFAULT true,
  app_is_visible    boolean     NOT NULL DEFAULT true,
  last_seen_in_yml  timestamptz NULL,
  created_at        timestamptz NOT NULL DEFAULT now()
);

COMMENT ON TABLE public.products IS
  'Catalog product. tilda_uid IS NULL means app-native and must stay outside YML upsert.';

COMMENT ON COLUMN public.products.is_active IS
  'Source/import active flag. YML upsert of a present offer sets this true. Not the public hide switch.';

COMMENT ON COLUMN public.products.app_is_visible IS
  'Admin visibility. Public catalog_items.is_active is is_active AND app_is_visible. YML sync must not write this column.';

COMMENT ON COLUMN public.products.mark IS
  'Curated label (NEW, ХИТ). Omitted from the YML product payload so sync does not overwrite it.';

-- NULLS DISTINCT is the PostgreSQL default: many native rows may have tilda_uid NULL.
CREATE UNIQUE INDEX idx_products_tilda_uid_unique
  ON public.products (tilda_uid);

CREATE INDEX idx_products_app_is_visible
  ON public.products (app_is_visible);

CREATE TABLE public.product_variants (
  id                uuid             PRIMARY KEY DEFAULT gen_random_uuid(),
  product_id        uuid             NOT NULL REFERENCES public.products (id) ON DELETE CASCADE,
  variant_id        text             NOT NULL,
  title             text             NULL,
  price             numeric(12,2)    NULL,
  old_price         numeric(12,2)    NULL,
  quantity          integer          NULL,
  photo             text             NULL,
  editions          text             NULL,
  modifications     text             NULL,
  external_id       text             NULL,
  tilda_uid         text             NULL,
  attributes        jsonb            NULL,
  last_seen_in_yml  timestamptz      NULL
);

COMMENT ON COLUMN public.product_variants.price IS
  'Exact rubles. numeric(12,2). Not double precision.';

COMMENT ON COLUMN public.product_variants.variant_id IS
  'Canonical SKU key. Tilda offer id, or admin_<hex> for native products. TEXT, not uuid.';

COMMENT ON COLUMN public.product_variants.id IS
  'Internal uuid. Exposed as catalog_items.legacy_variant_uuid for old cart lines.';

CREATE UNIQUE INDEX idx_product_variants_variant_id_unique
  ON public.product_variants (variant_id);

CREATE INDEX idx_product_variants_product_id
  ON public.product_variants (product_id);

CREATE TABLE public.product_images (
  id          uuid    PRIMARY KEY DEFAULT gen_random_uuid(),
  product_id  uuid    NOT NULL REFERENCES public.products (id) ON DELETE CASCADE,
  url         text    NOT NULL,
  position    integer NOT NULL DEFAULT 0
);

-- Conflict target for the YML image upsert: onConflict (product_id, url).
CREATE UNIQUE INDEX idx_product_images_product_url_unique
  ON public.product_images (product_id, url);

CREATE INDEX idx_product_images_product_position
  ON public.product_images (product_id, position);

COMMENT ON TABLE public.product_images IS
  'Gallery rows. Upsert conflict key is (product_id, url). id is internal only; Flutter reads url and position.';
