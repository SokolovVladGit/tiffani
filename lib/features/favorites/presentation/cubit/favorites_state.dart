class FavoritesState {
  final Set<String> ids;
  final bool isLoading;

  const FavoritesState({
    this.ids = const {},
    this.isLoading = false,
  });

  bool isFavorite(String id) => ids.contains(id);

  FavoritesState copyWith({
    Set<String>? ids,
    bool? isLoading,
  }) {
    return FavoritesState(
      ids: ids ?? this.ids,
      isLoading: isLoading ?? this.isLoading,
    );
  }
}
