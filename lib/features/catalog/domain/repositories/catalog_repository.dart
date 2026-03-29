import '../entities/catalog_item_entity.dart';
import '../entities/catalog_page_result.dart';
import '../entities/catalog_sort_option.dart';

abstract interface class CatalogRepository {
  Future<CatalogPageResult> getCatalogPage({
    required int from,
    required int to,
    String? brand,
    String? category,
    String? mark,
    CatalogSortOption sortOption = CatalogSortOption.defaultOrder,
    Map<String, Set<String>>? attributeFilters,
  });

  Future<CatalogPageResult> searchCatalog({
    required String query,
    int from = 0,
    int to = 29,
    String? brand,
    String? category,
    String? mark,
    CatalogSortOption sortOption = CatalogSortOption.defaultOrder,
    Map<String, Set<String>>? attributeFilters,
  });

  Future<CatalogItemEntity?> getCatalogItemByVariantId(String variantId);

  Future<List<CatalogItemEntity>> getCatalogItemsByVariantIds(List<String> ids);

  Future<List<String>> getAvailableBrands();
  Future<List<String>> getAvailableCategories();
  Future<List<String>> getAvailableMarks();
}
