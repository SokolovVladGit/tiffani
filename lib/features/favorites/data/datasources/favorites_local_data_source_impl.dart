import 'package:shared_preferences/shared_preferences.dart';

import '../../../../core/constants/storage_keys.dart';
import 'favorites_local_data_source.dart';

class FavoritesLocalDataSourceImpl implements FavoritesLocalDataSource {
  final SharedPreferences _prefs;

  const FavoritesLocalDataSourceImpl(this._prefs);

  @override
  Future<Set<String>> getFavorites() async {
    final list = _prefs.getStringList(StorageKeys.favoriteItemIds);
    if (list == null) return {};
    return list.toSet();
  }

  @override
  Future<void> saveFavorites(Set<String> ids) async {
    await _prefs.setStringList(StorageKeys.favoriteItemIds, ids.toList());
  }
}
