import 'catalog_item_dto.dart';

class CatalogPageResultDto {
  final List<CatalogItemDto> items;
  final int totalCount;

  const CatalogPageResultDto({
    required this.items,
    required this.totalCount,
  });
}
