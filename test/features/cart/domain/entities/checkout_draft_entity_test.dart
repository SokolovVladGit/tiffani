import 'package:flutter_test/flutter_test.dart';
import 'package:tiffani/features/cart/domain/entities/checkout_draft_entity.dart';

void main() {
  group('CheckoutDraftEntity.normalized', () {
    test('trims strings and collapses empty/whitespace to null', () {
      const draft = CheckoutDraftEntity(
        name: '  Анна  ',
        phone: '',
        email: '   ',
        loyaltyCard: ' 42  ',
      );

      final normalized = draft.normalized();

      expect(normalized.name, 'Анна');
      expect(normalized.phone, isNull);
      expect(normalized.email, isNull);
      expect(normalized.loyaltyCard, '42');
    });

    test('preserves updatedAt', () {
      final stamp = DateTime.utc(2026, 5, 2, 10, 0);
      final draft = CheckoutDraftEntity(name: 'A', updatedAt: stamp);

      expect(draft.normalized().updatedAt, stamp);
    });
  });

  group('CheckoutDraftEntity.isEmpty', () {
    test('true for a fresh empty entity', () {
      expect(CheckoutDraftEntity.empty.isEmpty, isTrue);
    });

    test('true when every field is null/whitespace', () {
      const draft = CheckoutDraftEntity(
        name: '   ',
        phone: '',
        email: null,
        loyaltyCard: '  ',
      );

      expect(draft.isEmpty, isTrue);
    });

    test('false when at least one field has content', () {
      const draft = CheckoutDraftEntity(phone: '+373 000');

      expect(draft.isEmpty, isFalse);
    });
  });

  group('CheckoutDraftEntity.toJson / fromJson', () {
    test('round-trip preserves values (after normalization)', () {
      final original = const CheckoutDraftEntity(
        name: 'Анна',
        phone: '+37360000000',
        email: 'anna@example.com',
        loyaltyCard: '42',
      ).normalized();

      final decoded = CheckoutDraftEntity.fromJson(original.toJson());

      expect(decoded.name, original.name);
      expect(decoded.phone, original.phone);
      expect(decoded.email, original.email);
      expect(decoded.loyaltyCard, original.loyaltyCard);
    });

    test('round-trip preserves updatedAt via ISO8601', () {
      final stamp = DateTime.utc(2026, 5, 2, 10, 30, 45);
      final original = CheckoutDraftEntity(name: 'A', updatedAt: stamp);

      final decoded = CheckoutDraftEntity.fromJson(original.toJson());

      expect(decoded.updatedAt, stamp);
    });

    test('fromJson tolerates missing keys', () {
      final decoded = CheckoutDraftEntity.fromJson({});

      expect(decoded.isEmpty, isTrue);
      expect(decoded.updatedAt, isNull);
    });

    test('fromJson ignores unknown keys', () {
      final decoded = CheckoutDraftEntity.fromJson({
        'name': 'Анна',
        'foo': 123,
        'nested': {'x': 'y'},
      });

      expect(decoded.name, 'Анна');
      expect(decoded.phone, isNull);
    });

    test('fromJson collapses empty strings to null', () {
      final decoded = CheckoutDraftEntity.fromJson({
        'name': '   ',
        'phone': '',
        'email': 'a@b.c',
      });

      expect(decoded.name, isNull);
      expect(decoded.phone, isNull);
      expect(decoded.email, 'a@b.c');
    });

    test('fromJson coerces non-string scalars into strings', () {
      final decoded = CheckoutDraftEntity.fromJson({
        'loyalty_card': 42,
      });

      expect(decoded.loyaltyCard, '42');
    });

    test('fromJson returns null updatedAt for unparseable date', () {
      final decoded = CheckoutDraftEntity.fromJson({
        'updated_at': 'not-a-date',
      });

      expect(decoded.updatedAt, isNull);
    });

    test('toJson omits null fields', () {
      const draft = CheckoutDraftEntity(name: 'Анна');

      final json = draft.toJson();

      expect(json.containsKey('name'), isTrue);
      expect(json.containsKey('phone'), isFalse);
      expect(json.containsKey('email'), isFalse);
      expect(json.containsKey('loyalty_card'), isFalse);
    });

    test('promo_code key is not emitted or consumed', () {
      const draft = CheckoutDraftEntity(name: 'Анна');

      expect(draft.toJson().containsKey('promo_code'), isFalse);

      final decoded = CheckoutDraftEntity.fromJson({
        'name': 'Анна',
        'promo_code': 'TIFFANI15',
      });

      expect(decoded.name, 'Анна');
      // No promoCode field exists on the entity; unknown key is ignored.
      expect(decoded.toJson().containsKey('promo_code'), isFalse);
    });
  });

  group('CheckoutDraftEntity.copyWith', () {
    test('overrides only supplied fields', () {
      const base = CheckoutDraftEntity(
        name: 'Анна',
        phone: '+1',
        email: 'a@b.c',
        loyaltyCard: '1',
      );

      final next = base.copyWith(phone: '+2', loyaltyCard: '2');

      expect(next.name, 'Анна');
      expect(next.phone, '+2');
      expect(next.email, 'a@b.c');
      expect(next.loyaltyCard, '2');
    });
  });
}
