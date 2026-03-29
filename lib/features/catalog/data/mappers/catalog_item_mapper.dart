import '../../domain/entities/catalog_item_entity.dart';
import '../dto/catalog_item_dto.dart';

extension CatalogItemMapper on CatalogItemDto {
  CatalogItemEntity toEntity() {
    return CatalogItemEntity(
      id: variantId,
      productId: productId,
      title: title,
      isActive: isActive,
      brand: brand,
      category: category,
      badge: mark,
      shortDescription: description,
      fullDescription: text,
      imageUrl: photo,
      price: price,
      oldPrice: oldPrice,
      quantity: quantity,
      edition: editions,
      modification: modifications,
      attributes: attributes,
    );
  }
}
