import '../../domain/entities/catalog_sort_option.dart';
import '../dto/catalog_item_dto.dart';
import '../dto/catalog_page_result_dto.dart';
import '../dto/product_image_dto.dart';

abstract interface class CatalogSupabaseDataSource {
  Future<CatalogPageResultDto> getCatalogPage({
    required int from,
    required int to,
    String? brand,
    String? category,
    String? mark,
    CatalogSortOption sortOption = CatalogSortOption.defaultOrder,
    Map<String, Set<String>>? attributeFilters,
    bool saleOnly = false,
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
    bool saleOnly = false,
  });

  Future<CatalogItemDto?> getCatalogItemByVariantId(String variantId);

  /// Best-effort lookup of a single active catalog row by `product_id`.
  /// A product may have multiple variants — the first active variant is
  /// returned purely for display (title/brand/category/image) in admin
  /// discount target UI. Returns `null` when the product has no active
  /// variants in the catalog view.
  Future<CatalogItemDto?> getCatalogItemByProductId(String productId);

  Future<List<CatalogItemDto>> getCatalogItemsByVariantIds(List<String> ids);

  Future<List<String>> getAvailableBrands();
  Future<List<String>> getAvailableCategories();
  Future<List<String>> getAvailableMarks();

  Future<List<CatalogItemDto>> getSimilarProducts({
    required String excludeId,
    String? brand,
    String? category,
    int limit = 10,
  });

  Future<List<ProductImageDto>> getProductImages(String productId);
}
