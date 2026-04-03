import '../entities/catalog_page_result.dart';
import '../entities/catalog_sort_option.dart';
import '../repositories/catalog_repository.dart';

class SearchCatalogUseCase {
  final CatalogRepository _repository;

  const SearchCatalogUseCase(this._repository);

  Future<CatalogPageResult> call({
    required String query,
    int from = 0,
    int to = 29,
    String? brand,
    String? category,
    String? mark,
    CatalogSortOption sortOption = CatalogSortOption.defaultOrder,
    Map<String, Set<String>>? attributeFilters,
    bool saleOnly = false,
  }) {
    return _repository.searchCatalog(
      query: query,
      from: from,
      to: to,
      brand: brand,
      category: category,
      mark: mark,
      sortOption: sortOption,
      attributeFilters: attributeFilters,
      saleOnly: saleOnly,
    );
  }
}
