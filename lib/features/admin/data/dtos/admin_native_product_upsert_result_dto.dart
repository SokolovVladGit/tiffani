import '../../domain/entities/admin_native_product_form.dart';

class AdminNativeProductUpsertResultDto {
  static AdminNativeProductUpsertResult parse(dynamic raw) {
    if (raw is! Map) {
      throw FormatException('Unexpected RPC response type: ${raw.runtimeType}');
    }
    final map = Map<String, dynamic>.from(raw);

    final imageUrlsRaw = map['image_urls'];
    final imageUrls = <String>[];
    if (imageUrlsRaw is List) {
      for (final item in imageUrlsRaw) {
        if (item is String && item.trim().isNotEmpty) {
          imageUrls.add(item.trim());
        }
      }
    }

    final price = _toDouble(map['price']);
    if (price == null) {
      throw FormatException('RPC response missing price');
    }

    return AdminNativeProductUpsertResult(
      productId: map['product_id'] as String,
      variantId: map['variant_id'] as String,
      title: map['title'] as String,
      brand: map['brand'] as String?,
      category: map['category'] as String?,
      mark: map['mark'] as String?,
      photo: map['photo'] as String?,
      price: price,
      oldPrice: _toDouble(map['old_price']),
      quantity: _toInt(map['quantity']) ?? 0,
      appIsVisible: _toBool(map['app_is_visible'], defaultValue: true),
      isActive: _toBool(map['is_active'], defaultValue: true),
      effectiveIsActive: _toBool(map['effective_is_active'], defaultValue: true),
      imageUrls: imageUrls,
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
