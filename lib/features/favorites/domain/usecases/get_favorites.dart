import '../repositories/favorites_repository.dart';

class GetFavorites {
  final FavoritesRepository _repository;

  const GetFavorites(this._repository);

  Future<Set<String>> call() => _repository.getFavorites();
}
