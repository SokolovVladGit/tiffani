import '../../domain/entities/recently_viewed_item.dart';

class RecentlyViewedItemDto {
  final String id;
  final String title;
  final String? imageUrl;
  final double? price;
  final double? oldPrice;
  final String? brand;

  const RecentlyViewedItemDto({
    required this.id,
    required this.title,
    this.imageUrl,
    this.price,
    this.oldPrice,
    this.brand,
  });

  factory RecentlyViewedItemDto.fromMap(Map<String, dynamic> map) {
    return RecentlyViewedItemDto(
      id: map['id'] as String,
      title: map['title'] as String,
      imageUrl: map['image_url'] as String?,
      price: _toDouble(map['price']),
      oldPrice: _toDouble(map['old_price']),
      brand: map['brand'] as String?,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'title': title,
      'image_url': imageUrl,
      'price': price,
      'old_price': oldPrice,
      'brand': brand,
    };
  }

  factory RecentlyViewedItemDto.fromEntity(RecentlyViewedItem entity) {
    return RecentlyViewedItemDto(
      id: entity.id,
      title: entity.title,
      imageUrl: entity.imageUrl,
      price: entity.price,
      oldPrice: entity.oldPrice,
      brand: entity.brand,
    );
  }

  RecentlyViewedItem toEntity() {
    return RecentlyViewedItem(
      id: id,
      title: title,
      imageUrl: imageUrl,
      price: price,
      oldPrice: oldPrice,
      brand: brand,
    );
  }
}

double? _toDouble(dynamic value) {
  if (value == null) return null;
  if (value is double) return value;
  if (value is int) return value.toDouble();
  if (value is String) return double.tryParse(value);
  return null;
}
