import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_radius.dart';
import '../../../../core/theme/app_spacing.dart';
import '../../../../core/widgets/section_header.dart';
import '../cubit/home_articles_cubit.dart';
import '../cubit/home_articles_state.dart';
import 'recommendation_card.dart';

class HomeRecommendationsSection extends StatelessWidget {
  const HomeRecommendationsSection({super.key});

  @override
  Widget build(BuildContext context) {
    return BlocBuilder<HomeArticlesCubit, HomeArticlesState>(
      buildWhen: (prev, curr) => prev.status != curr.status,
      builder: (context, state) {
        return switch (state.status) {
          HomeArticlesStatus.initial ||
          HomeArticlesStatus.error =>
            const SizedBox.shrink(),
          HomeArticlesStatus.loading => const _Skeleton(),
          HomeArticlesStatus.loaded when state.articles.isEmpty =>
            const SizedBox.shrink(),
          HomeArticlesStatus.loaded => _Content(state: state),
        };
      },
    );
  }
}

class _Content extends StatelessWidget {
  final HomeArticlesState state;

  const _Content({required this.state});

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const SectionHeader(title: 'Рекомендации'),
        SizedBox(
          height: 210,
          child: ListView.separated(
            scrollDirection: Axis.horizontal,
            padding: const EdgeInsets.symmetric(horizontal: AppSpacing.lg),
            itemCount: state.articles.length,
            separatorBuilder: (_, __) =>
                const SizedBox(width: AppSpacing.md),
            itemBuilder: (_, index) => RecommendationCard(
              article: state.articles[index],
            ),
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
            AppSpacing.lg,
            AppSpacing.xxl,
            AppSpacing.lg,
            AppSpacing.md,
          ),
          child: Container(
            width: 130,
            height: 18,
            decoration: BoxDecoration(
              color: AppColors.skeleton,
              borderRadius: BorderRadius.circular(AppRadius.sm),
            ),
          ),
        ),
        SizedBox(
          height: 210,
          child: ListView.separated(
            scrollDirection: Axis.horizontal,
            physics: const NeverScrollableScrollPhysics(),
            padding: const EdgeInsets.symmetric(horizontal: AppSpacing.lg),
            itemCount: 3,
            separatorBuilder: (_, __) =>
                const SizedBox(width: AppSpacing.md),
            itemBuilder: (_, __) => Container(
              width: RecommendationCard.cardWidth,
              decoration: BoxDecoration(
                color: AppColors.skeleton,
                borderRadius: BorderRadius.circular(AppRadius.lg),
              ),
            ),
          ),
        ),
      ],
    );
  }
}
