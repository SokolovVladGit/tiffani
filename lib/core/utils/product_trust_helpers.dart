import 'package:flutter/material.dart';

import '../theme/app_colors.dart';

class BadgeStyle {
  final Color foreground;
  final Color background;

  const BadgeStyle({required this.foreground, required this.background});
}

/// Returns mark-specific badge colors. Priority if choosing: sale > hit > new.
BadgeStyle badgeStyleForMark(String mark) {
  switch (mark.trim().toUpperCase()) {
    case 'SALE':
      return const BadgeStyle(
        foreground: Colors.white,
        background: AppColors.discount,
      );
    case 'HIT':
      return const BadgeStyle(
        foreground: AppColors.badge,
        background: AppColors.badgeSurface,
      );
    default:
      return const BadgeStyle(
        foreground: AppColors.textSecondary,
        background: AppColors.surfaceDim,
      );
  }
}

/// Resolves a single display mark when the badge field may contain
/// multiple comma-separated values. Returns null if no valid mark.
String? resolveDisplayMark(String? badge) {
  if (badge == null || badge.trim().isEmpty) return null;

  final marks = badge.split(',').map((m) => m.trim().toUpperCase()).toList();

  const priority = ['SALE', 'HIT', 'NEW'];
  for (final p in priority) {
    if (marks.contains(p)) return p;
  }
  return marks.first;
}

/// Returns availability label based on stock quantity.
///
/// - `quantity > 5` → "В наличии"
/// - `quantity 1..5` → "Мало на складе"
/// - `quantity == 0` → "Нет в наличии"
/// - `null` (no data) → "В наличии" default, with ~15% deterministic
///   "Мало на складе" based on item ID hash (details page only).
String availabilityText({
  required int? quantity,
  String? itemId,
  bool detailed = false,
}) {
  if (quantity != null) {
    if (quantity <= 0) return 'Нет в наличии';
    if (quantity <= 5) return 'Мало на складе';
    return 'В наличии';
  }

  if (detailed && itemId != null) {
    final hash = itemId.hashCode.abs();
    if (hash % 7 == 0) return 'Мало на складе';
  }

  return 'В наличии';
}

/// Color for availability text.
Color availabilityColor(String text) {
  if (text == 'Мало на складе') return AppColors.stockLimited;
  if (text == 'Нет в наличии') return AppColors.discount;
  return AppColors.stockAvailable;
}
