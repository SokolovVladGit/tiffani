/// Result of `quote_order_v1`. Backend is the source of truth for all
/// pricing; Flutter only renders these fields.
///
/// Always non-throwing: a failed quote sets [ok] = false and populates
/// [errors]; a successful quote sets [ok] = true and populates the
/// monetary fields plus the optional promo / applied-discount metadata.
class OrderQuoteEntity {
  final bool ok;
  final String? pricingVersion;

  // Money (zero defaults are safe — caller can use isDiscountAware to
  // decide whether to render the discount line).
  final double subtotalAmount;
  final double discountAmount;
  final double fulfillmentFee;
  final double grandTotalAmount;

  /// Status of the user-supplied promo code, if any. Examples:
  /// `applied`, `not_provided`, `not_found`, `inactive`, `expired`,
  /// `limit_reached`, `min_order_not_met`, `no_matching_items`,
  /// `not_best_discount`, `no_promo_input`.
  final String? promoStatus;
  final String? promoMessage;

  /// Pre-formatted user-facing labels for each applied campaign, in display
  /// order. Examples:
  ///   - "Промокод применён: TEST10 (-10%)"
  ///   - "Скидка: Brand A −10% (-10%)"
  final List<String> appliedDiscountLabels;

  /// Errors from the quoter (only populated when [ok] = false).
  final List<OrderQuoteErrorEntity> errors;

  const OrderQuoteEntity({
    required this.ok,
    this.pricingVersion,
    this.subtotalAmount = 0,
    this.discountAmount = 0,
    this.fulfillmentFee = 0,
    this.grandTotalAmount = 0,
    this.promoStatus,
    this.promoMessage,
    this.appliedDiscountLabels = const [],
    this.errors = const [],
  });

  bool get hasDiscount => discountAmount > 0;
}

class OrderQuoteErrorEntity {
  final String code;
  final String message;
  final String? variantId;

  const OrderQuoteErrorEntity({
    required this.code,
    required this.message,
    this.variantId,
  });
}
