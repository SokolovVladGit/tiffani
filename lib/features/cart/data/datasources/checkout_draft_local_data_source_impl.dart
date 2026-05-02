import 'dart:convert';

import 'package:shared_preferences/shared_preferences.dart';

import '../../../../core/constants/storage_keys.dart';
import '../../domain/entities/checkout_draft_entity.dart';
import 'checkout_draft_local_data_source.dart';

/// `SharedPreferences`-backed storage for [CheckoutDraftEntity]. Payload
/// is a single JSON object under [StorageKeys.checkoutDraftV1].
///
/// The "v1" suffix on the key is intentional: future shape changes should
/// bump to `_v2` so older corrupted payloads can be recovered/ignored
/// without accidentally reading incompatible data.
class CheckoutDraftLocalDataSourceImpl implements CheckoutDraftLocalDataSource {
  final SharedPreferences _prefs;

  const CheckoutDraftLocalDataSourceImpl(this._prefs);

  @override
  Future<CheckoutDraftEntity?> load() async {
    final raw = _prefs.getString(StorageKeys.checkoutDraftV1);
    if (raw == null || raw.isEmpty) return null;
    try {
      final decoded = jsonDecode(raw);
      if (decoded is! Map<String, dynamic>) {
        // Corrupted/incompatible payload — drop it so the next save is
        // clean.
        await clear();
        return null;
      }
      final entity = CheckoutDraftEntity.fromJson(decoded);
      return entity.isEmpty ? null : entity;
    } catch (_) {
      // Any decode failure (malformed JSON, type error) is non-fatal.
      // We clear the bad payload and act as if nothing was stored.
      await clear();
      return null;
    }
  }

  @override
  Future<void> save(CheckoutDraftEntity draft) async {
    final normalized = draft.normalized().copyWith(
          updatedAt: DateTime.now().toUtc(),
        );
    if (normalized.isEmpty) {
      await clear();
      return;
    }
    final encoded = jsonEncode(normalized.toJson());
    await _prefs.setString(StorageKeys.checkoutDraftV1, encoded);
  }

  @override
  Future<void> clear() async {
    await _prefs.remove(StorageKeys.checkoutDraftV1);
  }
}
