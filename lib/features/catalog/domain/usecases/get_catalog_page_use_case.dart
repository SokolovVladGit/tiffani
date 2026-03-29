import '../entities/catalog_page_result.dart';
import '../entities/catalog_sort_option.dart';
import '../repositories/catalog_repository.dart';

class GetCatalogPageUseCase {
  final CatalogRepository _repository;

  const GetCatalogPageUseCase(this._repository);

  Future<CatalogPageResult> call({
    required int from,
    required int to,
    String? brand,
    String? category,
    String? mark,
    CatalogSortOption sortOption = CatalogSortOption.defaultOrder,
    Map<String, Set<String>>? attributeFilters,
  }) {
    return _repository.getCatalogPage(
      from: from,
      to: to,
      brand: brand,
      category: category,
      mark: mark,
      sortOption: sortOption,
      attributeFilters: attributeFilters,
    );
  }
}
