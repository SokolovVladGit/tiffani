import '../dto/recently_viewed_item_dto.dart';

abstract interface class RecentlyViewedLocalDataSource {
  Future<List<RecentlyViewedItemDto>> getItems();
  Future<void> saveItems(List<RecentlyViewedItemDto> items);
  Future<void> clear();
}
