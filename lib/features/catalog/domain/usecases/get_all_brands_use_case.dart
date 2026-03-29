import '../repositories/catalog_repository.dart';

class GetAllBrandsUseCase {
  final CatalogRepository _repository;

  const GetAllBrandsUseCase(this._repository);

  /// Returns a deduplicated, alphabetically sorted list of brand names.
  Future<List<String>> call() {
    return _repository.getAvailableBrands();
  }
}
