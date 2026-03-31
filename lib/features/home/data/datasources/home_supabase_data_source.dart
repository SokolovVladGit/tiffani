import '../../../catalog/data/dto/catalog_item_dto.dart';

abstract interface class HomeSupabaseDataSource {
  Future<List<CatalogItemDto>> getNewItems({int limit = 10});
  Future<List<CatalogItemDto>> getSaleItems({int limit = 10});
  Future<List<CatalogItemDto>> getHitItems({int limit = 10});
}
