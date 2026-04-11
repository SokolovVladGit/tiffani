-- Enable RLS on order_request_items.
-- SELECT scoped to the order owner via order_requests.user_id.
-- INSERT open (supports both RPC SECURITY DEFINER and fallback direct insert).

ALTER TABLE public.order_request_items ENABLE ROW LEVEL SECURITY;

CREATE POLICY "Users can read own order items"
  ON public.order_request_items FOR SELECT
  USING (
    auth.uid() = (
      SELECT user_id FROM public.order_requests WHERE id = request_id
    )
  );

CREATE POLICY "Anyone can insert order items"
  ON public.order_request_items FOR INSERT
  WITH CHECK (true);
