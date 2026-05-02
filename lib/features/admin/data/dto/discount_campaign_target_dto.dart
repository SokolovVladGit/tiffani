import '../../domain/entities/discount_campaign_target_entity.dart';

/// Tolerant parsing/serialization for `public.discount_campaign_targets`.
class DiscountCampaignTargetDto {
  static DiscountCampaignTargetEntity parse(Map<String, dynamic> row) {
    return DiscountCampaignTargetEntity(
      id: _asString(row['id']),
      campaignId: _asString(row['campaign_id']),
      targetType: DiscountTargetType.fromWire(_asString(row['target_type'])),
      targetValue: _asString(row['target_value']),
      matchMode:
          DiscountTargetMatchMode.fromWire(_asString(row['match_mode'])),
    );
  }

  /// Insert payload for a target row. `campaign_id` is required and is
  /// supplied separately so this DTO does not need to know about the
  /// surrounding campaign's id during in-memory editing.
  static Map<String, dynamic> toInsertMap({
    required String campaignId,
    required DiscountCampaignTargetEntity target,
  }) {
    final isAll = target.targetType == DiscountTargetType.all;
    final value = target.targetValue?.trim();
    return {
      'campaign_id': campaignId,
      'target_type': target.targetType.wireValue,
      // The DB constraint requires NULL for `all` and a value otherwise.
      'target_value': isAll ? null : (value?.isEmpty ?? true ? null : value),
      'match_mode': target.matchMode.wireValue,
    };
  }

  static String? _asString(Object? value) {
    if (value == null) return null;
    if (value is String) return value;
    return value.toString();
  }
}
