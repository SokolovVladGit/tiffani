import '../../domain/repositories/favorites_repository.dart';
import '../datasources/favorites_local_data_source.dart';

class FavoritesRepositoryImpl implements FavoritesRepository {
  final FavoritesLocalDataSource _localDataSource;

  const FavoritesRepositoryImpl(this._localDataSource);

  @override
  Future<Set<String>> getFavorites() => _localDataSource.getFavorites();

  @override
  Future<void> toggleFavorite(String id) async {
    final current = await _localDataSource.getFavorites();
    if (current.contains(id)) {
      current.remove(id);
    } else {
      current.add(id);
    }
    await _localDataSource.saveFavorites(current);
  }

  @override
  Future<bool> isFavorite(String id) async {
    final current = await _localDataSource.getFavorites();
    return current.contains(id);
  }

  @override
  Future<void> clearFavorites() async {
    await _localDataSource.saveFavorites({});
  }
}
