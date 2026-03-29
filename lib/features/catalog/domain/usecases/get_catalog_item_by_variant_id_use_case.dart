import '../entities/catalog_item_entity.dart';
import '../repositories/catalog_repository.dart';

class GetCatalogItemByVariantIdUseCase {
  final CatalogRepository _repository;

  const GetCatalogItemByVariantIdUseCase(this._repository);

  Future<CatalogItemEntity?> call(String variantId) {
    return _repository.getCatalogItemByVariantId(variantId);
  }
}
