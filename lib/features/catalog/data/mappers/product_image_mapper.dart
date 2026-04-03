import '../../domain/entities/product_image_entity.dart';
import '../dto/product_image_dto.dart';

extension ProductImageMapper on ProductImageDto {
  ProductImageEntity toEntity() {
    return ProductImageEntity(
      id: id,
      productId: productId,
      url: url,
      position: position,
    );
  }
}
