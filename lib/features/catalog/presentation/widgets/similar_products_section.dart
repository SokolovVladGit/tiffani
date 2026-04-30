import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_radius.dart';
import '../../../../core/theme/app_spacing.dart';
import '../../../../core/utils/product_hero_tag.dart';
import '../../../../core/widgets/section_header.dart';
import '../../domain/entities/catalog_item_entity.dart';
import '../../../home/presentation/widgets/home_horizontal_item_card.dart';
import '../cubit/similar_products_cubit.dart';
import '../cubit/similar_products_state.dart';

class SimilarProductsSection extends StatelessWidget {
  const SimilarProductsSection({super.key});

  static List<CatalogItemEntity> _dedupeById(List<CatalogItemEntity> items) {
    final seen = <String>{};
    final out = <CatalogItemEntity>[];
    for (final item in items) {
      if (seen.add(item.id)) out.add(item);
    }
    return out;
  }

  @override
  Widget build(BuildContext context) {
    return BlocBuilder<SimilarProductsCubit, SimilarProductsState>(
      builder: (context, state) {
        if (state.status == SimilarProductsStatus.loading) {
          return const _Skeleton();
        }
        if (state.status != SimilarProductsStatus.success || !state.hasItems) {
          return const SizedBox.shrink();
        }
        final items = _dedupeById(state.items);
        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const SectionHeader(
              title: 'Похожие товары',
              padding: EdgeInsets.fromLTRB(
                AppSpacing.xl,
                AppSpacing.xxl,
                AppSpacing.xl,
                AppSpacing.sm,
              ),
            ),
            SizedBox(
              height: 228,
              child: ListView.separated(
                scrollDirection: Axis.horizontal,
                padding: const EdgeInsets.symmetric(horizontal: AppSpacing.lg),
                itemCount: items.length,
                separatorBuilder: (_, _) =>
                    const SizedBox(width: AppSpacing.md),
                itemBuilder: (_, index) {
                  final item = items[index];
                  final tag = ProductHeroTag.similar(item.id);
                  return HomeHorizontalItemCard(
                    key: ValueKey(tag),
                    item: item,
                    heroTag: tag,
                  );
                },
              ),
            ),
          ],
        );
      },
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
            AppSpacing.xl,
            AppSpacing.xxl,
            AppSpacing.xl,
            AppSpacing.sm,
          ),
          child: Container(
            width: 140,
            height: 18,
            decoration: BoxDecoration(
              color: AppColors.skeleton,
              borderRadius: BorderRadius.circular(6),
            ),
          ),
        ),
        SizedBox(
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
        ),
      ],
    );
  }
}
