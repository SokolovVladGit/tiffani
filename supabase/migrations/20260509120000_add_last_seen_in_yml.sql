-- Observability: record when a product/variant last appeared in a live YML upsert.
-- Additive only: nullable columns, no defaults, no backfill, no catalog_items / RPC changes.

ALTER TABLE public.products
  ADD COLUMN IF NOT EXISTS last_seen_in_yml timestamptz NULL;

ALTER TABLE public.product_variants
  ADD COLUMN IF NOT EXISTS last_seen_in_yml timestamptz NULL;
