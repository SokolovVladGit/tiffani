import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/router/product_details_payload.dart';
import '../../../../core/router/route_names.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_decorations.dart';
import '../../../../core/theme/app_radius.dart';
import '../../../../core/theme/app_spacing.dart';
import '../../../../core/utils/price_formatter.dart';
import '../../../../core/widgets/app_image_placeholder.dart';
import '../../../catalog/domain/entities/catalog_item_entity.dart';
import '../../../favorites/presentation/widgets/favorite_button.dart';

class HomeHorizontalItemCard extends StatelessWidget {
  final CatalogItemEntity item;
  final String? heroTag;

  const HomeHorizontalItemCard({super.key, required this.item, this.heroTag});

  static const double cardWidth = 152;
  static const double _imageHeight = 130;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: cardWidth,
      decoration: AppDecorations.cardSoft(radius: AppRadius.lg),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: () => context.push(
            RouteNames.catalogDetails,
            extra: ProductDetailsPayload(item: item, heroTag: heroTag),
          ),
          borderRadius: BorderRadius.circular(AppRadius.lg),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Stack(
                children: [
                  if (heroTag != null)
                    Hero(
                      tag: heroTag!,
                      child: _ImageBox(imageUrl: item.imageUrl),
                    )
                  else
                    _ImageBox(imageUrl: item.imageUrl),
                  Positioned(
                    top: AppSpacing.xs,
                    right: AppSpacing.xs,
                    child: FavoriteButton(id: item.id, iconSize: 16),
                  ),
                ],
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
              width: HomeHorizontalItemCard.cardWidth,
              height: HomeHorizontalItemCard._imageHeight,
              fit: BoxFit.contain,
              placeholder: (_, _) => const AppImagePlaceholder(
                width: HomeHorizontalItemCard.cardWidth,
                height: HomeHorizontalItemCard._imageHeight,
              ),
              errorWidget: (_, _, _) => const AppImagePlaceholder(
                width: HomeHorizontalItemCard.cardWidth,
                height: HomeHorizontalItemCard._imageHeight,
              ),
            )
          : const AppImagePlaceholder(
              width: HomeHorizontalItemCard.cardWidth,
              height: HomeHorizontalItemCard._imageHeight,
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
