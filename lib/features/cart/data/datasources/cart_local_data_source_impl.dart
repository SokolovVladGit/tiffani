import 'dart:convert';

import 'package:shared_preferences/shared_preferences.dart';

import '../../../../core/constants/storage_keys.dart';
import '../dto/cart_item_dto.dart';
import 'cart_local_data_source.dart';

class CartLocalDataSourceImpl implements CartLocalDataSource {
  final SharedPreferences _prefs;

  const CartLocalDataSourceImpl(this._prefs);

  @override
  Future<List<CartItemDto>> getCartItems() async {
    final raw = _prefs.getString(StorageKeys.cartItems);
    if (raw == null || raw.isEmpty) return [];
    final list = jsonDecode(raw) as List<dynamic>;
    return list
        .map((e) => CartItemDto.fromMap(e as Map<String, dynamic>))
        .toList();
  }

  @override
  Future<void> saveCartItems(List<CartItemDto> items) async {
    final encoded = jsonEncode(items.map((e) => e.toMap()).toList());
    await _prefs.setString(StorageKeys.cartItems, encoded);
  }

  @override
  Future<void> clearCart() async {
    await _prefs.remove(StorageKeys.cartItems);
  }
}
