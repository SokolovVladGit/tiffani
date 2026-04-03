import 'package:flutter/material.dart';

import 'app_colors.dart';
import 'app_radius.dart';

/// Reusable surface decorations for cards and containers.
class AppDecorations {
  AppDecorations._();

  static const _borderWidth = 0.5;

  static BoxDecoration card({double radius = AppRadius.lg}) => BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(radius),
        border: Border.all(color: AppColors.border, width: _borderWidth),
      );

  static BoxDecoration cardSoft({double radius = AppRadius.lg}) =>
      BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(radius),
      );

  static BoxDecoration cardElevated({double radius = AppRadius.lg}) =>
      BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(radius),
        boxShadow: const [
          BoxShadow(
            color: Color(0x0D000000),
            blurRadius: 12,
            spreadRadius: 0,
            offset: Offset(0, 2),
          ),
          BoxShadow(
            color: Color(0x06000000),
            blurRadius: 3,
            offset: Offset(0, 1),
          ),
        ],
      );

  static BoxDecoration skeleton({double radius = AppRadius.sm}) =>
      BoxDecoration(
        color: AppColors.skeleton,
        borderRadius: BorderRadius.circular(radius),
      );
}
