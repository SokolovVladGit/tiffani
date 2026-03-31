import '../../../../core/services/logger_service.dart';
import '../../domain/entities/catalog_item_entity.dart';
import '../../domain/entities/catalog_page_result.dart';
import '../../domain/entities/catalog_sort_option.dart';
import '../../domain/repositories/catalog_repository.dart';
import '../datasources/catalog_supabase_data_source.dart';
import '../mappers/catalog_item_mapper.dart';

class CatalogRepositoryImpl implements CatalogRepository {
  final CatalogSupabaseDataSource _dataSource;
  final LoggerService _logger;

  const CatalogRepositoryImpl(this._dataSource, this._logger);

  @override
  Future<CatalogPageResult> getCatalogPage({
    required int from,
    required int to,
    String? brand,
    String? category,
    String? mark,
    CatalogSortOption sortOption = CatalogSortOption.defaultOrder,
    Map<String, Set<String>>? attributeFilters,
  }) async {
    _logger.d('CatalogRepositoryImpl.getCatalogPage');
    final result = await _dataSource.getCatalogPage(
      from: from,
      to: to,
      brand: brand,
      category: category,
      mark: mark,
      sortOption: sortOption,
      attributeFilters: attributeFilters,
    );
    return CatalogPageResult(
      items: result.items.map((d) => d.toEntity()).toList(),
      totalCount: result.totalCount,
    );
  }

  @override
  Future<CatalogPageResult> searchCatalog({
    required String query,
    int from = 0,
    int to = 29,
    String? brand,
    String? category,
    String? mark,
    CatalogSortOption sortOption = CatalogSortOption.defaultOrder,
    Map<String, Set<String>>? attributeFilters,
  }) async {
    final result = await _dataSource.searchCatalog(
      query: query,
      from: from,
      to: to,
      brand: brand,
      category: category,
      mark: mark,
      sortOption: sortOption,
      attributeFilters: attributeFilters,
    );
    return CatalogPageResult(
      items: result.items.map((d) => d.toEntity()).toList(),
      totalCount: result.totalCount,
    );
  }

  @override
  Future<CatalogItemEntity?> getCatalogItemByVariantId(
    String variantId,
  ) async {
    final dto = await _dataSource.getCatalogItemByVariantId(variantId);
    return dto?.toEntity();
  }

  @override
  Future<List<CatalogItemEntity>> getCatalogItemsByVariantIds(
    List<String> ids,
  ) async {
    final dtos = await _dataSource.getCatalogItemsByVariantIds(ids);
    return dtos.map((d) => d.toEntity()).toList();
  }

  @override
  Future<List<String>> getAvailableBrands() =>
      _dataSource.getAvailableBrands();

  @override
  Future<List<String>> getAvailableCategories() =>
      _dataSource.getAvailableCategories();

  @override
  Future<List<String>> getAvailableMarks() =>
      _dataSource.getAvailableMarks();

  @override
  Future<List<CatalogItemEntity>> getSimilarProducts({
    required String excludeId,
    String? brand,
    String? category,
    int limit = 10,
  }) async {
    final dtos = await _dataSource.getSimilarProducts(
      excludeId: excludeId,
      brand: brand,
      category: category,
      limit: limit,
    );
    return dtos.map((d) => d.toEntity()).toList();
  }
}
