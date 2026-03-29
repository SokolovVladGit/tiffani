import '../../../catalog/domain/entities/catalog_item_entity.dart';

enum HomeStatus { initial, loading, success, failure }

class HomeState {
  final HomeStatus status;
  final List<CatalogItemEntity> newItems;
  final List<CatalogItemEntity> saleItems;
  final List<CatalogItemEntity> hitItems;
  final String? errorMessage;

  const HomeState({
    this.status = HomeStatus.initial,
    this.newItems = const [],
    this.saleItems = const [],
    this.hitItems = const [],
    this.errorMessage,
  });

  bool get hasSections =>
      newItems.isNotEmpty || saleItems.isNotEmpty || hitItems.isNotEmpty;

  HomeState copyWith({
    HomeStatus? status,
    List<CatalogItemEntity>? newItems,
    List<CatalogItemEntity>? saleItems,
    List<CatalogItemEntity>? hitItems,
    String? errorMessage,
  }) {
    return HomeState(
      status: status ?? this.status,
      newItems: newItems ?? this.newItems,
      saleItems: saleItems ?? this.saleItems,
      hitItems: hitItems ?? this.hitItems,
      errorMessage: errorMessage ?? this.errorMessage,
    );
  }
}
