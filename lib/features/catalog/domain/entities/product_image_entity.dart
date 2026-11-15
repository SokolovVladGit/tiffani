class ProductImageEntity {
  final String id;
  final String productId;
  final String url;
  final int position;

  /// `yml_variant`, `tilda_gallery`, or null for a legacy/native row.
  final String? source;

  const ProductImageEntity({
    required this.id,
    required this.productId,
    required this.url,
    required this.position,
    this.source,
  });
}
