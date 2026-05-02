/// Editable representation of a row in `public.discount_campaign_targets`.
///
/// `id` and `campaignId` are `null` for unsaved rows. The save flow for
/// automatic campaigns uses delete-then-insert (the spec considers this
/// acceptable for the admin MVP), so existing IDs are not strictly needed
/// during save — they are kept here so the UI can remember rendering order
/// and let the user discard a row by id when applicable.
enum DiscountTargetType {
  all('all'),
  category('category'),
  brand('brand'),
  mark('mark'),
  productTildaUid('product_tilda_uid'),
  productId('product_id'),
  variantId('variant_id');

  final String wireValue;
  const DiscountTargetType(this.wireValue);

  static DiscountTargetType fromWire(String? value) {
    for (final v in DiscountTargetType.values) {
      if (v.wireValue == value) return v;
    }
    return DiscountTargetType.all;
  }

  String get russianLabel {
    switch (this) {
      case DiscountTargetType.all:
        return 'Все товары';
      case DiscountTargetType.category:
        return 'Категория';
      case DiscountTargetType.brand:
        return 'Бренд';
      case DiscountTargetType.mark:
        return 'Метка';
      case DiscountTargetType.productTildaUid:
        return 'Tilda UID товара';
      case DiscountTargetType.productId:
        return 'Product ID';
      case DiscountTargetType.variantId:
        return 'Variant ID';
    }
  }

  bool get requiresValue => this != DiscountTargetType.all;
}

enum DiscountTargetMatchMode {
  exact('exact'),
  prefix('prefix'),
  contains('contains');

  final String wireValue;
  const DiscountTargetMatchMode(this.wireValue);

  static DiscountTargetMatchMode fromWire(String? value) {
    for (final v in DiscountTargetMatchMode.values) {
      if (v.wireValue == value) return v;
    }
    return DiscountTargetMatchMode.exact;
  }

  String get russianLabel {
    switch (this) {
      case DiscountTargetMatchMode.exact:
        return 'Точное совпадение';
      case DiscountTargetMatchMode.prefix:
        return 'Начинается с';
      case DiscountTargetMatchMode.contains:
        return 'Содержит';
    }
  }
}

class DiscountCampaignTargetEntity {
  final String? id;
  final String? campaignId;
  final DiscountTargetType targetType;
  final String? targetValue;
  final DiscountTargetMatchMode matchMode;

  const DiscountCampaignTargetEntity({
    this.id,
    this.campaignId,
    required this.targetType,
    this.targetValue,
    this.matchMode = DiscountTargetMatchMode.exact,
  });

  /// Server-side check `chk_discount_targets_value_presence` requires that
  /// every non-`all` target has a non-null value. This mirrors that for
  /// pre-flight UI validation.
  bool get hasValidValue {
    if (targetType == DiscountTargetType.all) return true;
    final v = targetValue?.trim();
    return v != null && v.isNotEmpty;
  }

  String get summaryLabel {
    if (targetType == DiscountTargetType.all) {
      return 'Все товары';
    }
    final value = (targetValue ?? '').trim();
    return value.isEmpty
        ? targetType.russianLabel
        : '${targetType.russianLabel}: $value';
  }

  DiscountCampaignTargetEntity copyWith({
    String? id,
    String? campaignId,
    DiscountTargetType? targetType,
    String? targetValue,
    DiscountTargetMatchMode? matchMode,
    bool clearTargetValue = false,
  }) {
    return DiscountCampaignTargetEntity(
      id: id ?? this.id,
      campaignId: campaignId ?? this.campaignId,
      targetType: targetType ?? this.targetType,
      targetValue:
          clearTargetValue ? null : (targetValue ?? this.targetValue),
      matchMode: matchMode ?? this.matchMode,
    );
  }
}
