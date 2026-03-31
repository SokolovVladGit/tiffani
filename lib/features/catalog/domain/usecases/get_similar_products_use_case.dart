import '../entities/catalog_item_entity.dart';
import '../repositories/catalog_repository.dart';

class GetSimilarProductsUseCase {
  final CatalogRepository _repository;

  const GetSimilarProductsUseCase(this._repository);

  /// Returns up to [limit] similar products, excluding [excludeId].
  /// Matches by brand + category, then category, then brand.
  Future<List<CatalogItemEntity>> call({
    required String excludeId,
    String? brand,
    String? category,
    int limit = 10,
  }) {
    return _repository.getSimilarProducts(
      excludeId: excludeId,
      brand: brand,
      category: category,
      limit: limit,
    );
  }
}
