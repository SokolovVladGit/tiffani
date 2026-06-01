import 'package:flutter_test/flutter_test.dart';
import 'package:tiffani/features/admin/data/dtos/admin_catalog_product_dto.dart';

void main() {
  group('AdminCatalogProductDto', () {
    test('fromMap parses visibility and tilda source', () {
      final dto = AdminCatalogProductDto.fromMap({
        'id': '11111111-1111-1111-1111-111111111111',
        'title': 'Test product',
        'brand': 'Brand',
        'category': 'Cat',
        'mark': 'NEW',
        'photo': 'https://example.com/p.jpg',
        'is_active': true,
        'app_is_visible': false,
        'tilda_uid': '184192311111',
        'created_at': '2026-06-01T12:00:00Z',
      });

      final entity = dto.toEntity();
      expect(entity.appIsVisible, isFalse);
      expect(entity.isTildaImported, isTrue);
      expect(entity.isEffectivelyVisibleInCatalog, isFalse);
      expect(entity.createdAt, isNotNull);
    });

    test('visibilityResultFromRpc parses jsonb fields', () {
      final result = visibilityResultFromRpc({
        'product_id': '11111111-1111-1111-1111-111111111111',
        'app_is_visible': true,
        'effective_is_active': false,
      });

      expect(result.appIsVisible, isTrue);
      expect(result.effectiveIsActive, isFalse);
    });
  });
}
