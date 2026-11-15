-- TIFFANI recovery baseline 0003
-- Content tables required by the current Flutter client, plus sync audit logs.
-- No store addresses, articles, delivery prices, or sync history are seeded.
--
-- Assumptions where no historical CREATE TABLE exists:
--   stores.id, delivery_rules.id, articles.id, article_blocks.id are uuid.
--     Flutter reads those ids with `as String` (PostgREST uuid JSON is a string).
--   article_blocks.items is text[] because ArticleBlockDto parses a list of strings.
--   public.stores is not the checkout pickup list. Checkout slugs live in the app.

CREATE TABLE public.info_blocks (
  id           uuid        PRIMARY KEY DEFAULT gen_random_uuid(),
  block_type   text        NOT NULL,
  sort_order   integer     NOT NULL,
  title        text        NULL,
  subtitle     text        NULL,
  text_content text        NULL,
  image_url    text        NULL,
  items_json   jsonb       NULL,
  is_active    boolean     NOT NULL DEFAULT true,
  created_at   timestamptz NOT NULL DEFAULT now()
);

CREATE INDEX idx_info_blocks_sort
  ON public.info_blocks (sort_order)
  WHERE is_active = true;

CREATE TABLE public.stores (
  id            uuid             PRIMARY KEY DEFAULT gen_random_uuid(),
  title         text             NOT NULL,
  address       text             NOT NULL,
  phone         text             NULL,
  working_hours text             NULL,
  latitude      double precision NULL,
  longitude     double precision NULL,
  is_active     boolean          NOT NULL DEFAULT true,
  sort_order    integer          NOT NULL DEFAULT 0
);

COMMENT ON TABLE public.stores IS
  'Stores screen only. Empty until content is inserted manually. Not referenced by pickup_store_id.';

CREATE TABLE public.delivery_rules (
  id          uuid    PRIMARY KEY DEFAULT gen_random_uuid(),
  title       text    NOT NULL,
  description text    NULL,
  region      text    NULL,
  is_active   boolean NOT NULL DEFAULT true,
  sort_order  integer NOT NULL DEFAULT 0
);

COMMENT ON TABLE public.delivery_rules IS
  'Delivery screen only. No prices are invented here. Info-page copy is seeded separately in info_blocks.';

CREATE TABLE public.articles (
  id              uuid        PRIMARY KEY DEFAULT gen_random_uuid(),
  slug            text        NOT NULL UNIQUE,
  title           text        NOT NULL,
  excerpt         text        NULL,
  cover_image_url text        NULL,
  is_published    boolean     NOT NULL DEFAULT false,
  published_at    timestamptz NULL
);

CREATE INDEX idx_articles_published
  ON public.articles (published_at DESC)
  WHERE is_published = true;

CREATE TABLE public.article_blocks (
  id           uuid    PRIMARY KEY DEFAULT gen_random_uuid(),
  article_id   uuid    NOT NULL REFERENCES public.articles (id) ON DELETE CASCADE,
  block_type   text    NOT NULL,
  text_content text    NULL,
  image_url    text    NULL,
  caption      text    NULL,
  items        text[]  NOT NULL DEFAULT '{}',
  sort_order   integer NOT NULL DEFAULT 0
);

CREATE INDEX idx_article_blocks_article_sort
  ON public.article_blocks (article_id, sort_order);

CREATE TABLE public.catalog_sync_runs (
  id                uuid        PRIMARY KEY DEFAULT gen_random_uuid(),
  started_at        timestamptz NOT NULL DEFAULT now(),
  finished_at       timestamptz NULL,
  status            text        NOT NULL DEFAULT 'pending',
  source_type       text        NOT NULL DEFAULT 'yml',
  products_seen     integer     DEFAULT 0,
  variants_seen     integer     DEFAULT 0,
  images_seen       integer     DEFAULT 0,
  products_upserted integer     DEFAULT 0,
  variants_upserted integer     DEFAULT 0,
  images_upserted   integer     DEFAULT 0,
  error_count       integer     DEFAULT 0,
  metadata          jsonb       NULL
);

CREATE INDEX idx_catalog_sync_runs_started
  ON public.catalog_sync_runs (started_at DESC);

CREATE TABLE public.catalog_sync_run_errors (
  id           uuid        PRIMARY KEY DEFAULT gen_random_uuid(),
  run_id       uuid        NOT NULL REFERENCES public.catalog_sync_runs (id) ON DELETE CASCADE,
  stage        text        NOT NULL,
  external_key text        NOT NULL DEFAULT '',
  message      text        NOT NULL,
  details      jsonb       NULL,
  created_at   timestamptz NOT NULL DEFAULT now()
);

CREATE INDEX idx_catalog_sync_run_errors_run
  ON public.catalog_sync_run_errors (run_id);

COMMENT ON TABLE public.catalog_sync_runs IS
  'Audit log for a future catalog-yml-sync-safe run. This baseline does not schedule that job.';
