/// Admin create/edit form for app-native products (tilda_uid IS NULL).
class AdminNativeProductForm {
  final String? productId;
  final String title;
  final String? brand;
  final String? category;
  final String? mark;
  final String? description;
  final String? text;
  final double? price;
  final double? oldPrice;
  final int quantity;
  final List<String> imageUrls;
  final bool appIsVisible;

  const AdminNativeProductForm({
    this.productId,
    required this.title,
    this.brand,
    this.category,
    this.mark,
    this.description,
    this.text,
    this.price,
    this.oldPrice,
    required this.quantity,
    this.imageUrls = const [],
    this.appIsVisible = true,
  });

  bool get isEdit => productId != null && productId!.isNotEmpty;

  factory AdminNativeProductForm.empty() {
    return const AdminNativeProductForm(
      title: '',
      quantity: 0,
      appIsVisible: true,
      imageUrls: [],
    );
  }

  AdminNativeProductForm copyWith({
    String? productId,
    String? title,
    String? brand,
    String? category,
    String? mark,
    String? description,
    String? text,
    double? price,
    double? oldPrice,
    int? quantity,
    List<String>? imageUrls,
    bool? appIsVisible,
    bool clearOldPrice = false,
  }) {
    return AdminNativeProductForm(
      productId: productId ?? this.productId,
      title: title ?? this.title,
      brand: brand ?? this.brand,
      category: category ?? this.category,
      mark: mark ?? this.mark,
      description: description ?? this.description,
      text: text ?? this.text,
      price: price ?? this.price,
      oldPrice: clearOldPrice ? null : (oldPrice ?? this.oldPrice),
      quantity: quantity ?? this.quantity,
      imageUrls: imageUrls ?? this.imageUrls,
      appIsVisible: appIsVisible ?? this.appIsVisible,
    );
  }

  static String? normalizeOptional(String? value) {
    final trimmed = value?.trim();
    if (trimmed == null || trimmed.isEmpty) return null;
    return trimmed;
  }

  /// Trims, drops empties, validates scheme, dedupes (order preserved), max 30.
  static List<String> normalizeImageUrls(Iterable<String> raw) {
    final seen = <String>{};
    final out = <String>[];
    for (final item in raw) {
      final trimmed = item.trim();
      if (trimmed.isEmpty) continue;
      if (seen.add(trimmed)) out.add(trimmed);
      if (out.length >= 30) break;
    }
    return out;
  }

  static double? parseDecimal(String raw) {
    final normalized = raw.trim().replaceAll(',', '.');
    if (normalized.isEmpty) return null;
    return double.tryParse(normalized);
  }

  static int? parseInt(String raw) {
    final normalized = raw.trim();
    if (normalized.isEmpty) return null;
    return int.tryParse(normalized);
  }

  /// Returns the first validation error message, or null when valid.
  String? validateForSave({
    required String titleInput,
    required String priceInput,
    required String oldPriceInput,
    required String quantityInput,
    required List<String> imageUrlInputs,
  }) {
    final trimmedTitle = titleInput.trim();
    if (trimmedTitle.isEmpty) {
      return 'Укажите название товара';
    }
    if (trimmedTitle.length > 500) {
      return 'Название не должно превышать 500 символов';
    }

    final priceText = priceInput.trim();
    if (priceText.isEmpty) {
      return 'Укажите цену';
    }
    final price = parseDecimal(priceText);
    if (price == null || price < 0) {
      return 'Цена должна быть числом не меньше 0';
    }

    final oldPriceText = oldPriceInput.trim();
    double? oldPrice;
    if (oldPriceText.isNotEmpty) {
      oldPrice = parseDecimal(oldPriceText);
      if (oldPrice == null || oldPrice < 0) {
        return 'Старая цена должна быть числом не меньше 0';
      }
      if (oldPrice < price) {
        return 'Старая цена не может быть меньше текущей цены';
      }
    }

    final quantityText = quantityInput.trim();
    if (quantityText.isEmpty) {
      return 'Укажите количество';
    }
    final quantity = parseInt(quantityText);
    if (quantity == null || quantity < 0) {
      return 'Количество должно быть целым числом не меньше 0';
    }

    var nonEmptyUrlInputs = 0;
    for (final item in imageUrlInputs) {
      if (item.trim().isNotEmpty) nonEmptyUrlInputs++;
    }
    if (nonEmptyUrlInputs > 30) {
      return 'Можно указать не более 30 URL изображений';
    }

    final urls = normalizeImageUrls(imageUrlInputs);
    for (final url in urls) {
      if (url.length > 2048) {
        return 'URL изображения слишком длинный (макс. 2048 символов)';
      }
      final lower = url.toLowerCase();
      if (!lower.startsWith('http://') && !lower.startsWith('https://')) {
        return 'URL изображения должен начинаться с http:// или https://';
      }
    }

    return null;
  }

  /// Builds a form ready for RPC from validated field inputs.
  AdminNativeProductForm toValidated({
    required String titleInput,
    required String priceInput,
    required String oldPriceInput,
    required String quantityInput,
    required List<String> imageUrlInputs,
    required bool appIsVisible,
  }) {
    final oldPriceText = oldPriceInput.trim();
    return copyWith(
      title: titleInput.trim(),
      brand: normalizeOptional(brand),
      category: normalizeOptional(category),
      mark: normalizeOptional(mark),
      description: normalizeOptional(description),
      text: normalizeOptional(text),
      price: parseDecimal(priceInput.trim()),
      oldPrice: oldPriceText.isEmpty
          ? null
          : parseDecimal(oldPriceText.replaceAll(',', '.')),
      clearOldPrice: oldPriceText.isEmpty,
      quantity: parseInt(quantityInput.trim()) ?? 0,
      imageUrls: normalizeImageUrls(imageUrlInputs),
      appIsVisible: appIsVisible,
    );
  }
}

/// Result of [AdminCatalogRepository.upsertNativeProduct].
class AdminNativeProductUpsertResult {
  final String productId;
  final String variantId;
  final String title;
  final String? brand;
  final String? category;
  final String? mark;
  final String? photo;
  final double price;
  final double? oldPrice;
  final int quantity;
  final bool appIsVisible;
  final bool isActive;
  final bool effectiveIsActive;
  final List<String> imageUrls;

  const AdminNativeProductUpsertResult({
    required this.productId,
    required this.variantId,
    required this.title,
    required this.price,
    required this.quantity,
    required this.appIsVisible,
    required this.isActive,
    required this.effectiveIsActive,
    this.brand,
    this.category,
    this.mark,
    this.photo,
    this.oldPrice,
    this.imageUrls = const [],
  });

  bool get isTildaImported => false;
}
