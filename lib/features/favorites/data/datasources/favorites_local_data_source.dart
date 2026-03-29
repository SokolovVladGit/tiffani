abstract interface class FavoritesLocalDataSource {
  Future<Set<String>> getFavorites();
  Future<void> saveFavorites(Set<String> ids);
}
