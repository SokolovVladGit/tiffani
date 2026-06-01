import 'package:flutter_test/flutter_test.dart';
import 'package:tiffani/features/admin/data/dtos/admin_native_product_upsert_result_dto.dart';

void main() {
  group('AdminNativeProductUpsertResultDto', () {
    test('parse maps RPC jsonb fields', () {
      final result = AdminNativeProductUpsertResultDto.parse({
        'product_id': '11111111-1111-1111-1111-111111111111',
        'variant_id': 'admin_8a7b6c5d4e3f2a1b0c9d8e7f6a5b4c3d',
        'title': 'Native',
        'brand': 'B',
        'category': 'C',
        'mark': 'M',
        'photo': 'https://example.com/p.jpg',
        'price': 90,
        'old_price': 120,
        'quantity': 11,
        'app_is_visible': false,
        'is_active': true,
        'effective_is_active': false,
        'tilda_uid': null,
        'image_urls': [
          'https://example.com/a.jpg',
          'https://example.com/b.jpg',
        ],
      });

      expect(result.variantId, startsWith('admin_'));
      expect(result.appIsVisible, isFalse);
      expect(result.effectiveIsActive, isFalse);
      expect(result.imageUrls.length, 2);
    });
  });
}
