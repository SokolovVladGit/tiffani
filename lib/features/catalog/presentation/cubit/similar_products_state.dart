import '../../domain/entities/catalog_item_entity.dart';

enum SimilarProductsStatus { initial, loading, success, failure }

class SimilarProductsState {
  final SimilarProductsStatus status;
  final List<CatalogItemEntity> items;

  const SimilarProductsState({
    this.status = SimilarProductsStatus.initial,
    this.items = const [],
  });

  bool get hasItems => items.isNotEmpty;

  SimilarProductsState copyWith({
    SimilarProductsStatus? status,
    List<CatalogItemEntity>? items,
  }) {
    return SimilarProductsState(
      status: status ?? this.status,
      items: items ?? this.items,
    );
  }
}
