import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../../core/di/injector.dart';
import '../../../../core/router/product_details_payload.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_decorations.dart';
import '../../../../core/theme/app_radius.dart';
import '../../../../core/theme/app_spacing.dart';
import '../../../../core/utils/navigation_guard.dart';
import '../../../../core/utils/price_formatter.dart';
import '../../../../core/widgets/app_image_placeholder.dart';
import '../../../../core/widgets/section_header.dart';
import '../../../catalog/domain/entities/catalog_item_entity.dart';
import '../../domain/entities/recently_viewed_item.dart';
import '../cubit/recently_viewed_cubit.dart';
import '../cubit/recently_viewed_state.dart';

class RecentlyViewedSection extends StatelessWidget {
  const RecentlyViewedSection({super.key});

  static const _maxDisplay = 10;
  static const double _cardWidth = 152;
  static const double _imageHeight = 130;

  @override
  Widget build(BuildContext context) {
    return BlocBuilder<RecentlyViewedCubit, RecentlyViewedState>(
      bloc: sl<RecentlyViewedCubit>(),
      builder: (context, state) {
        if (!state.hasItems) return const SizedBox.shrink();

        final displayItems = state.items.length > _maxDisplay
            ? state.items.sublist(0, _maxDisplay)
            : state.items;

        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const SectionHeader(title: 'Недавно просмотренные'),
            SizedBox(
              height: 228,
              child: ListView.separated(
                scrollDirection: Axis.horizontal,
                padding:
                    const EdgeInsets.symmetric(horizontal: AppSpacing.lg),
                itemCount: displayItems.length,
                separatorBuilder: (_, _) =>
                    const SizedBox(width: AppSpacing.md),
                itemBuilder: (_, index) => _RecentlyViewedCard(
                  item: displayItems[index],
                  heroTag: 'recent-${displayItems[index].id}',
                ),
              ),
            ),
          ],
        );
      },
    );
  }
}

class _RecentlyViewedCard extends StatelessWidget {
  final RecentlyViewedItem item;
  final String heroTag;

  const _RecentlyViewedCard({required this.item, required this.heroTag});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: RecentlyViewedSection._cardWidth,
      decoration: AppDecorations.cardSoft(radius: AppRadius.lg),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: () {
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
            NavigationGuard.pushCatalogDetailsOnce(
              context,
              ProductDetailsPayload(item: entity, heroTag: heroTag),
            );
          },
          borderRadius: BorderRadius.circular(AppRadius.lg),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Hero(
                tag: heroTag,
                child: _ImageBox(imageUrl: item.imageUrl),
              ),
              Padding(
                padding: const EdgeInsets.fromLTRB(10, AppSpacing.sm, 10, 11),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      item.title,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                        color: AppColors.textPrimary,
                        height: 1.3,
                      ),
                    ),
                    if (item.brand != null && item.brand!.isNotEmpty) ...[
                      const SizedBox(height: 4),
                      Text(
                        item.brand!,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          fontSize: 11,
                          color: AppColors.textTertiary,
                        ),
                      ),
                    ],
                    const SizedBox(height: 5),
                    _PriceRow(price: item.price, oldPrice: item.oldPrice),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _ImageBox extends StatelessWidget {
  final String? imageUrl;

  const _ImageBox({this.imageUrl});

  @override
  Widget build(BuildContext context) {
    final url = imageUrl;
    return ClipRRect(
      borderRadius: const BorderRadius.vertical(
        top: Radius.circular(AppRadius.lg),
      ),
      child: (url != null && url.isNotEmpty)
          ? CachedNetworkImage(
              imageUrl: url,
              width: RecentlyViewedSection._cardWidth,
              height: RecentlyViewedSection._imageHeight,
              fit: BoxFit.contain,
              placeholder: (_, _) => const AppImagePlaceholder(
                width: RecentlyViewedSection._cardWidth,
                height: RecentlyViewedSection._imageHeight,
              ),
              errorWidget: (_, _, _) => const AppImagePlaceholder(
                width: RecentlyViewedSection._cardWidth,
                height: RecentlyViewedSection._imageHeight,
              ),
            )
          : const AppImagePlaceholder(
              width: RecentlyViewedSection._cardWidth,
              height: RecentlyViewedSection._imageHeight,
            ),
    );
  }
}

class _PriceRow extends StatelessWidget {
  final double? price;
  final double? oldPrice;

  const _PriceRow({this.price, this.oldPrice});

  @override
  Widget build(BuildContext context) {
    final formatted = PriceFormatter.formatRub(price);
    if (formatted.isEmpty) return const SizedBox.shrink();

    final showOld =
        oldPrice != null && price != null && oldPrice! > price!;

    return Row(
      children: [
        Text(
          formatted,
          style: const TextStyle(
            fontSize: 14,
            fontWeight: FontWeight.w700,
            color: AppColors.textPrimary,
          ),
        ),
        if (showOld) ...[
          const SizedBox(width: AppSpacing.xs),
          Flexible(
            child: Text(
              PriceFormatter.formatRub(oldPrice),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(
                fontSize: 11,
                color: AppColors.priceOld,
                decoration: TextDecoration.lineThrough,
                decorationColor: AppColors.priceOld,
              ),
            ),
          ),
        ],
      ],
    );
  }
}
