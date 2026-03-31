import '../repositories/catalog_repository.dart';

class GetAvailableMarksUseCase {
  final CatalogRepository _repository;

  const GetAvailableMarksUseCase(this._repository);

  /// Returns a deduplicated, alphabetically sorted list of marks.
  Future<List<String>> call() {
    return _repository.getAvailableMarks();
  }
}
