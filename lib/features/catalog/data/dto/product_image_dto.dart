class ProductImageDto {
  final String id;
  final String productId;
  final String url;
  final int position;
  final String? source;

  const ProductImageDto({
    required this.id,
    required this.productId,
    required this.url,
    required this.position,
    this.source,
  });

  factory ProductImageDto.fromMap(Map<String, dynamic> map) {
    return ProductImageDto(
      id: map['id'] as String,
      productId: map['product_id'] as String,
      url: map['url'] as String,
      position: map['position'] as int,
      source: map['source'] as String?,
    );
  }
}
