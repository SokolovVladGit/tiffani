import '../../domain/entities/catalog_sort_option.dart';
import '../dto/catalog_item_dto.dart';
import '../dto/catalog_page_result_dto.dart';

abstract interface class CatalogSupabaseDataSource {
  Future<CatalogPageResultDto> getCatalogPage({
    required int from,
    required int to,
    String? brand,
    String? category,
    String? mark,
    CatalogSortOption sortOption = CatalogSortOption.defaultOrder,
    Map<String, Set<String>>? attributeFilters,
  });

  Future<CatalogPageResultDto> searchCatalog({
    required String query,
    int from = 0,
    int to = 29,
    String? brand,
    String? category,
    String? mark,
    CatalogSortOption sortOption = CatalogSortOption.defaultOrder,
    Map<String, Set<String>>? attributeFilters,
  });

  Future<CatalogItemDto?> getCatalogItemByVariantId(String variantId);

  Future<List<CatalogItemDto>> getCatalogItemsByVariantIds(List<String> ids);

  Future<List<String>> getAvailableBrands();
  Future<List<String>> getAvailableCategories();
  Future<List<String>> getAvailableMarks();
}
