class ProductImageDto {
  final String id;
  final String productId;
  final String url;
  final int position;

  const ProductImageDto({
    required this.id,
    required this.productId,
    required this.url,
    required this.position,
  });

  factory ProductImageDto.fromMap(Map<String, dynamic> map) {
    return ProductImageDto(
      id: map['id'] as String,
      productId: map['product_id'] as String,
      url: map['url'] as String,
      position: map['position'] as int,
    );
  }
}
