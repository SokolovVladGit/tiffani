import 'dart:convert';
import 'dart:math';

import 'pending_checkout_attempt.dart';

class PendingCheckoutConflictException implements Exception {
  const PendingCheckoutConflictException();
}

/// One logical checkout submission. The request id is created once and reused
/// until the server returns a definitive response.
class CheckoutAttemptCoordinator {
  final PendingCheckoutStore store;
  final Future<Map<String, dynamic>> Function({
    required Map<String, dynamic> customer,
    required List<Map<String, dynamic>> items,
    required String requestId,
  })
  submit;
  final String Function() newRequestId;
  final String? Function() currentOwnerId;

  const CheckoutAttemptCoordinator({
    required this.store,
    required this.submit,
    required this.newRequestId,
    this.currentOwnerId = _guestOwner,
  });

  static String? _guestOwner() => null;

  Future<PendingCheckoutAttempt?> loadPending() => store.load(currentOwnerId());

  /// Drops only the current account's attempt, and only after the server has
  /// conclusively reported that this request created no order.
  Future<void> discard() => store.clear(currentOwnerId());

  Future<Map<String, dynamic>> submitPayload({
    required Map<String, dynamic> customer,
    required List<Map<String, dynamic>> items,
  }) async {
    final digest = checkoutAttemptDigest(customer, items);
    final pending = await store.load(currentOwnerId());
    if (pending != null && pending.digest != digest) {
      throw const PendingCheckoutConflictException();
    }
    if (pending != null) {
      return _send(
        customer: pending.customer,
        items: pending.items,
        requestId: pending.requestId,
      );
    }
    final requestId = newRequestId();
    await store.save(
      PendingCheckoutAttempt(
        requestId: requestId,
        digest: digest,
        customer: customer,
        items: items,
        ownerId: currentOwnerId(),
      ),
    );
    return _send(customer: customer, items: items, requestId: requestId);
  }

  /// Resends the stored payload. Used when the customer explicitly retries an
  /// attempt whose form no longer matches.
  Future<Map<String, dynamic>> retryStored() async {
    final pending = await store.load(currentOwnerId());
    if (pending == null) {
      throw const PendingCheckoutConflictException();
    }
    return _send(
      customer: pending.customer,
      items: pending.items,
      requestId: pending.requestId,
    );
  }

  Future<Map<String, dynamic>> _send({
    required Map<String, dynamic> customer,
    required List<Map<String, dynamic>> items,
    required String requestId,
  }) async {
    final raw = await submit(
      customer: customer,
      items: items,
      requestId: requestId,
    );
    final ok = raw['ok'];
    if (ok is bool && ok) {
      await store.clear(currentOwnerId());
      return raw;
    }
    if (ok is bool && !ok && _isDefinitiveRejection(raw)) {
      await store.clear(currentOwnerId());
    }
    return raw;
  }

  bool _isDefinitiveRejection(Map<String, dynamic> raw) {
    final orderId = raw['order_id'];
    if (orderId is String && orderId.trim().isNotEmpty) return false;
    final errors = raw['errors'];
    if (errors is! List || errors.isEmpty) return true;
    final first = errors.first;
    if (first is! Map) return true;
    final code = first['code'];
    return code != 'request_payload_conflict' && code != 'request_forbidden';
  }
}

String newCheckoutRequestId() {
  final random = Random.secure();
  final bytes = List<int>.generate(16, (_) => random.nextInt(256));
  bytes[6] = (bytes[6] & 0x0f) | 0x40;
  bytes[8] = (bytes[8] & 0x3f) | 0x80;
  final hex = bytes.map((b) => b.toRadixString(16).padLeft(2, '0')).join();
  return '${hex.substring(0, 8)}-${hex.substring(8, 12)}-'
      '${hex.substring(12, 16)}-${hex.substring(16, 20)}-${hex.substring(20)}';
}

String checkoutAttemptDigest(
  Map<String, dynamic> customer,
  List<Map<String, dynamic>> items,
) {
  return jsonEncode({
    'customer': _canonicalize(customer),
    'items': items.map(_canonicalize).toList(),
  });
}

Object? _canonicalize(Object? value) {
  if (value is Map) {
    final keys = value.keys.map((key) => key.toString()).toList()..sort();
    return {for (final key in keys) key: _canonicalize(value[key])};
  }
  if (value is List) {
    return value.map(_canonicalize).toList();
  }
  return value;
}
