import '../../features/catalog/domain/entities/catalog_item_entity.dart';

/// Lightweight navigation payload for the product details route.
///
/// Carries the product entity and an optional [heroTag] so the PDP
/// can match the Hero widget from the source card that initiated navigation.
class ProductDetailsPayload {
  final CatalogItemEntity item;
  final String? heroTag;

  const ProductDetailsPayload({required this.item, this.heroTag});
}
