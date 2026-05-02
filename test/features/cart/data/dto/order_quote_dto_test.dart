import 'package:flutter_test/flutter_test.dart';
import 'package:tiffani/features/cart/data/dto/order_quote_dto.dart';

void main() {
  group('OrderQuoteDto.parseQuote', () {
    test('ok=true with discount: extracts money + applied label + promo status',
        () {
      final raw = <String, dynamic>{
        'ok': true,
        'pricing_version': 'discount_v1',
        'subtotal_amount': 250,
        'discount_amount': 25,
        'fulfillment_fee': 50,
        'grand_total_amount': 275,
        'promo': {'status': 'applied', 'code': 'TEST10'},
        'applied_discounts': [
          {
            'kind': 'promocode',
            'code': 'TEST10',
            'name': 'TEST10',
            'percent_off': 10,
            'discount_amount': 25,
            'campaign_id': '11111111-1111-1111-1111-111111111111',
          },
        ],
        'lines': const [],
        'errors': const [],
      };

      final q = OrderQuoteDto.parseQuote(raw);
      expect(q.ok, isTrue);
      expect(q.pricingVersion, 'discount_v1');
      expect(q.subtotalAmount, 250);
      expect(q.discountAmount, 25);
      expect(q.fulfillmentFee, 50);
      expect(q.grandTotalAmount, 275);
      expect(q.hasDiscount, isTrue);
      expect(q.promoStatus, 'applied');
      expect(q.appliedDiscountLabels, [
        'Промокод применён: TEST10 (-10%)',
      ]);
      expect(q.errors, isEmpty);
    });

    test('ok=true without discount: zero discount, no labels', () {
      final raw = <String, dynamic>{
        'ok': true,
        'subtotal_amount': 100,
        'discount_amount': 0,
        'fulfillment_fee': 50,
        'grand_total_amount': 150,
        'promo': {'status': 'not_provided'},
        'applied_discounts': const [],
      };
      final q = OrderQuoteDto.parseQuote(raw);
      expect(q.ok, isTrue);
      expect(q.hasDiscount, isFalse);
      expect(q.appliedDiscountLabels, isEmpty);
      expect(q.promoStatus, 'not_provided');
    });

    test(
        'ok=true with non_best_discount + automatic: shows the automatic discount label',
        () {
      final raw = <String, dynamic>{
        'ok': true,
        'subtotal_amount': 100,
        'discount_amount': 20,
        'fulfillment_fee': 0,
        'grand_total_amount': 80,
        'promo': {'status': 'not_best_discount', 'code': 'GPROMO10'},
        'applied_discounts': [
          {
            'kind': 'automatic',
            'name': 'Brand A 20%',
            'percent_off': 20,
            'discount_amount': 20,
            'campaign_id': '22222222-2222-2222-2222-222222222222',
          },
        ],
      };
      final q = OrderQuoteDto.parseQuote(raw);
      expect(q.ok, isTrue);
      expect(q.discountAmount, 20);
      expect(q.promoStatus, 'not_best_discount');
      expect(q.appliedDiscountLabels, ['Скидка: Brand A 20% (-20%)']);
    });

    test('ok=false with errors: surfaces error code + message', () {
      final raw = <String, dynamic>{
        'ok': false,
        'errors': [
          {
            'code': 'unknown_variant',
            'message': 'Variant not found',
            'variant_id': 'TST-V-X',
          },
        ],
      };
      final q = OrderQuoteDto.parseQuote(raw);
      expect(q.ok, isFalse);
      expect(q.errors, hasLength(1));
      expect(q.errors.first.code, 'unknown_variant');
      expect(q.errors.first.variantId, 'TST-V-X');
    });

    test('non-map input: returns ok=false with quote_unavailable', () {
      final q = OrderQuoteDto.parseQuote('garbage');
      expect(q.ok, isFalse);
      expect(q.errors.first.code, 'quote_unavailable');
    });

    test('malformed applied_discounts: drops bad entries, never throws', () {
      final raw = <String, dynamic>{
        'ok': true,
        'subtotal_amount': 100,
        'discount_amount': 10,
        'fulfillment_fee': 0,
        'grand_total_amount': 90,
        'applied_discounts': const [
          'not-an-object',
          42,
          null,
          {'discount_amount': 0}, // zero amount → skip
          {'kind': 'promocode', 'code': 'OK', 'percent_off': '5', 'discount_amount': '5'},
        ],
      };
      final q = OrderQuoteDto.parseQuote(raw);
      expect(q.ok, isTrue);
      expect(q.appliedDiscountLabels, ['Промокод применён: OK (-5%)']);
    });

    test('malformed promo block: ok still parsed, promoStatus null', () {
      final raw = <String, dynamic>{
        'ok': true,
        'subtotal_amount': 100,
        'discount_amount': 0,
        'fulfillment_fee': 0,
        'grand_total_amount': 100,
        'promo': 'not-a-map',
      };
      final q = OrderQuoteDto.parseQuote(raw);
      expect(q.ok, isTrue);
      expect(q.promoStatus, isNull);
    });
  });

  group('OrderQuoteDto.parseOrderResult', () {
    test('legacy v2 response: parses base fields, leaves Phase 1 fields null',
        () {
      final raw = <String, dynamic>{
        'order_id': 'aaaa-bbbb-cccc',
        'total_items': 2,
        'total_quantity': 3,
        'total_price': 250,
      };
      final r = OrderQuoteDto.parseOrderResult(raw);
      expect(r.orderId, 'aaaa-bbbb-cccc');
      expect(r.totalItems, 2);
      expect(r.totalQuantity, 3);
      expect(r.totalPrice, 250);
      expect(r.subtotalAmount, isNull);
      expect(r.discountAmount, isNull);
      expect(r.grandTotalAmount, isNull);
      expect(r.pricingVersion, isNull);
      expect(r.hasDiscount, isFalse);
      expect(r.effectivePayableAmount, 250);
    });

    test('v3 response: parses Phase 1 snapshot fields and prefers grand total',
        () {
      final raw = <String, dynamic>{
        'order_id': 'order-1',
        'total_items': 1,
        'total_quantity': 1,
        'total_price': 250,
        'subtotal_amount': 250,
        'discount_amount': 25,
        'fulfillment_fee': 50,
        'grand_total_amount': 275,
        'pricing_version': 'discount_v1',
        'promo': {'status': 'applied'},
      };
      final r = OrderQuoteDto.parseOrderResult(raw);
      expect(r.discountAmount, 25);
      expect(r.grandTotalAmount, 275);
      expect(r.pricingVersion, 'discount_v1');
      expect(r.promoStatus, 'applied');
      expect(r.hasDiscount, isTrue);
      expect(r.effectivePayableAmount, 275);
    });

    test('numeric strings are coerced safely', () {
      final raw = <String, dynamic>{
        'order_id': 'order-2',
        'total_items': '2',
        'total_quantity': '5',
        'total_price': '100.5',
        'discount_amount': '10.25',
      };
      final r = OrderQuoteDto.parseOrderResult(raw);
      expect(r.totalItems, 2);
      expect(r.totalQuantity, 5);
      expect(r.totalPrice, closeTo(100.5, 1e-9));
      expect(r.discountAmount, closeTo(10.25, 1e-9));
    });

    test('missing order_id throws FormatException', () {
      expect(
        () => OrderQuoteDto.parseOrderResult(<String, dynamic>{
          'total_items': 1,
          'total_quantity': 1,
          'total_price': 1,
        }),
        throwsFormatException,
      );
    });
  });

  group('OrderQuoteDto.localizeErrorCode', () {
    test('known codes return Russian messages', () {
      expect(OrderQuoteDto.localizeErrorCode('missing_name'), 'Укажите имя');
      expect(
        OrderQuoteDto.localizeErrorCode('promo_limit_reached'),
        'Лимит использований промокода исчерпан',
      );
      expect(
        OrderQuoteDto.localizeErrorCode('quote_changed_or_discount_unavailable'),
        startsWith('Скидки изменились'),
      );
    });

    test('unknown code falls back to backend message, then default', () {
      expect(
        OrderQuoteDto.localizeErrorCode('weird_code', backendMessage: 'oops'),
        'oops',
      );
      expect(OrderQuoteDto.localizeErrorCode('weird_code'),
          startsWith('Произошла ошибка'));
    });
  });

  group('OrderQuoteDto.humanizePromoStatus', () {
    test('null/empty/no-input statuses return null', () {
      expect(OrderQuoteDto.humanizePromoStatus(null), isNull);
      expect(OrderQuoteDto.humanizePromoStatus(''), isNull);
      expect(OrderQuoteDto.humanizePromoStatus('not_provided'), isNull);
    });

    test('applied + not_best_discount return user-friendly text', () {
      expect(OrderQuoteDto.humanizePromoStatus('applied'), 'Промокод применён');
      expect(
        OrderQuoteDto.humanizePromoStatus('not_best_discount')?.toLowerCase(),
        contains('автоматическая скидка выгоднее'),
      );
    });
  });
}
