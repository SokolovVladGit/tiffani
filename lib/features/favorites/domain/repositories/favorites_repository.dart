abstract interface class FavoritesRepository {
  Future<Set<String>> getFavorites();
  Future<void> toggleFavorite(String id);
  Future<bool> isFavorite(String id);
  Future<void> clearFavorites();
}
