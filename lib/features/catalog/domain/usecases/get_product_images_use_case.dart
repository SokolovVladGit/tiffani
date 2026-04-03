import '../entities/product_image_entity.dart';
import '../repositories/catalog_repository.dart';

class GetProductImagesUseCase {
  final CatalogRepository _repository;

  const GetProductImagesUseCase(this._repository);

  Future<List<ProductImageEntity>> call(String productId) {
    return _repository.getProductImages(productId);
  }
}
