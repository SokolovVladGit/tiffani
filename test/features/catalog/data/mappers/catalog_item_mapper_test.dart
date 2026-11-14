import 'package:flutter_test/flutter_test.dart';
import 'package:tiffani/features/catalog/data/dto/catalog_item_dto.dart';
import 'package:tiffani/features/catalog/data/mappers/catalog_item_mapper.dart';

void main() {
  group('CatalogItemMapper', () {
    test('entity id equals canonical variant_id, not product_id', () {
      const variantId = '184192311111';
      const productId = '11111111-1111-1111-1111-111111111111';

      final dto = CatalogItemDto.fromMap({
        'variant_id': variantId,
        'product_id': productId,
        'title': 'Test product',
        'is_active': true,
      });

      final entity = dto.toEntity();

      expect(entity.id, variantId);
      expect(entity.id, isNot(productId));
      expect(entity.productId, productId);
    });

    test('text maps to fullDescription and description stays short', () {
      final entity = CatalogItemDto.fromMap({
        'variant_id': '1',
        'product_id': '11111111-1111-1111-1111-111111111111',
        'title': 'Erborian CC Eye',
        'is_active': true,
        'description': 'Короткий лид',
        'text': '<p><strong>CC Eye</strong></p>',
      }).toEntity();

      expect(entity.shortDescription, 'Короткий лид');
      expect(entity.fullDescription, '<p><strong>CC Eye</strong></p>');
    });
  });
}
