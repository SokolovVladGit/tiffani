import '../../../catalog/domain/entities/catalog_item_entity.dart';

abstract interface class HomeRepository {
  Future<List<CatalogItemEntity>> getNewItems({int limit = 10});
  Future<List<CatalogItemEntity>> getSaleItems({int limit = 10});
  Future<List<CatalogItemEntity>> getHitItems({int limit = 10});
}
