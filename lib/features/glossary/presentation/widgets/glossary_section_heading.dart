import 'package:flutter/material.dart';

import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_spacing.dart';
import '../../../../core/theme/app_text_styles.dart';

/// Shared "Глоссарий" heading used by Info and `/glossary`.
class GlossarySectionHeading extends StatelessWidget {
  final int count;
  final VoidCallback? onCollapse;

  const GlossarySectionHeading({
    super.key,
    required this.count,
    this.onCollapse,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(
        AppSpacing.lg,
        AppSpacing.xxxl,
        AppSpacing.lg,
        0,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 28,
            height: 1.5,
            decoration: BoxDecoration(
              color: AppColors.textPrimary.withValues(alpha: 0.28),
              borderRadius: BorderRadius.circular(1),
            ),
          ),
          const SizedBox(height: AppSpacing.md + 2),
          Row(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Expanded(
                child: Text(
                  'Глоссарий',
                  style: AppTextStyles.pageTitle.copyWith(
                    fontSize: 23,
                    letterSpacing: -0.35,
                    height: 1.05,
                  ),
                ),
              ),
              if (onCollapse != null) ...[
                const SizedBox(width: AppSpacing.sm),
                Padding(
                  padding: const EdgeInsets.only(bottom: 2),
                  child: _HeadingCollapse(onTap: onCollapse!),
                ),
              ],
              const SizedBox(width: AppSpacing.md),
              Padding(
                padding: const EdgeInsets.only(bottom: 3),
                child: Text(
                  '$count терминов',
                  style: TextStyle(
                    fontSize: 11.5,
                    fontWeight: FontWeight.w500,
                    color: AppColors.textTertiary.withValues(alpha: 0.85),
                    letterSpacing: 0.15,
                    height: 1.0,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: AppSpacing.xs + 2),
          Text(
            'Ингредиенты и термины',
            style: TextStyle(
              fontSize: 12.5,
              fontWeight: FontWeight.w500,
              color: AppColors.textSecondary.withValues(alpha: 0.72),
              height: 1.3,
              letterSpacing: 0.15,
            ),
          ),
        ],
      ),
    );
  }
}

class _HeadingCollapse extends StatelessWidget {
  final VoidCallback onTap;

  const _HeadingCollapse({required this.onTap});

  @override
  Widget build(BuildContext context) {
    final color = AppColors.textSecondary.withValues(alpha: 0.9);
    return InkWell(
      key: const Key('glossary-heading-collapse'),
      onTap: onTap,
      borderRadius: BorderRadius.circular(8),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 2, vertical: 2),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              'Свернуть',
              style: TextStyle(
                fontSize: 11.5,
                fontWeight: FontWeight.w600,
                color: color,
                letterSpacing: 0.2,
                height: 1.0,
              ),
            ),
            Icon(Icons.keyboard_arrow_up_rounded, size: 16, color: color),
          ],
        ),
      ),
    );
  }
}
