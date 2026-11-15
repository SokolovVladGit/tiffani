import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:tiffani/features/cart/config/discount_pricing_config.dart';
import 'package:tiffani/features/cart/domain/checkout_attempt.dart';
import 'package:tiffani/features/cart/domain/pending_checkout_attempt.dart';

void main() {
  test('timeout keeps the key and the retry returns the same order', () async {
    final store = _MemoryStore();
    var calls = 0;
    String? seenId;
    final coordinator = CheckoutAttemptCoordinator(
      store: store,
      newRequestId: () => '11111111-1111-4111-8111-111111111111',
      submit: ({required customer, required items, required requestId}) async {
        calls++;
        seenId = requestId;
        if (calls == 1) throw Exception('timeout');
        return {
          'ok': true,
          'order_id': 'b1f40755-1111-4111-8111-111111111111',
          'total_items': 1,
          'total_quantity': 1,
          'total_price': 335,
        };
      },
    );
    final customer = {'name': 'Анна', 'phone': '+37312345678'};
    final items = [
      {'variant_id': 'sku-1', 'quantity': 1},
    ];

    await expectLater(
      coordinator.submitPayload(customer: customer, items: items),
      throwsException,
    );
    final pending = await store.load(null);
    final replay = await coordinator.submitPayload(
      customer: customer,
      items: items,
    );

    expect(calls, 2);
    expect(seenId, '11111111-1111-4111-8111-111111111111');
    expect(pending?.requestId, seenId);
    expect(replay['order_id'], 'b1f40755-1111-4111-8111-111111111111');
    expect(await store.load(null), isNull);
  });

  test('restart reuses the stored payload instead of a changed form', () async {
    final store = _MemoryStore();
    var calls = 0;
    final sent = <Map<String, dynamic>>[];
    final coordinator = CheckoutAttemptCoordinator(
      store: store,
      newRequestId: () => '22222222-2222-4222-8222-222222222222',
      submit: ({required customer, required items, required requestId}) async {
        calls++;
        sent.add(Map<String, dynamic>.from(customer));
        if (calls == 1) throw Exception('socket');
        return {
          'ok': true,
          'order_id': 'b1f40755-1111-4111-8111-111111111111',
          'total_items': 1,
          'total_quantity': 1,
          'total_price': 335,
        };
      },
    );
    await expectLater(
      coordinator.submitPayload(
        customer: {'name': 'Анна', 'phone': '12345678'},
        items: [
          {'variant_id': 'sku-1', 'quantity': 1},
        ],
      ),
      throwsException,
    );

    await expectLater(
      coordinator.submitPayload(
        customer: {'name': 'Мария', 'phone': '12345678'},
        items: [
          {'variant_id': 'sku-1', 'quantity': 1},
        ],
      ),
      throwsA(isA<PendingCheckoutConflictException>()),
    );
    expect(calls, 1);
    final replay = await coordinator.retryStored();
    expect(sent.last['name'], 'Анна');
    expect(replay['order_id'], 'b1f40755-1111-4111-8111-111111111111');
  });

  test(
    'a changed form is not sent until the pending attempt is discarded',
    () async {
      final store = _MemoryStore();
      var calls = 0;
      final ids = <String>[];
      final coordinator = CheckoutAttemptCoordinator(
        store: store,
        newRequestId: () => calls == 0
            ? '33333333-3333-4333-8333-333333333333'
            : '44444444-4444-4444-8444-444444444444',
        submit:
            ({required customer, required items, required requestId}) async {
              calls++;
              ids.add(requestId);
              if (calls == 1) throw Exception('timeout');
              return {
                'ok': true,
                'order_id': 'aaaaaaaa-1111-4111-8111-111111111111',
                'total_items': 1,
                'total_quantity': 1,
                'total_price': 10,
              };
            },
      );
      const items = [
        {'variant_id': 'sku-1', 'quantity': 1},
      ];
      await expectLater(
        coordinator.submitPayload(
          customer: {'phone': '12345678'},
          items: items,
        ),
        throwsException,
      );
      await coordinator.discard();
      await coordinator.submitPayload(
        customer: {'phone': '87654321'},
        items: items,
      );
      expect(ids, [
        '33333333-3333-4333-8333-333333333333',
        '44444444-4444-4444-8444-444444444444',
      ]);
    },
  );

  test('a payload conflict keeps the pending attempt', () async {
    final store = _MemoryStore();
    final coordinator = CheckoutAttemptCoordinator(
      store: store,
      newRequestId: () => '66666666-6666-4666-8666-666666666666',
      submit: ({required customer, required items, required requestId}) async {
        return {
          'ok': false,
          'errors': [
            {'code': 'request_payload_conflict', 'message': 'conflict'},
          ],
        };
      },
    );
    await coordinator.submitPayload(
      customer: {'phone': '12345678'},
      items: [
        {'variant_id': 'sku-1', 'quantity': 1},
      ],
    );
    expect(
      (await store.load(null))?.requestId,
      '66666666-6666-4666-8666-666666666666',
    );
  });

  test('a definitive rejection clears the pending attempt', () async {
    final store = _MemoryStore();
    final coordinator = CheckoutAttemptCoordinator(
      store: store,
      newRequestId: () => '55555555-5555-4555-8555-555555555555',
      submit: ({required customer, required items, required requestId}) async {
        return {
          'ok': false,
          'errors': [
            {'code': 'invalid_phone', 'message': 'Некорректный номер телефона'},
          ],
        };
      },
    );
    final raw = await coordinator.submitPayload(
      customer: {'phone': '1234567'},
      items: [
        {'variant_id': 'sku-1', 'quantity': 1},
      ],
    );
    expect(raw['ok'], isFalse);
    expect(await store.load(null), isNull);
  });

  test('a changed payload cannot replace an ambiguous attempt', () async {
    final store = _MemoryStore();
    var calls = 0;
    final coordinator = CheckoutAttemptCoordinator(
      store: store,
      newRequestId: () => '77777777-7777-4777-8777-777777777777',
      submit: ({required customer, required items, required requestId}) async {
        calls++;
        throw Exception('timeout');
      },
    );
    const items = [
      {'variant_id': 'sku-1', 'quantity': 1},
    ];
    await expectLater(
      coordinator.submitPayload(customer: {'phone': '12345678'}, items: items),
      throwsException,
    );
    await expectLater(
      coordinator.submitPayload(customer: {'phone': '87654321'}, items: items),
      throwsA(isA<PendingCheckoutConflictException>()),
    );
    expect(calls, 1);
    expect(
      (await store.load(null))?.requestId,
      '77777777-7777-4777-8777-777777777777',
    );
  });

  test('a stored rejection with an order id keeps the attempt', () async {
    final store = _MemoryStore();
    final coordinator = CheckoutAttemptCoordinator(
      store: store,
      newRequestId: () => '88888888-8888-4888-8888-888888888888',
      submit: ({required customer, required items, required requestId}) async {
        return {
          'ok': false,
          'order_id': 'b1f40755-1111-4111-8111-111111111111',
          'errors': [
            {'code': 'unknown_error', 'message': 'x'},
          ],
        };
      },
    );
    await coordinator.submitPayload(
      customer: {'phone': '12345678'},
      items: [
        {'variant_id': 'sku-1', 'quantity': 1},
      ],
    );
    expect(await store.load(null), isNotNull);
  });

  test(
    'another account does not read or overwrite the pending attempt',
    () async {
      final store = _MemoryStore();
      var owner = 'user-a';
      var calls = 0;
      final seen = <String>[];
      final coordinator = CheckoutAttemptCoordinator(
        store: store,
        currentOwnerId: () => owner,
        newRequestId: () => calls == 0
            ? '99999999-9999-4999-8999-999999999999'
            : 'aaaaaaaa-aaaa-4aaa-8aaa-aaaaaaaaaa10',
        submit:
            ({required customer, required items, required requestId}) async {
              calls++;
              seen.add('${customer['name']}:$requestId');
              throw Exception('timeout');
            },
      );
      const items = [
        {'variant_id': 'sku-1', 'quantity': 1},
      ];
      await expectLater(
        coordinator.submitPayload(
          customer: {'name': 'Анна', 'phone': '12345678'},
          items: items,
        ),
        throwsException,
      );
      owner = 'user-b';
      expect(await coordinator.loadPending(), isNull);
      await expectLater(
        coordinator.submitPayload(
          customer: {'name': 'Мария', 'phone': '87654321'},
          items: items,
        ),
        throwsException,
      );
      owner = 'user-a';
      final pending = await coordinator.loadPending();
      expect(pending?.customer['name'], 'Анна');
      expect(pending?.requestId, '99999999-9999-4999-8999-999999999999');
      expect(seen, [
        'Анна:99999999-9999-4999-8999-999999999999',
        'Мария:aaaaaaaa-aaaa-4aaa-8aaa-aaaaaaaaaa10',
      ]);
    },
  );

  test('release checkout is the idempotent discount path', () {
    expect(DiscountPricingConfig.useDiscountPricingV1, isTrue);
    expect(DiscountPricingConfig.submitOrderRpcName, 'submit_order_v4');
    final page = File(
      'lib/features/cart/presentation/pages/checkout_page.dart',
    ).readAsStringSync();
    expect(page.contains('discardPendingOrder'), isFalse);
    expect(page.contains('Изменить заказ'), isFalse);
  });
}

class _MemoryStore implements PendingCheckoutStore {
  final slots = <String, PendingCheckoutAttempt>{};

  String _key(String? ownerId) {
    final value = ownerId?.trim() ?? '';
    return value.isEmpty ? 'guest' : value;
  }

  @override
  Future<void> clear(String? ownerId) async {
    slots.remove(_key(ownerId));
  }

  @override
  Future<PendingCheckoutAttempt?> load(String? ownerId) async =>
      slots[_key(ownerId)];

  @override
  Future<void> save(PendingCheckoutAttempt attempt) async {
    slots[_key(attempt.ownerId)] = attempt;
  }
}
