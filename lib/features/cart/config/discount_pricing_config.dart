/// Phase 4 feature flag — controls whether the cart uses the discount-aware
/// `quote_order_v1` + `submit_order_v3` RPCs (true) or the legacy
/// `submit_order_v2` flow (false). Single switch, no remote config.
///
/// Flip to `false` to roll back to the legacy v2 path. When `false`:
///   - `quote_order_v1` is not called.
///   - `submit_order_v2` is used for order submission.
///   - The checkout UI hides the discount breakdown and the
///     "Применить промокод" button, falling back to the prior behavior
///     (raw promo code carried verbatim, manual application by the manager).
class DiscountPricingConfig {
  DiscountPricingConfig._();

  static const bool useDiscountPricingV1 = true;

  static const String submitOrderRpcName =
      useDiscountPricingV1 ? 'submit_order_v3' : 'submit_order_v2';

  static const String quoteOrderRpcName = 'quote_order_v1';

  /// Used by the checkout page if it ever debounces quote calls. The current
  /// UI uses an explicit "Применить" button so this is reserved for future
  /// fulfillment-option-change auto re-quoting if needed.
  static const Duration quoteDebounce = Duration(milliseconds: 400);
}
