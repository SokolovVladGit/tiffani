/// Minimal item payload for `submit_order_v2`.
/// Server resolves all other fields from `catalog_items`.
class RequestItemPayloadDto {
  final String variantId;
  final int quantity;

  const RequestItemPayloadDto({
    required this.variantId,
    required this.quantity,
  });

  Map<String, dynamic> toMap() {
    return {
      'variant_id': variantId,
      'quantity': quantity,
    };
  }
}
