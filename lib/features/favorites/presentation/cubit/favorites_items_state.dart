import '../../../catalog/domain/entities/catalog_item_entity.dart';

class FavoritesItemsState {
  final List<CatalogItemEntity> items;
  final bool isLoading;

  const FavoritesItemsState({
    this.items = const [],
    this.isLoading = false,
  });

  FavoritesItemsState copyWith({
    List<CatalogItemEntity>? items,
    bool? isLoading,
  }) {
    return FavoritesItemsState(
      items: items ?? this.items,
      isLoading: isLoading ?? this.isLoading,
    );
  }
}
