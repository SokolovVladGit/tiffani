class RequestItemPayloadDto {
  final String requestId;
  final String variantId;
  final String productId;
  final String title;
  final String? brand;
  final String? imageUrl;
  final double? price;
  final int quantity;
  final String? edition;
  final String? modification;

  const RequestItemPayloadDto({
    required this.requestId,
    required this.variantId,
    required this.productId,
    required this.title,
    this.brand,
    this.imageUrl,
    this.price,
    required this.quantity,
    this.edition,
    this.modification,
  });

  Map<String, dynamic> toMap() {
    return {
      'request_id': requestId,
      'variant_id': variantId,
      'product_id': productId,
      'title': title,
      'brand': brand,
      'image_url': imageUrl,
      'price': price,
      'quantity': quantity,
      'edition': edition,
      'modification': modification,
    };
  }
}
