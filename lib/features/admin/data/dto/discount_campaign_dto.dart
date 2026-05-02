import '../../domain/entities/discount_campaign_entity.dart';
import '../../domain/entities/discount_campaign_target_entity.dart';

/// Tolerant parsing/serialization for `public.discount_campaigns`.
class DiscountCampaignDto {
  /// Builds an entity from a Supabase row. `targets` defaults to empty;
  /// callers can attach loaded targets afterward.
  static DiscountCampaignEntity parse(
    Map<String, dynamic> row, {
    List<DiscountCampaignTargetEntity> targets = const [],
  }) {
    return DiscountCampaignEntity(
      id: _asString(row['id']),
      kind: DiscountCampaignKind.fromWire(_asString(row['kind'])),
      name: _asString(row['name']) ?? '',
      code: _asString(row['code']),
      description: _asString(row['description']),
      percentOff: _asDouble(row['percent_off']) ?? 0,
      minOrderAmount: _asDouble(row['min_order_amount']) ?? 0,
      startsAt: _asDateTime(row['starts_at']),
      endsAt: _asDateTime(row['ends_at']),
      maxRedemptions: _asInt(row['max_redemptions']),
      usedCount: _asInt(row['used_count']) ?? 0,
      isActive: _asBool(row['is_active']) ?? true,
      targets: targets,
    );
  }

  /// Map suitable for `from('discount_campaigns').insert(...)` — leaves
  /// server defaults intact and never sends `id`/`used_count`.
  static Map<String, dynamic> toInsertMap(DiscountCampaignEntity c) {
    final base = _commonWritableMap(c);
    base['kind'] = c.kind.wireValue;
    return base;
  }

  /// Map suitable for `from('discount_campaigns').update(...)` — same
  /// fields as insert, except `kind` is intentionally omitted because
  /// changing campaign kind across promocode/automatic is not supported.
  static Map<String, dynamic> toUpdateMap(DiscountCampaignEntity c) {
    return _commonWritableMap(c);
  }

  static Map<String, dynamic> _commonWritableMap(DiscountCampaignEntity c) {
    final code = c.code?.trim().toUpperCase();
    final desc = c.description?.trim();
    return {
      'name': c.name.trim(),
      'code': (code == null || code.isEmpty) ? null : code,
      'description': (desc == null || desc.isEmpty) ? null : desc,
      'percent_off': c.percentOff,
      'min_order_amount': c.minOrderAmount,
      'starts_at': c.startsAt?.toUtc().toIso8601String(),
      'ends_at': c.endsAt?.toUtc().toIso8601String(),
      'max_redemptions': c.maxRedemptions,
      'is_active': c.isActive,
    };
  }

  static String? _asString(Object? value) {
    if (value == null) return null;
    if (value is String) return value;
    return value.toString();
  }

  static double? _asDouble(Object? value) {
    if (value == null) return null;
    if (value is num) return value.toDouble();
    if (value is String) return double.tryParse(value);
    return null;
  }

  static int? _asInt(Object? value) {
    if (value == null) return null;
    if (value is int) return value;
    if (value is num) return value.toInt();
    if (value is String) return int.tryParse(value);
    return null;
  }

  static bool? _asBool(Object? value) {
    if (value == null) return null;
    if (value is bool) return value;
    if (value is num) return value != 0;
    if (value is String) {
      final v = value.toLowerCase();
      if (v == 'true') return true;
      if (v == 'false') return false;
    }
    return null;
  }

  static DateTime? _asDateTime(Object? value) {
    if (value == null) return null;
    if (value is DateTime) return value;
    if (value is String && value.isNotEmpty) {
      return DateTime.tryParse(value);
    }
    return null;
  }
}
