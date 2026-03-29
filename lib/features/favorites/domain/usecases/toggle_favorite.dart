import '../repositories/favorites_repository.dart';

class ToggleFavorite {
  final FavoritesRepository _repository;

  const ToggleFavorite(this._repository);

  Future<void> call(String id) => _repository.toggleFavorite(id);
}
