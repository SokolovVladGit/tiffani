import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:tiffani/features/account/domain/checkout_phone_sync.dart';
import 'package:tiffani/features/account/domain/entities/order_summary_entity.dart';
import 'package:tiffani/features/account/domain/entities/profile_entity.dart';
import 'package:tiffani/features/account/domain/repositories/account_repository.dart';
import 'package:tiffani/features/account/domain/sign_up_outcome.dart';
import 'package:tiffani/features/account/presentation/cubit/auth_cubit.dart';
import 'package:tiffani/features/account/presentation/cubit/auth_state.dart';
import 'package:tiffani/features/cart/presentation/checkout_contact.dart';

User _user() {
  return User(
    id: 'user-1',
    appMetadata: const {},
    userMetadata: const {},
    aud: 'authenticated',
    email: 'a@b.co',
    createdAt: '2026-01-01T00:00:00Z',
  );
}

class _Repo implements AccountRepository {
  User? user;
  ProfileEntity? profile;
  int phoneWrites = 0;
  Object? phoneSyncError;
  final orders = [
    OrderSummaryEntity(
      id: 'order-1',
      createdAt: DateTime.utc(2026, 11, 15),
      totalItems: 1,
      totalQuantity: 1,
      totalPrice: 10,
      status: 'new',
    ),
  ];
  final _auth = StreamController<AuthState>.broadcast();

  @override
  Stream<AuthState> get authStateChanges => _auth.stream;

  @override
  User? get currentUser => user;

  @override
  bool get isAuthenticated => user != null;

  @override
  Future<SignUpOutcome> signUp({
    required String email,
    required String password,
  }) async => SignUpOutcome.session;

  @override
  Future<void> signIn({required String email, required String password}) async {
    user ??= _user();
  }

  @override
  Future<void> signOut() async {}

  @override
  Future<ProfileEntity?> getProfile() async => profile;

  @override
  Future<void> upsertProfile(ProfileEntity profile) async {}

  @override
  Future<ProfileEntity?> saveCheckoutPhone(String phone) async {
    if (user == null) return null;
    if (phoneSyncError != null) throw phoneSyncError!;
    final next = profileAfterCheckoutPhone(
      userId: user!.id,
      existing: profile,
      submittedPhone: phone,
    );
    if (next == null) return profile;
    phoneWrites++;
    profile = next;
    return next;
  }

  @override
  Future<List<OrderSummaryEntity>> getOrderHistory() async => orders;

  Future<void> close() => _auth.close();
}

