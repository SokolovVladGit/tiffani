import 'package:shared_preferences/shared_preferences.dart';

import 'favorites_local_data_source.dart';

class FavoritesLocalDataSourceImpl implements FavoritesLocalDataSource {
  final SharedPreferences _prefs;

  static const _key = 'favorite_item_ids';

  const FavoritesLocalDataSourceImpl(this._prefs);

  @override
  Future<Set<String>> getFavorites() async {
    final list = _prefs.getStringList(_key);
    if (list == null) return {};
    return list.toSet();
  }

  @override
  Future<void> saveFavorites(Set<String> ids) async {
    await _prefs.setStringList(_key, ids.toList());
  }
}
