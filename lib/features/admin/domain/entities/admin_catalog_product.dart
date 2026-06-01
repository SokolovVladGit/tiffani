import 'admin_native_product_form.dart';

/// Admin catalog list row (product-level, not catalog_items variant rows).
class AdminCatalogProduct {
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

  const AdminCatalogProduct({
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

  /// Tilda-imported when [tildaUid] is a non-empty numeric/source id.
  bool get isTildaImported =>
      tildaUid != null && tildaUid!.trim().isNotEmpty;

  /// Matches public [catalog_items.is_active] after Phase 1 view change.
  bool get isEffectivelyVisibleInCatalog => isActive && appIsVisible;

  AdminCatalogProduct copyWith({
    String? title,
    String? brand,
    String? category,
    String? mark,
    String? photo,
    bool? appIsVisible,
    bool? isActive,
  }) {
    return AdminCatalogProduct(
      id: id,
      title: title ?? this.title,
      isActive: isActive ?? this.isActive,
      appIsVisible: appIsVisible ?? this.appIsVisible,
      brand: brand ?? this.brand,
      category: category ?? this.category,
      mark: mark ?? this.mark,
      photo: photo ?? this.photo,
      tildaUid: tildaUid,
      createdAt: createdAt,
    );
  }

  factory AdminCatalogProduct.fromUpsertResult(AdminNativeProductUpsertResult r) {
    return AdminCatalogProduct(
      id: r.productId,
      title: r.title,
      brand: r.brand,
      category: r.category,
      mark: r.mark,
      photo: r.photo,
      isActive: r.isActive,
      appIsVisible: r.appIsVisible,
      tildaUid: null,
      createdAt: DateTime.now(),
    );
  }
}

/// Result of [AdminCatalogRepository.setVisibility].
class AdminCatalogVisibilityResult {
  final String productId;
  final bool appIsVisible;
  final bool effectiveIsActive;

  const AdminCatalogVisibilityResult({
    required this.productId,
    required this.appIsVisible,
    required this.effectiveIsActive,
  });
}