void main() {
  test('checkout phone is required and a typed value is kept', () {
    expect(validateCheckoutPhone(null), 'Укажите телефон');
    expect(validateCheckoutPhone('  '), 'Укажите телефон');
    expect(validateCheckoutPhone('123'), 'Некорректный номер телефона');
    expect(validateCheckoutPhone('+373 00 000 000'), isNull);
    expect(validateCheckoutPhone('+37312345678'), isNull);
    expect(validateCheckoutPhone('12345678'), isNull);
    expect(validateCheckoutPhone('+12025550123'), isNull);
    expect(validateCheckoutPhone('+373 (12) 345-678'), isNull);
    expect(validateCheckoutPhone('123456789012345'), isNull);
    expect(validateCheckoutPhone(''), checkoutPhoneRequiredMessage);
    expect(validateCheckoutPhone('abc12345678'), checkoutPhoneInvalidMessage);
    expect(validateCheckoutPhone('++37312345678'), checkoutPhoneInvalidMessage);
    expect(validateCheckoutPhone('373+12345678'), checkoutPhoneInvalidMessage);
    expect(validateCheckoutPhone('++--()'), checkoutPhoneInvalidMessage);
    expect(validateCheckoutPhone('1234567'), checkoutPhoneInvalidMessage);
    expect(
      validateCheckoutPhone('1234567890123456'),
      checkoutPhoneInvalidMessage,
    );
    expect(
      validateCheckoutPhone('1234567890123456789'),
      checkoutPhoneInvalidMessage,
    );

    expect(fillCheckoutField('', '+373 00'), '+373 00');
    expect(fillCheckoutField('edited', '+373 00'), 'edited');
    expect(fillCheckoutField('', null), '');
    expect(fillCheckoutField('', '   '), '');
  });

  test('a failed order does not ask to save the phone', () async {
    var calls = 0;
    await persistPhoneAfterOrder(
      orderSucceeded: false,
      phone: '+373 00',
      persist: (_) async {
        calls++;
      },
    );
    expect(calls, 0);
  });

  test('successful checkout phone keeps name, card, and order snapshot', () {
    const existing = ProfileEntity(
      id: 'user-1',
      name: 'Анна',
      phone: '+373 11',
      loyaltyCard: '42',
    );
    final order = OrderSummaryEntity(
      id: '9f1c2a10-1111-2222-3333-444455556666',
      createdAt: DateTime.utc(2026, 11, 15),
      totalItems: 1,
      totalQuantity: 2,
      totalPrice: 90,
      status: 'new',
    );

    expect(
      profileAfterCheckoutPhone(
        userId: 'user-1',
        existing: existing,
        submittedPhone: ' +373 11 ',
      ),
      isNull,
    );

    final next = profileAfterCheckoutPhone(
      userId: 'user-1',
      existing: existing,
      submittedPhone: '+373 22',
    )!;
    expect(next.name, 'Анна');
    expect(next.loyaltyCard, '42');
    expect(next.phone, '+373 22');

    final payload = checkoutPhoneUpdatePayload(
      phone: next.phone!,
      updatedAt: '2026-11-15T00:00:00.000Z',
    );
    expect(payload.keys.toList(), ['phone', 'updated_at']);
    expect(payload.containsKey('name'), isFalse);
    expect(payload.containsKey('loyalty_card'), isFalse);
    expect(order.id, '9f1c2a10-1111-2222-3333-444455556666');
    expect(order.status, 'new');
    expect(fillCheckoutField('', next.phone), '+373 22');
  });

  test('phone sync write does not include name or loyalty_card', () {
    final insert = checkoutPhoneInsertPayload(
      userId: 'user-1',
      phone: '+373 22',
      updatedAt: '2026-11-15T00:00:00.000Z',
    );
    final update = checkoutPhoneUpdatePayload(
      phone: '+373 22',
      updatedAt: '2026-11-15T00:00:00.000Z',
    );

    expect(insert.keys.toSet(), {'id', 'phone', 'updated_at'});
    expect(update.keys.toSet(), {'phone', 'updated_at'});
    for (final payload in [insert, update]) {
      expect(payload.containsKey('name'), isFalse);
      expect(payload.containsKey('loyalty_card'), isFalse);
    }
  });

  test(
    'guest and sync failure do not change auth or the order result',
    () async {
      final repo = _Repo();
      final cubit = AuthCubit(repo);
      addTearDown(() async {
        await cubit.close();
        await repo.close();
      });

      await cubit.syncSubmittedPhone('+373 00');
      expect(repo.phoneWrites, 0);
      expect(cubit.state.status, AuthStatus.unauthenticated);

      repo.user = _user();
      repo.profile = const ProfileEntity(
        id: 'user-1',
        name: 'Анна',
        loyaltyCard: '42',
      );
      repo.phoneSyncError = Exception('rls');
      await cubit.signIn(email: 'a@b.co', password: 'secret1');

      await cubit.syncSubmittedPhone('+373 22');

      expect(repo.phoneWrites, 0);
      expect(cubit.state.status, AuthStatus.authenticated);
      expect(cubit.state.errorMessage, isNull);
      expect(cubit.state.isLoading, isFalse);
      expect(cubit.state.profile?.phone, isNull);
      expect(cubit.state.profile?.name, 'Анна');
      expect(repo.orders.single.status, 'new');
    },
  );

  test(
    'authenticated sync stores the new phone and can prefill the next order',
    () async {
      final repo = _Repo();
      repo.user = _user();
      repo.profile = const ProfileEntity(
        id: 'user-1',
        name: 'Анна',
        loyaltyCard: '42',
      );
      final cubit = AuthCubit(repo);
      addTearDown(() async {
        await cubit.close();
        await repo.close();
      });
      await cubit.signIn(email: 'a@b.co', password: 'secret1');

      await cubit.syncSubmittedPhone('+373 22');
      await cubit.syncSubmittedPhone('+373 22');

      expect(repo.phoneWrites, 1);
      expect(cubit.state.profile?.phone, '+373 22');
      expect(cubit.state.profile?.name, 'Анна');
      expect(cubit.state.profile?.loyaltyCard, '42');
      expect(repo.orders.single.id, 'order-1');
      expect(fillCheckoutField('', cubit.state.profile?.phone), '+373 22');
    },
  );

  test('failed profile sync still shows the confirmed order', () async {
    var shown = false;
    await completeCheckoutSideEffects(
      orderSucceeded: true,
      persistPhone: () async {
        throw Exception('profile down');
      },
      showSuccess: () => shown = true,
    );
    expect(shown, isTrue);
  });
}
