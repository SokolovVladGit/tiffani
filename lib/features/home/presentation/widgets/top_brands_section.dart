import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/router/route_names.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_radius.dart';
import '../../../../core/widgets/section_header.dart';
import '../cubit/top_brands_cubit.dart';
import '../home_metrics.dart';
import '../home_strings.dart';
import 'top_brand_card.dart';

class TopBrandsSection extends StatelessWidget {
  const TopBrandsSection({super.key});

  @override
  Widget build(BuildContext context) {
    return BlocBuilder<TopBrandsCubit, TopBrandsState>(
      builder: (context, state) {
        final Widget child;
        if (state.isLoading) {
          child = const _Skeleton();
        } else if (state.brands.isEmpty) {
          child = const SizedBox.shrink();
        } else {
          child = _Content(brands: state.brands);
        }
        return AnimatedSwitcher(
          duration: const Duration(milliseconds: 200),
          child: child,
        );
      },
    );
  }
}

class _Content extends StatelessWidget {
  final List<String> brands;

  const _Content({required this.brands});

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SectionHeader(
          title: HomeStrings.brandsSection,
          actionText: HomeStrings.seeAll,
          onAction: () => context.push(RouteNames.brands),
          padding: const EdgeInsets.fromLTRB(
            HomeMetrics.pageEdge,
            HomeMetrics.sectionTop,
            HomeMetrics.pageEdge,
            HomeMetrics.sectionHeaderBottom,
          ),
        ),
        SizedBox(
          height: 108,
          child: ListView.separated(
            scrollDirection: Axis.horizontal,
            padding: const EdgeInsets.symmetric(
              horizontal: HomeMetrics.pageEdge,
            ),
            itemCount: brands.length,
            separatorBuilder: (_, _) => const SizedBox(width: 14),
            itemBuilder: (context, index) {
              final brand = brands[index];
              return TopBrandCard(
                name: brand,
                index: index,
                onTap: () =>
                    context.push(RouteNames.brandCatalog, extra: brand),
              );
            },
          ),
        ),
      ],
    );
  }
}

class _Skeleton extends StatelessWidget {
  const _Skeleton();

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(
            HomeMetrics.pageEdge,
            HomeMetrics.sectionTop,
            HomeMetrics.pageEdge,
            HomeMetrics.sectionHeaderBottom,
          ),
          child: Container(
            width: 120,
            height: 18,
            decoration: BoxDecoration(
              color: AppColors.skeleton,
              borderRadius: BorderRadius.circular(AppRadius.sm),
            ),
          ),
        ),
        SizedBox(
          height: 108,
          child: ListView.separated(
            scrollDirection: Axis.horizontal,
            physics: const NeverScrollableScrollPhysics(),
            padding: const EdgeInsets.symmetric(
              horizontal: HomeMetrics.pageEdge,
            ),
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
        ),
      ],
    );
  }
}
