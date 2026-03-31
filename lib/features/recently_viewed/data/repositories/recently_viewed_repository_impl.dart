import '../../domain/entities/recently_viewed_item.dart';
import '../../domain/repositories/recently_viewed_repository.dart';
import '../datasources/recently_viewed_local_data_source.dart';
import '../dto/recently_viewed_item_dto.dart';

class RecentlyViewedRepositoryImpl implements RecentlyViewedRepository {
  final RecentlyViewedLocalDataSource _dataSource;

  static const _maxItems = 20;

  const RecentlyViewedRepositoryImpl(this._dataSource);

  @override
  Future<List<RecentlyViewedItem>> getRecentlyViewed() async {
    final dtos = await _dataSource.getItems();
    return dtos.map((d) => d.toEntity()).toList();
  }

  @override
  Future<void> addItem(RecentlyViewedItem item) async {
    final dtos = await _dataSource.getItems();
    dtos.removeWhere((d) => d.id == item.id);
    dtos.insert(0, RecentlyViewedItemDto.fromEntity(item));
    if (dtos.length > _maxItems) {
      dtos.removeRange(_maxItems, dtos.length);
    }
    await _dataSource.saveItems(dtos);
  }

  @override
  Future<void> clear() => _dataSource.clear();
}
