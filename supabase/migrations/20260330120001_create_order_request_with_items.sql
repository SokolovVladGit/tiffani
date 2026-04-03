CREATE OR REPLACE FUNCTION create_order_request_with_items(
  p_request JSONB,
  p_items JSONB
)
RETURNS UUID
LANGUAGE plpgsql
SECURITY DEFINER
AS $$
DECLARE
  v_request_id UUID;
  v_item JSONB;
BEGIN
  INSERT INTO order_requests (
    customer_name,
    phone,
    comment,
    total_items,
    total_quantity,
    total_price,
    status,
    source
  )
  VALUES (
    p_request->>'customer_name',
    p_request->>'phone',
    p_request->>'comment',
    (p_request->>'total_items')::INT,
    (p_request->>'total_quantity')::INT,
    (p_request->>'total_price')::DOUBLE PRECISION,
    COALESCE(p_request->>'status', 'new'),
    COALESCE(p_request->>'source', 'mobile_app')
  )
  RETURNING id INTO v_request_id;

  FOR v_item IN SELECT * FROM jsonb_array_elements(p_items)
  LOOP
    INSERT INTO order_request_items (
      request_id,
      variant_id,
      product_id,
      title,
      brand,
      image_url,
      price,
      quantity,
      edition,
      modification
    )
    VALUES (
      v_request_id,
      v_item->>'variant_id',
      v_item->>'product_id',
      v_item->>'title',
      v_item->>'brand',
      v_item->>'image_url',
      (v_item->>'price')::DOUBLE PRECISION,
      (v_item->>'quantity')::INT,
      v_item->>'edition',
      v_item->>'modification'
    );
  END LOOP;

  RETURN v_request_id;
END;
$$;
