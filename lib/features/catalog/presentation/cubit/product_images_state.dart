import '../../domain/entities/product_image_entity.dart';

enum ProductImagesStatus { initial, loading, success, failure }

class ProductImagesState {
  final ProductImagesStatus status;
  final List<ProductImageEntity> images;

  const ProductImagesState({
    this.status = ProductImagesStatus.initial,
    this.images = const [],
  });

  bool get hasMultiple => images.length > 1;

  ProductImagesState copyWith({
    ProductImagesStatus? status,
    List<ProductImageEntity>? images,
  }) {
    return ProductImagesState(
      status: status ?? this.status,
      images: images ?? this.images,
    );
  }
}
