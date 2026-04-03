CREATE OR REPLACE FUNCTION get_distinct_brands()
RETURNS SETOF TEXT
LANGUAGE sql
STABLE
SECURITY DEFINER
AS $$
  SELECT DISTINCT brand
  FROM catalog_items
  WHERE is_active = true
    AND brand IS NOT NULL
    AND brand != ''
  ORDER BY brand;
$$;

CREATE OR REPLACE FUNCTION get_distinct_categories()
RETURNS SETOF TEXT
LANGUAGE sql
STABLE
SECURITY DEFINER
AS $$
  SELECT DISTINCT category
  FROM catalog_items
  WHERE is_active = true
    AND category IS NOT NULL
    AND category != ''
  ORDER BY category;
$$;

CREATE OR REPLACE FUNCTION get_distinct_marks()
RETURNS SETOF TEXT
LANGUAGE sql
STABLE
SECURITY DEFINER
AS $$
  SELECT DISTINCT mark
  FROM catalog_items
  WHERE is_active = true
    AND mark IS NOT NULL
    AND mark != ''
  ORDER BY mark;
$$;
