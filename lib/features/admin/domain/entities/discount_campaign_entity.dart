import 'discount_campaign_target_entity.dart';

/// Editable representation of a row in `public.discount_campaigns`.
///
/// `id` is `null` for a newly-created campaign that has not been persisted
/// yet. `usedCount` is read-only — populated from the backend, never sent
/// back on upsert. `targets` is loaded from `public.discount_campaign_targets`
/// for `automatic` campaigns and is empty for `promocode` campaigns
/// (where promocode itself is the only "target").
enum DiscountCampaignKind {
  automatic('automatic'),
  promocode('promocode');

  final String wireValue;
  const DiscountCampaignKind(this.wireValue);

  static DiscountCampaignKind fromWire(String? value) {
    return value == 'promocode' ? promocode : automatic;
  }
}

class DiscountCampaignEntity {
  final String? id;
  final DiscountCampaignKind kind;
  final String name;
  final String? code;
  final String? description;
  final double percentOff;
  final double minOrderAmount;
  final DateTime? startsAt;
  final DateTime? endsAt;
  final int? maxRedemptions;
  final int usedCount;
  final bool isActive;
  final List<DiscountCampaignTargetEntity> targets;

  const DiscountCampaignEntity({
    this.id,
    required this.kind,
    required this.name,
    this.code,
    this.description,
    required this.percentOff,
    this.minOrderAmount = 0,
    this.startsAt,
    this.endsAt,
    this.maxRedemptions,
    this.usedCount = 0,
    this.isActive = true,
    this.targets = const [],
  });

  bool get isPersisted => id != null;
  bool get isPromocode => kind == DiscountCampaignKind.promocode;
  bool get isAutomatic => kind == DiscountCampaignKind.automatic;

  DiscountCampaignEntity copyWith({
    String? id,
    DiscountCampaignKind? kind,
    String? name,
    String? code,
    String? description,
    double? percentOff,
    double? minOrderAmount,
    DateTime? startsAt,
    DateTime? endsAt,
    int? maxRedemptions,
    int? usedCount,
    bool? isActive,
    List<DiscountCampaignTargetEntity>? targets,
    bool clearCode = false,
    bool clearDescription = false,
    bool clearStartsAt = false,
    bool clearEndsAt = false,
    bool clearMaxRedemptions = false,
  }) {
    return DiscountCampaignEntity(
      id: id ?? this.id,
      kind: kind ?? this.kind,
      name: name ?? this.name,
      code: clearCode ? null : (code ?? this.code),
      description: clearDescription ? null : (description ?? this.description),
      percentOff: percentOff ?? this.percentOff,
      minOrderAmount: minOrderAmount ?? this.minOrderAmount,
      startsAt: clearStartsAt ? null : (startsAt ?? this.startsAt),
      endsAt: clearEndsAt ? null : (endsAt ?? this.endsAt),
      maxRedemptions:
          clearMaxRedemptions ? null : (maxRedemptions ?? this.maxRedemptions),
      usedCount: usedCount ?? this.usedCount,
      isActive: isActive ?? this.isActive,
      targets: targets ?? this.targets,
    );
  }
}
