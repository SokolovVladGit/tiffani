import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';

import '../../../../core/di/injector.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/utils/price_formatter.dart';
import '../../../cart/domain/entities/cart_item_from_catalog.dart';
import '../../../cart/presentation/cubit/cart_cubit.dart';
import '../../../favorites/presentation/widgets/favorite_button.dart';
import '../../domain/entities/catalog_item_entity.dart';

class CatalogCard extends StatelessWidget {
  final CatalogItemEntity item;
  final VoidCallback? onTap;

  const CatalogCard({super.key, required this.item, this.onTap});

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 5),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: AppColors.border, width: 0.5),
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(14),
          child: Padding(
            padding: const EdgeInsets.all(10),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                SizedBox(
                  width: 96,
                  height: 96,
                  child: Stack(
                    children: [
                      _ImageBox(imageUrl: item.imageUrl),
                      Positioned(
                        top: 0,
                        right: 0,
                        child: FavoriteButton(id: item.id, iconSize: 18),
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: _InfoColumn(
                    item: item,
                    onAddToCart: () {
                      sl<CartCubit>().addItem(cartItemFromCatalog(item));
                      ScaffoldMessenger.of(context)
                        ..hideCurrentSnackBar()
                        ..showSnackBar(
                          const SnackBar(
                            content: Text('Added to cart'),
                            duration: Duration(seconds: 1),
                          ),
                        );
                    },
                  ),
                ),
              ],
            ),
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
    const size = 96.0;
    const radius = BorderRadius.all(Radius.circular(10));
    final url = imageUrl;

    if (url != null && url.isNotEmpty) {
      return ClipRRect(
        borderRadius: radius,
        child: CachedNetworkImage(
          imageUrl: url,
          width: size,
          height: size,
          fit: BoxFit.contain,
          placeholder: (_, _) => _placeholder(size),
          errorWidget: (_, _, _) => _placeholder(size),
        ),
      );
    }
    return _placeholder(size);
  }

  Widget _placeholder(double size) {
    return Container(
      width: size,
      height: size,
      decoration: const BoxDecoration(
        color: AppColors.surfaceDim,
        borderRadius: BorderRadius.all(Radius.circular(10)),
      ),
      child: const Icon(
        Icons.image_outlined,
        color: AppColors.textTertiary,
        size: 28,
      ),
    );
  }
}

class _InfoColumn extends StatelessWidget {
  final CatalogItemEntity item;
  final VoidCallback onAddToCart;

  const _InfoColumn({required this.item, required this.onAddToCart});

  @override
  Widget build(BuildContext context) {
    final badgeText = item.badge?.trim();
    final hasBadge = badgeText != null && badgeText.isNotEmpty;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (hasBadge) ...[_Badge(text: badgeText), const SizedBox(height: 4)],
        Text(
          item.title,
          maxLines: 2,
          overflow: TextOverflow.ellipsis,
          style: const TextStyle(
            fontSize: 14,
            fontWeight: FontWeight.w600,
            color: AppColors.textPrimary,
            height: 1.3,
          ),
        ),
        if (item.brand != null) ...[
          const SizedBox(height: 2),
          Text(
            item.brand!,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(
              fontSize: 12,
              color: AppColors.textSecondary,
            ),
          ),
        ],
        if (_hasSubline) ...[
          const SizedBox(height: 2),
          Text(
            _subline,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(fontSize: 11, color: AppColors.textTertiary),
          ),
        ],
        const SizedBox(height: 6),
        Row(
          children: [
            Expanded(
              child: _PriceRow(price: item.price, oldPrice: item.oldPrice),
            ),
            _AddButton(onTap: onAddToCart),
          ],
        ),
      ],
    );
  }

  bool get _hasSubline =>
      (item.edition?.isNotEmpty ?? false) ||
      (item.modification?.isNotEmpty ?? false);

  String get _subline {
    final parts = <String>[
      if (item.edition?.isNotEmpty ?? false) item.edition!,
      if (item.modification?.isNotEmpty ?? false) item.modification!,
    ];
    return parts.join(' · ');
  }
}

class _Badge extends StatelessWidget {
  final String text;

  const _Badge({required this.text});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
      decoration: BoxDecoration(
        color: AppColors.badgeSurface,
        borderRadius: BorderRadius.circular(4),
      ),
      child: Text(
        text.toUpperCase(),
        style: const TextStyle(
          fontSize: 10,
          fontWeight: FontWeight.w700,
          color: AppColors.badge,
          letterSpacing: 0.5,
        ),
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

    final showOld = oldPrice != null && price != null && oldPrice! > price!;

    return Row(
      crossAxisAlignment: CrossAxisAlignment.baseline,
      textBaseline: TextBaseline.alphabetic,
      children: [
        Text(
          formatted,
          style: const TextStyle(
            fontSize: 15,
            fontWeight: FontWeight.w700,
            color: AppColors.textPrimary,
          ),
        ),
        if (showOld) ...[
          const SizedBox(width: 6),
          Text(
            PriceFormatter.formatRub(oldPrice),
            style: const TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w400,
              color: AppColors.priceOld,
              decoration: TextDecoration.lineThrough,
              decorationColor: AppColors.priceOld,
            ),
          ),
        ],
      ],
    );
  }
}

class _AddButton extends StatelessWidget {
  final VoidCallback onTap;

  const _AddButton({required this.onTap});

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(8),
      child: Container(
        padding: const EdgeInsets.all(6),
        decoration: BoxDecoration(
          color: AppColors.seed.withValues(alpha: 0.1),
          borderRadius: BorderRadius.circular(8),
        ),
        child: Icon(Icons.add_shopping_cart, size: 18, color: AppColors.seed),
      ),
    );
  }
}
