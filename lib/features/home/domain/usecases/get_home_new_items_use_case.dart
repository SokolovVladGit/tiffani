import '../../../catalog/domain/entities/catalog_item_entity.dart';
import '../repositories/home_repository.dart';

class GetHomeNewItemsUseCase {
  final HomeRepository _repository;

  const GetHomeNewItemsUseCase(this._repository);

  Future<List<CatalogItemEntity>> call({int limit = 10}) =>
      _repository.getNewItems(limit: limit);
}
