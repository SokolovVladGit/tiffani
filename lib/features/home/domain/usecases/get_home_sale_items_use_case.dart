import '../../../catalog/domain/entities/catalog_item_entity.dart';
import '../repositories/home_repository.dart';

class GetHomeSaleItemsUseCase {
  final HomeRepository _repository;

  const GetHomeSaleItemsUseCase(this._repository);

  Future<List<CatalogItemEntity>> call({int limit = 10}) =>
      _repository.getSaleItems(limit: limit);
}
