import '../repositories/favorites_repository.dart';

class IsFavorite {
  final FavoritesRepository _repository;

  const IsFavorite(this._repository);

  Future<bool> call(String id) => _repository.isFavorite(id);
}
