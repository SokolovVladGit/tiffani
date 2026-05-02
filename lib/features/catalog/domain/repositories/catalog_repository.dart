import '../entities/catalog_item_entity.dart';
import '../entities/catalog_page_result.dart';
import '../entities/catalog_sort_option.dart';
import '../entities/product_image_entity.dart';

abstract interface class CatalogRepository {
  Future<CatalogPageResult> getCatalogPage({
    required int from,
    required int to,
    String? brand,
    String? category,
    String? mark,
    CatalogSortOption sortOption = CatalogSortOption.defaultOrder,
    Map<String, Set<String>>? attributeFilters,
    bool saleOnly = false,
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
    bool saleOnly = false,
  });

  Future<CatalogItemEntity?> getCatalogItemByVariantId(String variantId);

  /// Best-effort product display resolver by `products.id` (as stored in
  /// `catalog_items.product_id`). Intended for admin discount target UI
  /// where a campaign's `target_value` is a product_id and the UI must
  /// show title/brand/category/image instead of a raw UUID. Returns
  /// `null` when no active variant exists for the product.
  Future<CatalogItemEntity?> getCatalogItemByProductId(String productId);

  Future<List<CatalogItemEntity>> getCatalogItemsByVariantIds(List<String> ids);

  Future<List<String>> getAvailableBrands();
  Future<List<String>> getAvailableCategories();
  Future<List<String>> getAvailableMarks();

  Future<List<CatalogItemEntity>> getSimilarProducts({
    required String excludeId,
    String? brand,
    String? category,
    int limit = 10,
  });

  Future<List<ProductImageEntity>> getProductImages(String productId);
}
