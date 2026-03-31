import 'package:flutter/material.dart';

import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_decorations.dart';
import '../../../../core/theme/app_radius.dart';
import '../../../../core/theme/app_spacing.dart';
import 'home_horizontal_item_card.dart';
import 'top_brand_card.dart';

/// Skeleton for the below-hero content area during initial load.
class HomeContentSkeleton extends StatelessWidget {
  const HomeContentSkeleton({super.key});

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _buildTabsSkeleton(),
        const SizedBox(height: AppSpacing.lg),
        _buildProductStrip(),
        const SizedBox(height: AppSpacing.xxl),
        _buildSectionHeaderBar(width: 120),
        const SizedBox(height: AppSpacing.md),
        _buildBrandStrip(),
        const SizedBox(height: AppSpacing.xxl),
        _buildSectionHeaderBar(width: 140),
        const SizedBox(height: AppSpacing.md),
        _buildProductStrip(),
      ],
    );
  }

  Widget _buildTabsSkeleton() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(
        AppSpacing.lg,
        AppSpacing.xxl,
        AppSpacing.lg,
        0,
      ),
      child: Container(
        height: 40,
        decoration: BoxDecoration(
          color: AppColors.skeleton,
          borderRadius: BorderRadius.circular(12),
        ),
      ),
    );
  }

  Widget _buildSectionHeaderBar({required double width}) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: AppSpacing.lg),
      child: Container(
        width: width,
        height: 18,
        decoration: AppDecorations.skeleton(),
      ),
    );
  }

  Widget _buildBrandStrip() {
    return SizedBox(
      height: 108,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        physics: const NeverScrollableScrollPhysics(),
        padding: const EdgeInsets.symmetric(horizontal: AppSpacing.lg),
        itemCount: 4,
        separatorBuilder: (_, _) => const SizedBox(width: AppSpacing.md),
        itemBuilder: (_, _) => Container(
          width: TopBrandCard.cardWidth,
          decoration: BoxDecoration(
            color: AppColors.skeleton,
            borderRadius: BorderRadius.circular(AppRadius.xl),
          ),
        ),
      ),
    );
  }

  Widget _buildProductStrip() {
    return SizedBox(
      height: 228,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        physics: const NeverScrollableScrollPhysics(),
        padding: const EdgeInsets.symmetric(horizontal: AppSpacing.lg),
        itemCount: 3,
        separatorBuilder: (_, _) => const SizedBox(width: AppSpacing.md),
        itemBuilder: (_, _) => Container(
          width: HomeHorizontalItemCard.cardWidth,
          decoration: BoxDecoration(
            color: AppColors.skeleton,
            borderRadius: BorderRadius.circular(AppRadius.lg),
          ),
        ),
      ),
    );
  }
}
