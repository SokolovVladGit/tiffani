import '../../domain/entities/admin_catalog_product.dart';

class AdminCatalogProductDto {
  final String id;
  final String title;
  final String? brand;
  final String? category;
  final String? mark;
  final String? photo;
  final bool isActive;
  final bool appIsVisible;
  final String? tildaUid;
  final DateTime? createdAt;

  const AdminCatalogProductDto({
    required this.id,
    required this.title,
    required this.isActive,
    required this.appIsVisible,
    this.brand,
    this.category,
    this.mark,
    this.photo,
    this.tildaUid,
    this.createdAt,
  });

  factory AdminCatalogProductDto.fromMap(Map<String, dynamic> map) {
    return AdminCatalogProductDto(
      id: map['id'] as String,
      title: (map['title'] as String?)?.trim().isNotEmpty == true
          ? map['title'] as String
          : '—',
      brand: map['brand'] as String?,
      category: map['category'] as String?,
      mark: map['mark'] as String?,
      photo: map['photo'] as String?,
      isActive: _toBool(map['is_active']),
      appIsVisible: _toBool(map['app_is_visible'], defaultValue: true),
      tildaUid: map['tilda_uid'] as String?,
      createdAt: _toDateTime(map['created_at']),
    );
  }

  AdminCatalogProduct toEntity() {
    return AdminCatalogProduct(
      id: id,
      title: title,
      brand: brand,
      category: category,
      mark: mark,
      photo: photo,
      isActive: isActive,
      appIsVisible: appIsVisible,
      tildaUid: tildaUid,
      createdAt: createdAt,
    );
  }
}

AdminCatalogVisibilityResult visibilityResultFromRpc(dynamic raw) {
  if (raw is! Map) {
    throw FormatException('Unexpected RPC response type: ${raw.runtimeType}');
  }
  final map = Map<String, dynamic>.from(raw);
  return AdminCatalogVisibilityResult(
    productId: map['product_id'] as String,
    appIsVisible: _toBool(map['app_is_visible'], defaultValue: true),
    effectiveIsActive: _toBool(map['effective_is_active']),
  );
}

bool _toBool(dynamic value, {bool defaultValue = false}) {
  if (value == null) return defaultValue;
  if (value is bool) return value;
  if (value is int) return value != 0;
  if (value is String) return value.toLowerCase() == 'true' || value == 't';
  return defaultValue;
}

DateTime? _toDateTime(dynamic value) {
  if (value == null) return null;
  if (value is DateTime) return value;
  if (value is String) return DateTime.tryParse(value);
  return null;
}
