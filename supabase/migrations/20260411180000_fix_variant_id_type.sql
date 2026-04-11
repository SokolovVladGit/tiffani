-- Fix: order_request_items.variant_id is UUID in production but the system
-- contract is TEXT everywhere (catalog_items VIEW, Flutter DTOs, sync engine).
-- Safe for existing data: UUID values cast losslessly to TEXT.

ALTER TABLE public.order_request_items
  ALTER COLUMN variant_id TYPE TEXT
  USING variant_id::text;
