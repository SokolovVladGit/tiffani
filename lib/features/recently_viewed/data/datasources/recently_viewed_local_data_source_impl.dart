import 'dart:convert';

import 'package:shared_preferences/shared_preferences.dart';

import '../../../../core/constants/storage_keys.dart';
import '../dto/recently_viewed_item_dto.dart';
import 'recently_viewed_local_data_source.dart';

class RecentlyViewedLocalDataSourceImpl
    implements RecentlyViewedLocalDataSource {
  final SharedPreferences _prefs;

  const RecentlyViewedLocalDataSourceImpl(this._prefs);

  @override
  Future<List<RecentlyViewedItemDto>> getItems() async {
    final raw = _prefs.getString(StorageKeys.recentlyViewedItems);
    if (raw == null || raw.isEmpty) return [];
    try {
      final list = jsonDecode(raw) as List<dynamic>;
      return list
          .map((e) => RecentlyViewedItemDto.fromMap(e as Map<String, dynamic>))
          .toList();
    } catch (_) {
      await clear();
      return [];
    }
  }

  @override
  Future<void> saveItems(List<RecentlyViewedItemDto> items) async {
    final encoded = jsonEncode(items.map((e) => e.toMap()).toList());
    await _prefs.setString(StorageKeys.recentlyViewedItems, encoded);
  }

  @override
  Future<void> clear() async {
    await _prefs.remove(StorageKeys.recentlyViewedItems);
  }
}
