class CatalogItemEntity {
  final String id;
  final String productId;
  final String title;
  final bool isActive;
  final String? brand;
  final String? category;
  final String? badge;
  final String? shortDescription;
  final String? fullDescription;
  final String? imageUrl;
  final double? price;
  final double? oldPrice;
  final int? quantity;
  final String? edition;
  final String? modification;
  final Map<String, dynamic>? attributes;

  const CatalogItemEntity({
    required this.id,
    required this.productId,
    required this.title,
    required this.isActive,
    this.brand,
    this.category,
    this.badge,
    this.shortDescription,
    this.fullDescription,
    this.imageUrl,
    this.price,
    this.oldPrice,
    this.quantity,
    this.edition,
    this.modification,
    this.attributes,
  });
}
