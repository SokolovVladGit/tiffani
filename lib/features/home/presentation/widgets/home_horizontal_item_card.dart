import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/router/route_names.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/utils/price_formatter.dart';
import '../../../catalog/domain/entities/catalog_item_entity.dart';
import '../../../favorites/presentation/widgets/favorite_button.dart';

class HomeHorizontalItemCard extends StatelessWidget {
  final CatalogItemEntity item;

  const HomeHorizontalItemCard({super.key, required this.item});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: () => context.push(RouteNames.catalogDetails, extra: item),
      child: Container(
        width: 140,
        decoration: BoxDecoration(
          color: AppColors.surface,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: AppColors.border, width: 0.5),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Stack(
              children: [
                _ImageBox(imageUrl: item.imageUrl),
                Positioned(
                  top: 4,
                  right: 4,
                  child: FavoriteButton(id: item.id, iconSize: 16),
                ),
              ],
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(8, 6, 8, 8),
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
                    const SizedBox(height: 2),
                    Text(
                      item.brand!,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        fontSize: 11,
                        color: AppColors.textSecondary,
                      ),
                    ),
                  ],
                  const SizedBox(height: 4),
                  _PriceRow(price: item.price, oldPrice: item.oldPrice),
                ],
              ),
            ),
          ],
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
      borderRadius: const BorderRadius.vertical(top: Radius.circular(12)),
      child: (url != null && url.isNotEmpty)
          ? CachedNetworkImage(
              imageUrl: url,
              width: 140,
              height: 120,
              fit: BoxFit.contain,
              placeholder: (_, _) => _placeholder(),
              errorWidget: (_, _, _) => _placeholder(),
            )
          : _placeholder(),
    );
  }

  Widget _placeholder() {
    return Container(
      width: 140,
      height: 120,
      color: AppColors.surfaceDim,
      child: const Icon(
        Icons.image_outlined,
        size: 28,
        color: AppColors.textTertiary,
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
            fontSize: 13,
            fontWeight: FontWeight.w700,
            color: AppColors.textPrimary,
          ),
        ),
        if (showOld) ...[
          const SizedBox(width: 4),
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
