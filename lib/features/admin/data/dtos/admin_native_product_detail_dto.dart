import '../../domain/entities/admin_native_product_form.dart';

class AdminNativeProductDetailDto {
  final Map<String, dynamic> product;
  final List<Map<String, dynamic>> variants;
  final List<Map<String, dynamic>> images;

  const AdminNativeProductDetailDto({
    required this.product,
    required this.variants,
    required this.images,
  });

  AdminNativeProductForm toForm() {
    final tildaUid = product['tilda_uid'] as String?;
    if (tildaUid != null && tildaUid.trim().isNotEmpty) {
      throw FormatException('Tilda products cannot be edited');
    }

    if (variants.isEmpty) {
      throw FormatException('Product has no variants');
    }
    if (variants.length > 1) {
      throw FormatException(
        'Multi-variant native edit is not supported in MVP',
      );
    }

    final variant = variants.first;
    final imageUrls = images
        .map((row) => row['url'] as String?)
        .whereType<String>()
        .map((u) => u.trim())
        .where((u) => u.isNotEmpty)
        .toList(growable: false);

    return AdminNativeProductForm(
      productId: product['id'] as String,
      title: (product['title'] as String?)?.trim() ?? '',
      brand: product['brand'] as String?,
      category: product['category'] as String?,
      mark: product['mark'] as String?,
      description: product['description'] as String?,
      text: product['text'] as String?,
      price: _toDouble(variant['price']),
      oldPrice: _toDouble(variant['old_price']),
      quantity: _toInt(variant['quantity']) ?? 0,
      imageUrls: imageUrls,
      appIsVisible: _toBool(product['app_is_visible'], defaultValue: true),
    );
  }
}

double? _toDouble(dynamic value) {
  if (value == null) return null;
  if (value is double) return value;
  if (value is int) return value.toDouble();
  if (value is String) return double.tryParse(value);
  return null;
}

int? _toInt(dynamic value) {
  if (value == null) return null;
  if (value is int) return value;
  if (value is String) return int.tryParse(value);
  if (value is double) return value.toInt();
  return null;
}

bool _toBool(dynamic value, {bool defaultValue = false}) {
  if (value == null) return defaultValue;
  if (value is bool) return value;
  if (value is int) return value != 0;
  if (value is String) return value.toLowerCase() == 'true' || value == 't';
  return defaultValue;
}
