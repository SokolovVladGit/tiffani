import 'package:flutter_test/flutter_test.dart';
import 'package:tiffani/features/admin/data/dtos/admin_native_product_detail_dto.dart';

void main() {
  group('AdminNativeProductDetailDto', () {
    const productId = '11111111-1111-1111-1111-111111111111';

    test('toForm parses product, variant, and images in list order', () {
      final dto = AdminNativeProductDetailDto(
        product: {
          'id': productId,
          'title': ' Native title ',
          'brand': 'Brand',
          'category': 'Cat',
          'mark': 'NEW',
          'description': 'Short',
          'text': 'Long',
          'app_is_visible': false,
          'tilda_uid': null,
        },
        variants: [
          {
            'variant_id': 'admin_abc123',
            'price': 199.5,
            'old_price': 250,
            'quantity': 4,
          },
        ],
        images: [
          {'url': 'https://example.com/second.jpg', 'position': 1},
          {'url': 'https://example.com/first.jpg', 'position': 0},
        ],
      );

      final form = dto.toForm();

      expect(form.productId, productId);
      expect(form.title, 'Native title');
      expect(form.brand, 'Brand');
      expect(form.price, 199.5);
      expect(form.oldPrice, 250);
      expect(form.quantity, 4);
      expect(form.appIsVisible, isFalse);
      expect(
        form.imageUrls,
        [
          'https://example.com/second.jpg',
          'https://example.com/first.jpg',
        ],
      );
    });

    test('toForm handles empty images list', () {
      final dto = AdminNativeProductDetailDto(
        product: {
          'id': productId,
          'title': 'No images',
          'tilda_uid': null,
          'app_is_visible': true,
        },
        variants: [
          {'variant_id': 'admin_x', 'price': 1, 'quantity': 0},
        ],
        images: const [],
      );

      expect(dto.toForm().imageUrls, isEmpty);
    });

    test('toForm rejects Tilda product', () {
      final dto = AdminNativeProductDetailDto(
        product: {
          'id': productId,
          'title': 'Tilda',
          'tilda_uid': '184192311111',
        },
        variants: [
          {'variant_id': '184192311111', 'price': 10, 'quantity': 1},
        ],
        images: const [],
      );

      expect(
        () => dto.toForm(),
        throwsA(
          isA<FormatException>().having(
            (e) => e.message,
            'message',
            'Tilda products cannot be edited',
          ),
        ),
      );
    });

    test('toForm rejects multi-variant native product', () {
      final dto = AdminNativeProductDetailDto(
        product: {
          'id': productId,
          'title': 'Multi',
          'tilda_uid': null,
        },
        variants: [
          {'variant_id': 'admin_a', 'price': 1, 'quantity': 0},
          {'variant_id': 'admin_b', 'price': 2, 'quantity': 0},
        ],
        images: const [],
      );

      expect(
        () => dto.toForm(),
        throwsA(
          isA<FormatException>().having(
            (e) => e.message,
            'message',
            contains('Multi-variant'),
          ),
        ),
      );
    });
  });
}
