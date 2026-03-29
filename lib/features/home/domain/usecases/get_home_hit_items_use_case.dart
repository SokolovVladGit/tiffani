import '../../../catalog/domain/entities/catalog_item_entity.dart';
import '../repositories/home_repository.dart';

class GetHomeHitItemsUseCase {
  final HomeRepository _repository;

  const GetHomeHitItemsUseCase(this._repository);

  Future<List<CatalogItemEntity>> call({int limit = 10}) =>
      _repository.getHitItems(limit: limit);
}
