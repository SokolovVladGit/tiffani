import 'dart:convert';

import 'package:shared_preferences/shared_preferences.dart';

import '../../../../core/constants/storage_keys.dart';
import '../../domain/pending_checkout_attempt.dart';

class PendingCheckoutStoreImpl implements PendingCheckoutStore {
  final SharedPreferences _prefs;

  const PendingCheckoutStoreImpl(this._prefs);

  @override
  Future<PendingCheckoutAttempt?> load(String? ownerId) async {
    final slots = await _readSlots();
    return slots[_ownerKey(ownerId)];
  }

  @override
  Future<void> save(PendingCheckoutAttempt attempt) async {
    final slots = await _readSlots();
    slots[_ownerKey(attempt.ownerId)] = attempt;
    await _writeSlots(slots);
  }

  @override
  Future<void> clear(String? ownerId) async {
    final slots = await _readSlots();
    slots.remove(_ownerKey(ownerId));
    await _writeSlots(slots);
  }

  String _ownerKey(String? ownerId) {
    final value = ownerId?.trim() ?? '';
    return value.isEmpty ? 'guest' : value;
  }

  Future<Map<String, PendingCheckoutAttempt>> _readSlots() async {
    final raw = _prefs.getString(StorageKeys.pendingCheckoutV1);
    if (raw == null || raw.isEmpty) return {};
    try {
      final decoded = jsonDecode(raw);
      if (decoded is! Map) {
        await _prefs.remove(StorageKeys.pendingCheckoutV1);
        return {};
      }
      final owners = decoded['owners'];
      if (owners is Map) {
        final slots = <String, PendingCheckoutAttempt>{};
        for (final entry in owners.entries) {
          final attempt = _attemptFrom(entry.value);
          if (attempt == null) continue;
          slots[entry.key.toString()] = attempt;
        }
        return slots;
      }
      final legacy = _attemptFrom(decoded);
      if (legacy == null) return {};
      return {'guest': legacy};
    } catch (_) {
      await _prefs.remove(StorageKeys.pendingCheckoutV1);
      return {};
    }
  }

  Future<void> _writeSlots(Map<String, PendingCheckoutAttempt> slots) async {
    if (slots.isEmpty) {
      await _prefs.remove(StorageKeys.pendingCheckoutV1);
      return;
    }
    final encoded = jsonEncode({
      'owners': {
        for (final entry in slots.entries)
          entry.key: {
            'request_id': entry.value.requestId,
            'digest': entry.value.digest,
            'customer': entry.value.customer,
            'items': entry.value.items,
            'owner_id': entry.value.ownerId,
          },
      },
    });
    await _prefs.setString(StorageKeys.pendingCheckoutV1, encoded);
  }

  PendingCheckoutAttempt? _attemptFrom(Object? raw) {
    if (raw is! Map) return null;
    final requestId = raw['request_id'];
    final digest = raw['digest'];
    final customer = raw['customer'];
    final items = raw['items'];
    if (requestId is! String ||
        requestId.isEmpty ||
        digest is! String ||
        customer is! Map ||
        items is! List) {
      return null;
    }
    final owner = raw['owner_id'];
    return PendingCheckoutAttempt(
      requestId: requestId,
      digest: digest,
      customer: _stringKeyMap(customer),
      items: items.whereType<Map>().map(_stringKeyMap).toList(growable: false),
      ownerId: owner is String && owner.trim().isNotEmpty ? owner.trim() : null,
    );
  }

  Map<String, dynamic> _stringKeyMap(Map value) {
    return value.map((key, item) => MapEntry(key.toString(), item));
  }
}
