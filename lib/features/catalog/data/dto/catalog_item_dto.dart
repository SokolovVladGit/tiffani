class CatalogItemDto {
  final String variantId;
  final String productId;
  final String? externalId;
  final String? tildaUid;
  final String title;
  final String? brand;
  final String? category;
  final String? mark;
  final String? description;
  final String? text;
  final String? photo;
  final bool isActive;
  final double? price;
  final double? oldPrice;
  final int? quantity;
  final String? editions;
  final String? modifications;
  final Map<String, dynamic>? attributes;

  const CatalogItemDto({
    required this.variantId,
    required this.productId,
    required this.title,
    required this.isActive,
    this.externalId,
    this.tildaUid,
    this.brand,
    this.category,
    this.mark,
    this.description,
    this.text,
    this.photo,
    this.price,
    this.oldPrice,
    this.quantity,
    this.editions,
    this.modifications,
    this.attributes,
  });

  factory CatalogItemDto.fromMap(Map<String, dynamic> map) {
    return CatalogItemDto(
      variantId: map['variant_id'] as String,
      productId: map['product_id'] as String,
      externalId: map['external_id'] as String?,
      tildaUid: map['tilda_uid'] as String?,
      title: map['title'] as String,
      brand: map['brand'] as String?,
      category: map['category'] as String?,
      mark: map['mark'] as String?,
      description: map['description'] as String?,
      text: map['text'] as String?,
      photo: map['photo'] as String?,
      isActive: _toBool(map['is_active']),
      price: _toDouble(map['price']),
      oldPrice: _toDouble(map['old_price']),
      quantity: map['quantity'] as int?,
      editions: map['editions'] as String?,
      modifications: map['modifications'] as String?,
      attributes: _toMap(map['attributes']),
    );
  }
}

Map<String, dynamic>? _toMap(dynamic value) {
  if (value == null) return null;
  if (value is Map<String, dynamic>) return value;
  if (value is Map) return Map<String, dynamic>.from(value);
  return null;
}

double? _toDouble(dynamic value) {
  if (value == null) return null;
  if (value is double) return value;
  if (value is int) return value.toDouble();
  if (value is String) return double.tryParse(value);
  return null;
}

bool _toBool(dynamic value) {
  if (value == null) return false;
  if (value is bool) return value;
  if (value is int) return value != 0;
  if (value is String) return value.toLowerCase() == 'true';
  return false;
}
