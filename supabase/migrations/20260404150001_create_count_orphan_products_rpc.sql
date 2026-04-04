-- RPC: returns the number of products that have zero variants.
-- Used by the admin dashboard for catalog health diagnostics.
CREATE OR REPLACE FUNCTION public.count_orphan_products()
RETURNS bigint
LANGUAGE sql
STABLE
SECURITY DEFINER
AS $$
  SELECT count(*)
  FROM products p
  LEFT JOIN product_variants v ON v.product_id = p.id
  WHERE v.id IS NULL;
$$;
