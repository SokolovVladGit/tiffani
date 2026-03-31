import '../entities/recently_viewed_item.dart';

abstract interface class RecentlyViewedRepository {
  Future<List<RecentlyViewedItem>> getRecentlyViewed();
  Future<void> addItem(RecentlyViewedItem item);
  Future<void> clear();
}
