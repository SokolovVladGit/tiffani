import 'package:flutter/material.dart';

import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_decorations.dart';
import '../../../../core/theme/app_radius.dart';
import '../home_metrics.dart';
import 'home_product_card.dart';
import 'top_brand_card.dart';

/// Skeleton for the below-hero content area during initial load.
///
/// Mirrors the canonical Home rhythm: 3 product sections → brands.
class HomeContentSkeleton extends StatelessWidget {
  const HomeContentSkeleton({super.key});

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _buildSectionHeaderBar(top: HomeMetrics.firstSectionTop),
        _buildProductStrip(),
        _buildSectionHeaderBar(top: HomeMetrics.sectionTop),
        _buildProductStrip(),
        _buildSectionHeaderBar(top: HomeMetrics.sectionTop),
        _buildProductStrip(),
        _buildSectionHeaderBar(top: HomeMetrics.sectionTop),
        _buildBrandStrip(),
      ],
    );
  }

  Widget _buildSectionHeaderBar({required double top}) {
    return Padding(
      padding: EdgeInsets.fromLTRB(
        HomeMetrics.pageEdge,
        top,
        HomeMetrics.pageEdge,
        HomeMetrics.sectionHeaderBottom,
      ),
      child: Container(
        width: 96,
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
        padding: const EdgeInsets.symmetric(horizontal: HomeMetrics.pageEdge),
        itemCount: 4,
        separatorBuilder: (_, _) => const SizedBox(width: 14),
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
      height: HomeProductCard.cardHeight,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        physics: const NeverScrollableScrollPhysics(),
        padding: const EdgeInsets.symmetric(horizontal: HomeMetrics.pageEdge),
        itemCount: 3,
        separatorBuilder: (_, _) => const SizedBox(width: 14),
        itemBuilder: (_, _) => Container(
          width: HomeProductCard.cardWidth,
          decoration: BoxDecoration(
            color: AppColors.skeleton,
            borderRadius: BorderRadius.circular(AppRadius.lg),
          ),
        ),
      ),
    );
  }
}
