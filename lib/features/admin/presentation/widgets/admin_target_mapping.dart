import '../../domain/entities/discount_campaign_target_entity.dart';

/// Enum of client-facing target shapes exposed by the admin discount UI.
///
/// Technical target types (`mark`, `product_tilda_uid`, `variant_id`) and
/// non-exact match modes (`prefix`, `contains`) are intentionally excluded
/// — they remain supported by the backend for legacy rows, but are never
/// produced by the friendly editor.
enum FriendlyTargetKind {
  all,
  category,
  brand,
  product,
}

/// Builds a `Все товары` target row: `all` + `exact`, no value.
DiscountCampaignTargetEntity buildAllTarget() {
  return const DiscountCampaignTargetEntity(
    targetType: DiscountTargetType.all,
    matchMode: DiscountTargetMatchMode.exact,
  );
}

/// Builds a category target row with case-preserved target value.
/// Empty/whitespace-only values return an empty placeholder row so the
/// caller's validation (`hasValidValue`) rejects them before save.
DiscountCampaignTargetEntity buildCategoryTarget(String category) {
  final trimmed = category.trim();
  return DiscountCampaignTargetEntity(
    targetType: DiscountTargetType.category,
    matchMode: DiscountTargetMatchMode.exact,
    targetValue: trimmed.isEmpty ? null : trimmed,
  );
}

/// Builds a brand target row (same semantics as [buildCategoryTarget]).
DiscountCampaignTargetEntity buildBrandTarget(String brand) {
  final trimmed = brand.trim();
  return DiscountCampaignTargetEntity(
    targetType: DiscountTargetType.brand,
    matchMode: DiscountTargetMatchMode.exact,
    targetValue: trimmed.isEmpty ? null : trimmed,
  );
}

/// Builds a product target row addressed by `product_id` (stable UUID
/// from `catalog_items.product_id`). Single-product discounts cover every
/// variant of that product.
DiscountCampaignTargetEntity buildProductTarget(String productId) {
  final trimmed = productId.trim();
  return DiscountCampaignTargetEntity(
    targetType: DiscountTargetType.productId,
    matchMode: DiscountTargetMatchMode.exact,
    targetValue: trimmed.isEmpty ? null : trimmed,
  );
}

/// Whether [target] fits the friendly editor contract: `exact` match plus
/// one of (all | category | brand | product_id) with a non-empty value
/// when required.
bool isFriendlyTarget(DiscountCampaignTargetEntity target) {
  if (target.matchMode != DiscountTargetMatchMode.exact) return false;
  switch (target.targetType) {
    case DiscountTargetType.all:
      return true;
    case DiscountTargetType.category:
    case DiscountTargetType.brand:
    case DiscountTargetType.productId:
      final v = target.targetValue?.trim();
      return v != null && v.isNotEmpty;
    case DiscountTargetType.mark:
    case DiscountTargetType.productTildaUid:
    case DiscountTargetType.variantId:
      return false;
  }
}

/// Inverse of [isFriendlyTarget]. Legacy rows and any
/// `prefix`/`contains` match modes count as advanced.
bool isAdvancedTarget(DiscountCampaignTargetEntity target) {
  return !isFriendlyTarget(target);
}

/// Maps a friendly target to its [FriendlyTargetKind], or `null` when
/// [target] is advanced/legacy.
FriendlyTargetKind? friendlyKindOf(DiscountCampaignTargetEntity target) {
  if (!isFriendlyTarget(target)) return null;
  switch (target.targetType) {
    case DiscountTargetType.all:
      return FriendlyTargetKind.all;
    case DiscountTargetType.category:
      return FriendlyTargetKind.category;
    case DiscountTargetType.brand:
      return FriendlyTargetKind.brand;
    case DiscountTargetType.productId:
      return FriendlyTargetKind.product;
    case DiscountTargetType.mark:
    case DiscountTargetType.productTildaUid:
    case DiscountTargetType.variantId:
      return null;
  }
}

/// Short Russian label for the friendly target type (or advanced fallback).
String friendlyTargetTypeLabel(DiscountCampaignTargetEntity target) {
  final kind = friendlyKindOf(target);
  switch (kind) {
    case FriendlyTargetKind.all:
      return 'Все товары';
    case FriendlyTargetKind.category:
      return 'Категория';
    case FriendlyTargetKind.brand:
      return 'Бренд';
    case FriendlyTargetKind.product:
      return 'Товар';
    case null:
      return 'Расширенное условие';
  }
}

/// One-line humanized summary for advanced/legacy rows. Avoids exposing
/// raw UUIDs where reasonable but keeps the value readable so the owner
/// can decide whether to delete the row.
String advancedTargetSummary(DiscountCampaignTargetEntity target) {
  final typeLabel = _advancedTypeLabel(target.targetType);
  final modeLabel = _advancedMatchModeLabel(target.matchMode);
  final rawValue = (target.targetValue ?? '').trim();
  final valueLabel = rawValue.isEmpty ? '—' : rawValue;
  if (target.targetType == DiscountTargetType.all) {
    return typeLabel;
  }
  return '$typeLabel · $modeLabel · $valueLabel';
}

String _advancedTypeLabel(DiscountTargetType type) {
  switch (type) {
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
      return 'ID товара';
    case DiscountTargetType.variantId:
      return 'ID варианта';
  }
}

String _advancedMatchModeLabel(DiscountTargetMatchMode mode) {
  switch (mode) {
    case DiscountTargetMatchMode.exact:
      return 'точное';
    case DiscountTargetMatchMode.prefix:
      return 'начинается с';
    case DiscountTargetMatchMode.contains:
      return 'содержит';
  }
}

/// Whether the list already contains at least one `Все товары` row.
bool hasAllTarget(List<DiscountCampaignTargetEntity> targets) {
  return targets.any((t) => t.targetType == DiscountTargetType.all);
}

/// Deduplicates identical rows (same type, trimmed value, match mode).
/// Preserves original order. Does not alter advanced rows relative to
/// each other beyond removing exact duplicates.
List<DiscountCampaignTargetEntity> dedupeTargets(
  List<DiscountCampaignTargetEntity> targets,
) {
  final seen = <String>{};
  final result = <DiscountCampaignTargetEntity>[];
  for (final t in targets) {
    final key =
        '${t.targetType.wireValue}|${(t.targetValue ?? '').trim().toLowerCase()}|${t.matchMode.wireValue}';
    if (seen.add(key)) {
      result.add(t);
    }
  }
  return result;
}

/// Enforces `Все товары` mutual exclusivity.
///
/// - If the list contains any `all` row, collapses to a single canonical
///   `all` row (all other rows dropped).
/// - Otherwise returns [dedupeTargets] over the input.
List<DiscountCampaignTargetEntity> normalizeTargets(
  List<DiscountCampaignTargetEntity> targets,
) {
  if (targets.isEmpty) return const [];
  if (hasAllTarget(targets)) {
    return [buildAllTarget()];
  }
  return dedupeTargets(targets);
}
