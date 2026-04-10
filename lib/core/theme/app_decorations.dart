import 'package:flutter/material.dart';

import 'app_colors.dart';
import 'app_radius.dart';
import 'app_shadows.dart';

/// Reusable surface decorations for cards and containers.
class AppDecorations {
  AppDecorations._();

  static const _borderWidth = 0.5;

  static BoxDecoration card({double radius = AppRadius.lg}) => BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(radius),
        border: Border.all(color: AppColors.border, width: _borderWidth),
      );

  /// Soft card with a hairline border for definition against gray backgrounds.
  static BoxDecoration cardSoft({double radius = AppRadius.lg}) =>
      BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(radius),
        border: Border.all(
          color: AppColors.border.withValues(alpha: 0.5),
          width: _borderWidth,
        ),
      );

  static BoxDecoration cardElevated({double radius = AppRadius.lg}) =>
      BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(radius),
        boxShadow: AppShadows.cardElevated,
      );

  static BoxDecoration skeleton({double radius = AppRadius.sm}) =>
      BoxDecoration(
        color: AppColors.skeleton,
        borderRadius: BorderRadius.circular(radius),
      );
}
