/// Server response from `submit_order_v2` (legacy fields only) or
/// `submit_order_v3` (legacy + Phase 1 snapshot fields).
///
/// All Phase 1 snapshot fields are nullable so this entity can be parsed
/// tolerantly from either RPC response shape.
class OrderResultEntity {
  // Legacy v2 contract (always present).
  final String orderId;
  final int totalItems;
  final int totalQuantity;
  final double totalPrice;

  // Phase 1 snapshot fields — populated by submit_order_v3, NULL on v2.
  final double? subtotalAmount;
  final double? discountAmount;
  final double? fulfillmentFee;
  final double? grandTotalAmount;
  final String? pricingVersion;
  final String? promoStatus;
  final String? promoMessage;

  const OrderResultEntity({
    required this.orderId,
    required this.totalItems,
    required this.totalQuantity,
    required this.totalPrice,
    this.subtotalAmount,
    this.discountAmount,
    this.fulfillmentFee,
    this.grandTotalAmount,
    this.pricingVersion,
    this.promoStatus,
    this.promoMessage,
  });

  /// Final amount the customer actually paid. Prefers v3 [grandTotalAmount]
  /// when present, otherwise falls back to v2 [totalPrice] (which is the
  /// item subtotal under the v2 contract — fee handling lives elsewhere).
  double get effectivePayableAmount => grandTotalAmount ?? totalPrice;

  bool get hasDiscount => (discountAmount ?? 0) > 0;
}
