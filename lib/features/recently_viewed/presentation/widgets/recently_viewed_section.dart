import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../../core/di/injector.dart';
import '../../../../core/utils/product_hero_tag.dart';
import '../../../../core/widgets/section_header.dart';
import '../../../catalog/domain/entities/catalog_item_entity.dart';
import '../../../home/presentation/home_metrics.dart';
import '../../../home/presentation/home_strings.dart';
import '../../../home/presentation/widgets/home_product_card.dart';
import '../cubit/recently_viewed_cubit.dart';
import '../cubit/recently_viewed_state.dart';

/// Inter-card gap matches Home product shelves.
const double _kHomeShelfGap = 14;

class RecentlyViewedSection extends StatelessWidget {
  const RecentlyViewedSection({super.key});

  static const _maxDisplay = 10;

  @override
  Widget build(BuildContext context) {
    return BlocBuilder<RecentlyViewedCubit, RecentlyViewedState>(
      bloc: sl<RecentlyViewedCubit>(),
      builder: (context, state) {
        if (!state.hasItems) return const SizedBox.shrink();

        // Cap, then dedupe by id. Recently viewed mutates while a PDP is
        // open (the just-viewed item gets prepended), so a duplicated
        // entry sneaking in would mount two Heroes with the same tag on
        // the same route — the canonical Hero divert assertion trigger.
        final capped = state.items.length > _maxDisplay
            ? state.items.sublist(0, _maxDisplay)
            : state.items;
        final seen = <String>{};
        final displayItems = [
          for (final item in capped)
            if (seen.add(item.id)) item,
        ];

        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const SectionHeader(
              title: HomeStrings.recentlyViewed,
              padding: EdgeInsets.fromLTRB(
                HomeMetrics.pageEdge,
                HomeMetrics.sectionTop,
                HomeMetrics.pageEdge,
                HomeMetrics.sectionHeaderBottom,
              ),
            ),
            SizedBox(
              height: HomeProductCard.cardHeight,
              child: ListView.separated(
                scrollDirection: Axis.horizontal,
                padding: const EdgeInsets.symmetric(
                  horizontal: HomeMetrics.pageEdge,
                ),
                itemCount: displayItems.length,
                separatorBuilder: (_, _) =>
                    const SizedBox(width: _kHomeShelfGap),
                itemBuilder: (_, index) {
                  final item = displayItems[index];
                  final entity = CatalogItemEntity(
                    id: item.id,
                    productId: item.id,
                    title: item.title,
                    isActive: true,
                    imageUrl: item.imageUrl,
                    price: item.price,
                    oldPrice: item.oldPrice,
                    brand: item.brand,
                  );
                  final tag = ProductHeroTag.home('recent', item.id);
                  return HomeProductCard(
                    key: ValueKey(tag),
                    item: entity,
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
