import 'package:flutter_test/flutter_test.dart';
import 'package:tiffani/features/admin/data/dto/discount_campaign_dto.dart';
import 'package:tiffani/features/admin/data/dto/discount_campaign_target_dto.dart';
import 'package:tiffani/features/admin/domain/entities/discount_campaign_entity.dart';
import 'package:tiffani/features/admin/domain/entities/discount_campaign_target_entity.dart';

void main() {
  group('DiscountCampaignDto.parse', () {
    test('parses a promocode row with full fields', () {
      final entity = DiscountCampaignDto.parse({
        'id': 'aaaa-bbbb-cccc',
        'kind': 'promocode',
        'name': 'Spring 25',
        'code': 'SPRING25',
        'description': 'Promo for spring',
        'percent_off': '15.50',
        'min_order_amount': '500',
        'starts_at': '2026-04-01T10:00:00Z',
        'ends_at': '2026-05-01T10:00:00Z',
        'max_redemptions': 100,
        'used_count': '7',
        'is_active': true,
      });

      expect(entity.id, 'aaaa-bbbb-cccc');
      expect(entity.kind, DiscountCampaignKind.promocode);
      expect(entity.code, 'SPRING25');
      expect(entity.percentOff, 15.5);
      expect(entity.minOrderAmount, 500);
      expect(entity.maxRedemptions, 100);
      expect(entity.usedCount, 7);
      expect(entity.isActive, isTrue);
      expect(entity.startsAt?.isUtc, isTrue);
    });

    test('parses an automatic campaign with no targets and missing optionals',
        () {
      final entity = DiscountCampaignDto.parse({
        'id': 'auto-1',
        'kind': 'automatic',
        'name': 'Flat 20',
        'percent_off': 20,
        'min_order_amount': 0,
        'used_count': 0,
        'is_active': false,
      });
      expect(entity.kind, DiscountCampaignKind.automatic);
      expect(entity.percentOff, 20.0);
      expect(entity.code, isNull);
      expect(entity.startsAt, isNull);
      expect(entity.endsAt, isNull);
      expect(entity.maxRedemptions, isNull);
      expect(entity.isActive, isFalse);
      expect(entity.targets, isEmpty);
    });

    test('tolerates missing/garbage fields', () {
      final entity = DiscountCampaignDto.parse({
        'id': 1234, // numeric id coerced to string
        'kind': null, // unknown kind defaults to automatic
        'name': null,
        'percent_off': 'bad',
        'min_order_amount': null,
        'is_active': 'true',
        'used_count': 'abc',
      });
      expect(entity.id, '1234');
      expect(entity.kind, DiscountCampaignKind.automatic);
      expect(entity.name, '');
      expect(entity.percentOff, 0);
      expect(entity.minOrderAmount, 0);
      expect(entity.isActive, isTrue);
      expect(entity.usedCount, 0);
    });
  });

  group('DiscountCampaignDto.toInsertMap / toUpdateMap', () {
    final base = DiscountCampaignEntity(
      kind: DiscountCampaignKind.promocode,
      name: '  Spring 25  ',
      code: ' spring25 ',
      description: '  ',
      percentOff: 15,
      minOrderAmount: 0,
      isActive: true,
      startsAt: DateTime.utc(2026, 4, 1, 10),
      endsAt: DateTime.utc(2026, 5, 1, 10),
      maxRedemptions: 50,
    );

    test('insert map trims/uppercases code, drops blank description, '
        'serializes timestamps as ISO8601 UTC', () {
      final map = DiscountCampaignDto.toInsertMap(base);
      expect(map['kind'], 'promocode');
      expect(map['name'], 'Spring 25');
      expect(map['code'], 'SPRING25');
      expect(map['description'], isNull);
      expect(map['percent_off'], 15);
      expect(map['min_order_amount'], 0);
      expect(map['starts_at'], '2026-04-01T10:00:00.000Z');
      expect(map['ends_at'], '2026-05-01T10:00:00.000Z');
      expect(map['max_redemptions'], 50);
      expect(map['is_active'], true);
      expect(map.containsKey('id'), isFalse);
      expect(map.containsKey('used_count'), isFalse);
    });

    test('update map omits kind to prevent kind switching', () {
      final map = DiscountCampaignDto.toUpdateMap(base);
      expect(map.containsKey('kind'), isFalse);
      expect(map['code'], 'SPRING25');
      expect(map['name'], 'Spring 25');
    });

    test('null timestamps serialize as null', () {
      final auto = DiscountCampaignEntity(
        kind: DiscountCampaignKind.automatic,
        name: 'Auto',
        percentOff: 5,
      );
      final map = DiscountCampaignDto.toInsertMap(auto);
      expect(map['starts_at'], isNull);
      expect(map['ends_at'], isNull);
      expect(map['code'], isNull);
      expect(map['max_redemptions'], isNull);
    });
  });

  group('DiscountCampaignTargetDto', () {
    test('parses a brand target', () {
      final entity = DiscountCampaignTargetDto.parse({
        'id': 't1',
        'campaign_id': 'c1',
        'target_type': 'brand',
        'target_value': 'Hermes',
        'match_mode': 'contains',
      });
      expect(entity.id, 't1');
      expect(entity.campaignId, 'c1');
      expect(entity.targetType, DiscountTargetType.brand);
      expect(entity.targetValue, 'Hermes');
      expect(entity.matchMode, DiscountTargetMatchMode.contains);
      expect(entity.summaryLabel, 'Бренд: Hermes');
      expect(entity.hasValidValue, isTrue);
    });

    test('parses an "all" target with null value', () {
      final entity = DiscountCampaignTargetDto.parse({
        'id': 't2',
        'campaign_id': 'c2',
        'target_type': 'all',
        'target_value': null,
        'match_mode': 'exact',
      });
      expect(entity.targetType, DiscountTargetType.all);
      expect(entity.targetValue, isNull);
      expect(entity.summaryLabel, 'Все товары');
      expect(entity.hasValidValue, isTrue);
    });

    test('falls back to defaults for unknown enum values', () {
      final entity = DiscountCampaignTargetDto.parse({
        'target_type': 'mystery',
        'match_mode': 'mystery',
      });
      expect(entity.targetType, DiscountTargetType.all);
      expect(entity.matchMode, DiscountTargetMatchMode.exact);
    });

    test('insert map enforces null value for "all" and trims strings', () {
      final map = DiscountCampaignTargetDto.toInsertMap(
        campaignId: 'cmp-1',
        target: const DiscountCampaignTargetEntity(
          targetType: DiscountTargetType.all,
          targetValue: 'should-be-dropped',
          matchMode: DiscountTargetMatchMode.exact,
        ),
      );
      expect(map['campaign_id'], 'cmp-1');
      expect(map['target_type'], 'all');
      expect(map['target_value'], isNull);
      expect(map['match_mode'], 'exact');
    });

    test('insert map trims values for typed targets', () {
      final map = DiscountCampaignTargetDto.toInsertMap(
        campaignId: 'cmp-2',
        target: const DiscountCampaignTargetEntity(
          targetType: DiscountTargetType.variantId,
          targetValue: '  abc-123  ',
          matchMode: DiscountTargetMatchMode.prefix,
        ),
      );
      expect(map['target_type'], 'variant_id');
      expect(map['target_value'], 'abc-123');
      expect(map['match_mode'], 'prefix');
    });

    test('insert map nullifies whitespace-only typed values', () {
      final map = DiscountCampaignTargetDto.toInsertMap(
        campaignId: 'cmp-3',
        target: const DiscountCampaignTargetEntity(
          targetType: DiscountTargetType.brand,
          targetValue: '   ',
          matchMode: DiscountTargetMatchMode.exact,
        ),
      );
      // The DB constraint will reject this; the DTO mirrors that by sending null.
      expect(map['target_value'], isNull);
    });
  });

  group('DiscountCampaignEntity.copyWith', () {
    test('clear flags reset optional fields', () {
      final c = DiscountCampaignEntity(
        kind: DiscountCampaignKind.promocode,
        name: 'X',
        code: 'XXX',
        description: 'desc',
        percentOff: 10,
        startsAt: DateTime(2026, 1, 1),
        endsAt: DateTime(2026, 12, 31),
        maxRedemptions: 99,
      );
      final cleared = c.copyWith(
        clearCode: true,
        clearDescription: true,
        clearStartsAt: true,
        clearEndsAt: true,
        clearMaxRedemptions: true,
      );
      expect(cleared.code, isNull);
      expect(cleared.description, isNull);
      expect(cleared.startsAt, isNull);
      expect(cleared.endsAt, isNull);
      expect(cleared.maxRedemptions, isNull);
      expect(cleared.name, 'X');
      expect(cleared.percentOff, 10);
    });
  });
}
