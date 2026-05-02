import 'package:flutter_test/flutter_test.dart';
import 'package:tiffani/features/admin/domain/entities/discount_campaign_target_entity.dart';
import 'package:tiffani/features/admin/presentation/widgets/admin_target_mapping.dart';

void main() {
  group('buildAllTarget', () {
    test('emits all + exact + null value', () {
      final t = buildAllTarget();
      expect(t.targetType, DiscountTargetType.all);
      expect(t.matchMode, DiscountTargetMatchMode.exact);
      expect(t.targetValue, isNull);
    });
  });

  group('buildCategoryTarget', () {
    test('trims value, keeps case', () {
      final t = buildCategoryTarget('  Уход за волосами  ');
      expect(t.targetType, DiscountTargetType.category);
      expect(t.matchMode, DiscountTargetMatchMode.exact);
      expect(t.targetValue, 'Уход за волосами');
    });

    test('empty value becomes null (invalid friendly row)', () {
      final t = buildCategoryTarget('   ');
      expect(t.targetValue, isNull);
      expect(isFriendlyTarget(t), isFalse);
    });
  });

  group('buildBrandTarget', () {
    test('trims value', () {
      final t = buildBrandTarget("L'Oréal");
      expect(t.targetType, DiscountTargetType.brand);
      expect(t.matchMode, DiscountTargetMatchMode.exact);
      expect(t.targetValue, "L'Oréal");
    });
  });

  group('buildProductTarget', () {
    test('uses product_id + exact', () {
      final t = buildProductTarget('abc-123');
      expect(t.targetType, DiscountTargetType.productId);
      expect(t.matchMode, DiscountTargetMatchMode.exact);
      expect(t.targetValue, 'abc-123');
    });
  });

  group('isFriendlyTarget', () {
    test('all is friendly regardless of value', () {
      expect(isFriendlyTarget(buildAllTarget()), isTrue);
    });

    test('category/brand/product are friendly with non-empty value', () {
      expect(isFriendlyTarget(buildCategoryTarget('Cat')), isTrue);
      expect(isFriendlyTarget(buildBrandTarget('Br')), isTrue);
      expect(isFriendlyTarget(buildProductTarget('pid')), isTrue);
    });

    test('category/brand/product without value are not friendly', () {
      expect(isFriendlyTarget(buildCategoryTarget('')), isFalse);
      expect(isFriendlyTarget(buildBrandTarget('  ')), isFalse);
      expect(isFriendlyTarget(buildProductTarget('')), isFalse);
    });

    test('prefix/contains are never friendly', () {
      final t = DiscountCampaignTargetEntity(
        targetType: DiscountTargetType.category,
        matchMode: DiscountTargetMatchMode.prefix,
        targetValue: 'Hair',
      );
      expect(isFriendlyTarget(t), isFalse);
    });

    test('mark/product_tilda_uid/variant_id are not friendly', () {
      for (final type in [
        DiscountTargetType.mark,
        DiscountTargetType.productTildaUid,
        DiscountTargetType.variantId,
      ]) {
        final t = DiscountCampaignTargetEntity(
          targetType: type,
          matchMode: DiscountTargetMatchMode.exact,
          targetValue: 'x',
        );
        expect(isFriendlyTarget(t), isFalse,
            reason: 'type $type should not be friendly');
      }
    });
  });

  group('isAdvancedTarget', () {
    test('inverse of isFriendlyTarget', () {
      expect(isAdvancedTarget(buildAllTarget()), isFalse);
      expect(isAdvancedTarget(buildBrandTarget('X')), isFalse);
      final legacy = DiscountCampaignTargetEntity(
        targetType: DiscountTargetType.mark,
        matchMode: DiscountTargetMatchMode.contains,
        targetValue: 'sale',
      );
      expect(isAdvancedTarget(legacy), isTrue);
    });
  });

  group('friendlyKindOf / friendlyTargetTypeLabel', () {
    test('returns correct kind and label for each friendly shape', () {
      expect(friendlyKindOf(buildAllTarget()), FriendlyTargetKind.all);
      expect(friendlyTargetTypeLabel(buildAllTarget()), 'Все товары');
      expect(friendlyKindOf(buildCategoryTarget('C')),
          FriendlyTargetKind.category);
      expect(friendlyTargetTypeLabel(buildCategoryTarget('C')), 'Категория');
      expect(friendlyKindOf(buildBrandTarget('B')), FriendlyTargetKind.brand);
      expect(friendlyTargetTypeLabel(buildBrandTarget('B')), 'Бренд');
      expect(friendlyKindOf(buildProductTarget('P')),
          FriendlyTargetKind.product);
      expect(friendlyTargetTypeLabel(buildProductTarget('P')), 'Товар');
    });

    test('returns null for advanced rows', () {
      final legacy = DiscountCampaignTargetEntity(
        targetType: DiscountTargetType.variantId,
        matchMode: DiscountTargetMatchMode.exact,
        targetValue: 'v1',
      );
      expect(friendlyKindOf(legacy), isNull);
      expect(friendlyTargetTypeLabel(legacy), 'Расширенное условие');
    });
  });

  group('advancedTargetSummary', () {
    test('formats legacy rows with type/mode/value', () {
      final t = DiscountCampaignTargetEntity(
        targetType: DiscountTargetType.productTildaUid,
        matchMode: DiscountTargetMatchMode.prefix,
        targetValue: '12345',
      );
      expect(
        advancedTargetSummary(t),
        'Tilda UID товара · начинается с · 12345',
      );
    });

    test('all without value collapses cleanly', () {
      expect(advancedTargetSummary(buildAllTarget()), 'Все товары');
    });
  });

  group('hasAllTarget / normalizeTargets', () {
    test('hasAllTarget detects any all row', () {
      expect(hasAllTarget([]), isFalse);
      expect(hasAllTarget([buildBrandTarget('X')]), isFalse);
      expect(hasAllTarget([buildAllTarget(), buildBrandTarget('X')]), isTrue);
    });

    test('normalizeTargets collapses to a single all row when present', () {
      final normalized = normalizeTargets([
        buildBrandTarget('L'),
        buildAllTarget(),
        buildCategoryTarget('C'),
      ]);
      expect(normalized.length, 1);
      expect(normalized.first.targetType, DiscountTargetType.all);
    });

    test('normalizeTargets dedupes identical rows (case-insensitive value)',
        () {
      final normalized = normalizeTargets([
        buildBrandTarget("L'Oréal"),
        buildBrandTarget("l'oréal"),
        buildCategoryTarget('Hair'),
      ]);
      expect(normalized.length, 2);
    });

    test('normalizeTargets preserves order of first occurrence', () {
      final normalized = normalizeTargets([
        buildBrandTarget('A'),
        buildCategoryTarget('C'),
        buildBrandTarget('A'),
      ]);
      expect(normalized.map((t) => t.targetType).toList(), [
        DiscountTargetType.brand,
        DiscountTargetType.category,
      ]);
    });

    test('normalizeTargets returns empty list for empty input', () {
      expect(normalizeTargets(const []), isEmpty);
    });
  });
}
