import 'package:flutter/material.dart';

import '../../../../core/utils/product_hero_tag.dart';
import '../../../../core/widgets/section_header.dart';
import '../../../catalog/domain/entities/catalog_item_entity.dart';
import '../home_metrics.dart';
import 'home_product_card.dart';

const double _kHomeShelfGap = 14;

class HomeSection extends StatelessWidget {
  final String title;

  /// Stable internal section key used to build deterministic Hero tags
  /// (e.g. `'new'`, `'hits'`, `'sale'`). MUST NOT be a localized display
  /// title — see [ProductHeroTag].
  final String sectionKey;

  final List<CatalogItemEntity> items;
  final String? actionText;
  final VoidCallback? onAction;
  final EdgeInsetsGeometry? headerPadding;
  final bool isFirst;

  const HomeSection({
    super.key,
    required this.title,
    required this.sectionKey,
    required this.items,
    this.actionText,
    this.onAction,
    this.headerPadding,
    this.isFirst = false,
  });

  @override
  Widget build(BuildContext context) {
    if (items.isEmpty) return const SizedBox.shrink();

    // Deduplicate by product id. Two cards on the same route sharing a
    // Hero tag is the textbook trigger for the divert assertion in
    // `_HeroFlight._handleAnimationUpdate`. Backend duplicates within a
    // single shelf must never reach the Hero layer.
    final dedupedItems = _dedupeById(items);

    final resolvedHeaderPadding =
        headerPadding ??
        EdgeInsets.fromLTRB(
          HomeMetrics.pageEdge,
          isFirst ? HomeMetrics.firstSectionTop : HomeMetrics.sectionTop,
          HomeMetrics.pageEdge,
          HomeMetrics.sectionHeaderBottom,
        );

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SectionHeader(
          title: title,
          actionText: actionText,
          onAction: onAction,
          padding: resolvedHeaderPadding,
        ),
        SizedBox(
          height: HomeProductCard.cardHeight,
          child: ListView.separated(
            scrollDirection: Axis.horizontal,
            padding: const EdgeInsets.symmetric(
              horizontal: HomeMetrics.pageEdge,
            ),
            itemCount: dedupedItems.length,
            separatorBuilder: (_, _) => const SizedBox(width: _kHomeShelfGap),
            itemBuilder: (_, index) {
              final item = dedupedItems[index];
              final tag = ProductHeroTag.home(sectionKey, item.id);
              return HomeProductCard(
                key: ValueKey(tag),
                item: item,
                heroTag: tag,
              );
            },
          ),
        ),
      ],
    );
  }

  static List<CatalogItemEntity> _dedupeById(List<CatalogItemEntity> items) {
    final seen = <String>{};
    final out = <CatalogItemEntity>[];
    for (final item in items) {
      if (seen.add(item.id)) out.add(item);
    }
    return out;
  }
}
