/// Phase 4 feature flag — controls whether the cart uses the discount-aware
/// `quote_order_v1` + `submit_order_v4` RPCs (true) or the legacy
/// `submit_order_v2` flow (false). Single switch, no remote config.
/// The value is a compile-time constant. Release builds cannot override it.
/// The false branch is not a supported checkout path: it has no idempotency
/// key and must not be enabled without a wrapper that keeps v2 pricing.
///
/// Release keeps this true. The false branch also hides quote UI and would
/// call `submit_order_v2`. That call is not idempotent, so this release does
/// not use it.
class DiscountPricingConfig {
  DiscountPricingConfig._();

  static const bool useDiscountPricingV1 = true;

  /// `submit_order_v4` is the idempotent checkout contract. `submit_order_v3`
  /// stays callable for older clients and is not idempotent: a lost response
  /// followed by another v3 call creates a second order.
  static const String submitOrderRpcName = useDiscountPricingV1
      ? 'submit_order_v4'
      : 'submit_order_v2';

  static const String quoteOrderRpcName = 'quote_order_v1';

  /// Used by the checkout page if it ever debounces quote calls. The current
  /// UI uses an explicit "Применить" button so this is reserved for future
  /// fulfillment-option-change auto re-quoting if needed.
  static const Duration quoteDebounce = Duration(milliseconds: 400);
}
