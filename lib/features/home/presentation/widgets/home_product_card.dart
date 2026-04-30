import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';

import '../../../../core/router/product_details_payload.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_radius.dart';
import '../../../../core/utils/navigation_guard.dart';
import '../../../../core/utils/price_formatter.dart';
import '../../../../core/widgets/app_image_placeholder.dart';
import '../../../catalog/domain/entities/catalog_item_entity.dart';
import '../../../favorites/presentation/widgets/favorite_button.dart';

/// Home-only premium product card.
///
/// Single clean white surface — no inner panel, no outline. The product
/// sits on the same surface as the text; depth comes from a soft shadow
/// and proportion, not from framing. Intentionally not shared with
/// Catalog "similar products" — `HomeHorizontalItemCard` remains the
/// shared variant for the rest of the app.
class HomeProductCard extends StatelessWidget {
  final CatalogItemEntity item;
  final String? heroTag;

  const HomeProductCard({super.key, required this.item, this.heroTag});

  static const double cardWidth = 156;
  static const double cardHeight = 236;
  static const double _imageAreaHeight = 138;

  static const _shadow = <BoxShadow>[
    BoxShadow(
      color: Color(0x0C000000),
      blurRadius: 24,
      spreadRadius: -6,
      offset: Offset(0, 8),
    ),
  ];

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: cardWidth,
      height: cardHeight,
      child: DecoratedBox(
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(AppRadius.lg),
          boxShadow: _shadow,
        ),
        child: Material(
          color: Colors.transparent,
          child: InkWell(
            onTap: () => NavigationGuard.pushCatalogDetailsOnce(
              context,
              ProductDetailsPayload(item: item, heroTag: heroTag),
            ),
            borderRadius: BorderRadius.circular(AppRadius.lg),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _ImageArea(item: item, heroTag: heroTag),
                Expanded(
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(13, 4, 13, 14),
                    child: _TextBlock(item: item),
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

// ---------------------------------------------------------------------------
// Image area — sits on the same white surface as the text. No tinted panel,
// no inner border. Favorite icon floats discreetly in the top-right.
// ---------------------------------------------------------------------------

class _ImageArea extends StatelessWidget {
  final CatalogItemEntity item;
  final String? heroTag;

  const _ImageArea({required this.item, this.heroTag});

  @override
  Widget build(BuildContext context) {
    final image = _buildImage();
    return SizedBox(
      width: HomeProductCard.cardWidth,
      height: HomeProductCard._imageAreaHeight,
      child: Stack(
        children: [
          Positioned.fill(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(12, 12, 12, 6),
              child: heroTag != null
                  ? Hero(key: ValueKey(heroTag!), tag: heroTag!, child: image)
                  : image,
            ),
          ),
          Positioned(
            top: 4,
            right: 4,
            child: FavoriteButton(id: item.id, iconSize: 14),
          ),
        ],
      ),
    );
  }

  Widget _buildImage() {
    final url = item.imageUrl;
    if (url != null && url.isNotEmpty) {
      return CachedNetworkImage(
        imageUrl: url,
        fit: BoxFit.contain,
        placeholder: (_, _) => const AppImagePlaceholder(
          width: HomeProductCard.cardWidth,
          height: HomeProductCard._imageAreaHeight,
        ),
        errorWidget: (_, _, _) => const AppImagePlaceholder(
          width: HomeProductCard.cardWidth,
          height: HomeProductCard._imageAreaHeight,
        ),
      );
    }
    return const AppImagePlaceholder(
      width: HomeProductCard.cardWidth,
      height: HomeProductCard._imageAreaHeight,
    );
  }
}

// ---------------------------------------------------------------------------
// Text block — brand eyebrow, title, price row
// ---------------------------------------------------------------------------

class _TextBlock extends StatelessWidget {
  final CatalogItemEntity item;

  const _TextBlock({required this.item});

  @override
  Widget build(BuildContext context) {
    final brand = item.brand;
    final hasBrand = brand != null && brand.isNotEmpty;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (hasBrand)
          Padding(
            padding: const EdgeInsets.only(bottom: 6),
            child: Text(
              brand.toUpperCase(),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                fontSize: 9,
                fontWeight: FontWeight.w500,
                color: AppColors.textTertiary.withValues(alpha: 0.85),
                letterSpacing: 1.6,
                height: 1.0,
              ),
            ),
          ),
        Text(
          item.title,
          maxLines: 2,
          overflow: TextOverflow.ellipsis,
          style: const TextStyle(
            fontSize: 12.5,
            fontWeight: FontWeight.w500,
            color: AppColors.textPrimary,
            height: 1.32,
            letterSpacing: -0.05,
          ),
        ),
        const Spacer(),
        _PriceRow(price: item.price, oldPrice: item.oldPrice),
      ],
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
            fontSize: 14.5,
            fontWeight: FontWeight.w700,
            color: AppColors.textPrimary,
            letterSpacing: -0.15,
            height: 1.1,
          ),
        ),
        if (showOld) ...[
          const SizedBox(width: 6),
          Flexible(
            child: Text(
              PriceFormatter.formatRub(oldPrice),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                fontSize: 10.5,
                fontWeight: FontWeight.w400,
                color: AppColors.priceOld.withValues(alpha: 0.85),
                decoration: TextDecoration.lineThrough,
                decorationColor: AppColors.priceOld.withValues(alpha: 0.7),
                height: 1.1,
              ),
            ),
          ),
        ],
      ],
    );
  }
}
