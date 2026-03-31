import '../repositories/catalog_repository.dart';

class GetAvailableCategoriesUseCase {
  final CatalogRepository _repository;

  const GetAvailableCategoriesUseCase(this._repository);

  /// Returns a deduplicated, alphabetically sorted list of category names.
  Future<List<String>> call() {
    return _repository.getAvailableCategories();
  }
}
