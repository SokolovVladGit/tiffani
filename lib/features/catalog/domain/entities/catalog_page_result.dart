import 'catalog_item_entity.dart';

class CatalogPageResult {
  final List<CatalogItemEntity> items;
  final int totalCount;

  const CatalogPageResult({
    required this.items,
    required this.totalCount,
  });
}
