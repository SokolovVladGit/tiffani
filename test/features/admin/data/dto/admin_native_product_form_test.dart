import 'package:flutter_test/flutter_test.dart';
import 'package:tiffani/features/admin/data/dtos/admin_native_product_payload_dto.dart';
import 'package:tiffani/features/admin/domain/entities/admin_native_product_form.dart';

void main() {
  group('AdminNativeProductForm', () {
    test('normalizeOptional trims and empty becomes null', () {
      expect(AdminNativeProductForm.normalizeOptional('  '), isNull);
      expect(AdminNativeProductForm.normalizeOptional(' Brand '), 'Brand');
    });

    test('parseDecimal accepts comma decimal separator', () {
      expect(AdminNativeProductForm.parseDecimal('12,5'), 12.5);
      expect(AdminNativeProductForm.parseDecimal('12.5'), 12.5);
    });

    test('normalizeImageUrls trims, dedupes, preserves order, caps at 30', () {
      final urls = List.generate(
        32,
        (i) => 'https://example.com/$i.jpg',
      );
      urls[3] = '  https://example.com/1.jpg  ';
      urls[4] = 'https://example.com/1.jpg';

      final out = AdminNativeProductForm.normalizeImageUrls(urls);

      expect(out.first, 'https://example.com/0.jpg');
      expect(out[1], 'https://example.com/1.jpg');
      expect(out[2], 'https://example.com/2.jpg');
      expect(out.length, 30);
    });

    test('normalizeImageUrls ignores empty rows', () {
      expect(
        AdminNativeProductForm.normalizeImageUrls([
          '',
          '  ',
          'https://example.com/a.jpg',
        ]),
        ['https://example.com/a.jpg'],
      );
    });

    test('validateForSave rejects empty title', () {
      const form = AdminNativeProductForm(title: '', quantity: 0);
      expect(
        form.validateForSave(
          titleInput: '',
          priceInput: '10',
          oldPriceInput: '',
          quantityInput: '1',
          imageUrlInputs: const [],
        ),
        'Укажите название товара',
      );
    });

    test('validateForSave rejects title longer than 500', () {
      const form = AdminNativeProductForm(title: 'x', quantity: 0);
      expect(
        form.validateForSave(
          titleInput: 'x' * 501,
          priceInput: '10',
          oldPriceInput: '',
          quantityInput: '0',
          imageUrlInputs: const [],
        ),
        'Название не должно превышать 500 символов',
      );
    });

    test('validateForSave requires price', () {
      const form = AdminNativeProductForm(title: 'OK', quantity: 0);
      expect(
        form.validateForSave(
          titleInput: 'OK',
          priceInput: '',
          oldPriceInput: '',
          quantityInput: '0',
          imageUrlInputs: const [],
        ),
        'Укажите цену',
      );
    });

    test('validateForSave rejects negative price', () {
      const form = AdminNativeProductForm(title: 'OK', quantity: 0);
      expect(
        form.validateForSave(
          titleInput: 'OK',
          priceInput: '-1',
          oldPriceInput: '',
          quantityInput: '0',
          imageUrlInputs: const [],
        ),
        'Цена должна быть числом не меньше 0',
      );
    });

    test('validateForSave rejects old_price below price', () {
      const form = AdminNativeProductForm(title: 'x', quantity: 0);
      expect(
        form.validateForSave(
          titleInput: 'OK',
          priceInput: '100',
          oldPriceInput: '50',
          quantityInput: '0',
          imageUrlInputs: const [],
        ),
        'Старая цена не может быть меньше текущей цены',
      );
    });

    test('validateForSave rejects negative quantity', () {
      const form = AdminNativeProductForm(title: 'OK', quantity: 0);
      expect(
        form.validateForSave(
          titleInput: 'OK',
          priceInput: '10',
          oldPriceInput: '',
          quantityInput: '-1',
          imageUrlInputs: const [],
        ),
        'Количество должно быть целым числом не меньше 0',
      );
    });

    test('validateForSave rejects non-http image URL', () {
      const form = AdminNativeProductForm(title: 'OK', quantity: 0);
      expect(
        form.validateForSave(
          titleInput: 'OK',
          priceInput: '10',
          oldPriceInput: '',
          quantityInput: '1',
          imageUrlInputs: ['ftp://bad.com/x.jpg'],
        ),
        contains('http://'),
      );
    });

    test('validateForSave rejects more than 30 non-empty image URLs', () {
      const form = AdminNativeProductForm(title: 'OK', quantity: 0);
      final urls = List.generate(31, (i) => 'https://example.com/$i.jpg');
      expect(
        form.validateForSave(
          titleInput: 'OK',
          priceInput: '10',
          oldPriceInput: '',
          quantityInput: '0',
          imageUrlInputs: urls,
        ),
        'Можно указать не более 30 URL изображений',
      );
    });

    test('toValidated clears optional strings and normalizes images', () {
      final form = AdminNativeProductForm.empty().toValidated(
        titleInput: 'Title',
        priceInput: '10,5',
        oldPriceInput: '',
        quantityInput: '2',
        imageUrlInputs: [
          ' https://example.com/a.jpg ',
          '',
          'https://example.com/a.jpg',
        ],
        appIsVisible: true,
      ).copyWith(
        brand: AdminNativeProductForm.normalizeOptional('  '),
        category: AdminNativeProductForm.normalizeOptional(' Cat '),
      );

      expect(form.title, 'Title');
      expect(form.price, 10.5);
      expect(form.oldPrice, isNull);
      expect(form.brand, isNull);
      expect(form.category, 'Cat');
      expect(form.imageUrls, ['https://example.com/a.jpg']);
    });
  });

  group('AdminNativeProductPayloadDto', () {
    test('toJson omits product_id on create and null old_price', () {
      const form = AdminNativeProductForm(
        title: 'Native',
        price: 99.5,
        quantity: 2,
        imageUrls: ['https://example.com/a.jpg'],
        appIsVisible: true,
      );
      final json = AdminNativeProductPayloadDto(form).toJson();

      expect(json.containsKey('product_id'), isFalse);
      expect(json['title'], 'Native');
      expect(json['price'], 99.5);
      expect(json['old_price'], isNull);
      expect(json['image_urls'], ['https://example.com/a.jpg']);
      expect(json['app_is_visible'], isTrue);
    });

    test('toJson includes product_id on edit', () {
      const form = AdminNativeProductForm(
        productId: '11111111-1111-1111-1111-111111111111',
        title: 'Native',
        price: 10,
        quantity: 0,
      );
      final json = AdminNativeProductPayloadDto(form).toJson();
      expect(json['product_id'], form.productId);
    });

    test('toJson excludes variant_id, is_active, and tilda_uid', () {
      const form = AdminNativeProductForm(
        title: 'Native',
        price: 1,
        quantity: 0,
      );
      final json = AdminNativeProductPayloadDto(form).toJson();

      expect(json.containsKey('variant_id'), isFalse);
      expect(json.containsKey('is_active'), isFalse);
      expect(json.containsKey('tilda_uid'), isFalse);
    });

    test('toJson sends trimmed optional nulls', () {
      final form = AdminNativeProductForm(
        title: 'Native',
        brand: null,
        category: null,
        price: 1,
        quantity: 0,
      );
      final json = AdminNativeProductPayloadDto(form).toJson();

      expect(json['brand'], isNull);
      expect(json['category'], isNull);
      expect(json['mark'], isNull);
    });
  });
}
