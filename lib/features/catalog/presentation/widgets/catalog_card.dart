import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../../core/di/injector.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_decorations.dart';
import '../../../../core/theme/app_radius.dart';
import '../../../../core/theme/app_spacing.dart';
import '../../../../core/utils/price_formatter.dart';
import '../../../../core/utils/product_trust_helpers.dart';
import '../../../../core/widgets/app_image_placeholder.dart';
import '../../../cart/domain/entities/cart_item_from_catalog.dart';
import '../../../cart/presentation/cubit/cart_cubit.dart';
import '../../../cart/presentation/cubit/cart_state.dart';
import '../../../favorites/presentation/widgets/favorite_button.dart';
import '../../domain/entities/catalog_item_entity.dart';

class CatalogCard extends StatelessWidget {
  final CatalogItemEntity item;
  final VoidCallback? onTap;
  final String? heroTag;

  const CatalogCard({
    super.key,
    required this.item,
    this.onTap,
    this.heroTag,
  });

  static const double _imageSize = 108;

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.symmetric(
        horizontal: AppSpacing.lg,
        vertical: 5,
      ),
      decoration: AppDecorations.cardSoft(),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(AppRadius.lg),
          child: Padding(
            padding: const EdgeInsets.all(AppSpacing.md),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                SizedBox(
                  width: _imageSize,
                  height: _imageSize,
                  child: Stack(
                    children: [
                      if (heroTag != null)
                        Hero(
                          tag: heroTag!,
                          child: _ImageBox(imageUrl: item.imageUrl),
                        )
                      else
                        _ImageBox(imageUrl: item.imageUrl),
                      Positioned(
                        top: 0,
                        right: 0,
                        child: FavoriteButton(id: item.id, iconSize: 18),
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: AppSpacing.lg),
                Expanded(child: _InfoColumn(item: item)),
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
    const size = CatalogCard._imageSize;
    const radius = BorderRadius.all(Radius.circular(AppRadius.md));
    final url = imageUrl;

    if (url != null && url.isNotEmpty) {
      return ClipRRect(
        borderRadius: radius,
        child: CachedNetworkImage(
          imageUrl: url,
          width: size,
          height: size,
          fit: BoxFit.contain,
          placeholder: (_, _) => const AppImagePlaceholder(
            width: size,
            height: size,
            borderRadius: radius,
          ),
          errorWidget: (_, _, _) => const AppImagePlaceholder(
            width: size,
            height: size,
            borderRadius: radius,
          ),
        ),
      );
    }
    return const AppImagePlaceholder(
      width: size,
      height: size,
      borderRadius: radius,
    );
  }
}

class _InfoColumn extends StatelessWidget {
  final CatalogItemEntity item;

  const _InfoColumn({required this.item});

  @override
  Widget build(BuildContext context) {
    final mark = resolveDisplayMark(item.badge);
    final stock = availabilityText(quantity: item.quantity);
    final stockColor = availabilityColor(stock);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (mark != null) ...[
          _Badge(mark: mark),
          const SizedBox(height: AppSpacing.xs),
        ],
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
        const SizedBox(height: 2),
        _MetaLine(
          brand: item.brand,
          stock: stock,
          stockColor: stockColor,
        ),
        const SizedBox(height: AppSpacing.sm),
        Row(
          children: [
            Expanded(
              child: _PriceRow(price: item.price, oldPrice: item.oldPrice),
            ),
            _CartControls(item: item),
          ],
        ),
      ],
    );
  }
}

class _MetaLine extends StatelessWidget {
  final String? brand;
  final String stock;
  final Color stockColor;

  const _MetaLine({
    this.brand,
    required this.stock,
    required this.stockColor,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        if (brand != null && brand!.isNotEmpty) ...[
          Flexible(
            child: Text(
              brand!,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(
                fontSize: 11,
                color: AppColors.textSecondary,
              ),
            ),
          ),
          const Text(
            ' · ',
            style: TextStyle(
              fontSize: 11,
              color: AppColors.textTertiary,
            ),
          ),
        ],
        Text(
          stock,
          style: TextStyle(fontSize: 10, color: stockColor),
        ),
      ],
    );
  }
}

class _Badge extends StatelessWidget {
  final String mark;

  const _Badge({required this.mark});

  @override
  Widget build(BuildContext context) {
    final style = badgeStyleForMark(mark);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
      decoration: BoxDecoration(
        color: style.background,
        borderRadius: BorderRadius.circular(AppRadius.xs),
      ),
      child: Text(
        mark.toUpperCase(),
        style: TextStyle(
          fontSize: 10,
          fontWeight: FontWeight.w700,
          color: style.foreground,
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
            fontSize: 16,
            fontWeight: FontWeight.w700,
            color: AppColors.textPrimary,
          ),
        ),
        if (showOld) ...[
          const SizedBox(width: AppSpacing.sm),
          Text(
            PriceFormatter.formatRub(oldPrice),
            style: const TextStyle(
              fontSize: 12,
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

/// Per-item cart controls using BlocSelector for isolated rebuilds.
class _CartControls extends StatelessWidget {
  final CatalogItemEntity item;

  const _CartControls({required this.item});

  @override
  Widget build(BuildContext context) {
    final cubit = sl<CartCubit>();
    return BlocProvider.value(
      value: cubit,
      child: BlocSelector<CartCubit, CartState, int>(
        selector: (state) => state.quantityOf(item.id),
        builder: (context, quantity) {
          if (quantity == 0) {
            return _AddButton(
              onTap: () => cubit.addItem(cartItemFromCatalog(item)),
            );
          }
          return _QuantityChip(
            quantity: quantity,
            onIncrement: () => cubit.incrementQuantity(item.id),
            onDecrement: () => cubit.decrementQuantity(item.id),
          );
        },
      ),
    );
  }
}

class _AddButton extends StatefulWidget {
  final VoidCallback onTap;

  const _AddButton({required this.onTap});

  @override
  State<_AddButton> createState() => _AddButtonState();
}

class _AddButtonState extends State<_AddButton>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;
  late final Animation<double> _scale;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 150),
    );
    _scale = TweenSequence<double>([
      TweenSequenceItem(tween: Tween(begin: 1.0, end: 0.8), weight: 40),
      TweenSequenceItem(tween: Tween(begin: 0.8, end: 1.0), weight: 60),
    ]).animate(_controller);
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _onTap() {
    HapticFeedback.lightImpact();
    _controller.forward(from: 0);
    widget.onTap();
  }

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: _onTap,
      behavior: HitTestBehavior.opaque,
      child: AnimatedBuilder(
        animation: _scale,
        builder: (context, child) => Transform.scale(
          scale: _scale.value,
          child: child,
        ),
        child: Container(
          padding: const EdgeInsets.all(6),
          decoration: BoxDecoration(
            color: AppColors.seed.withValues(alpha: 0.1),
            borderRadius: BorderRadius.circular(AppRadius.sm),
          ),
          child: Icon(Icons.add_shopping_cart, size: 18, color: AppColors.seed),
        ),
      ),
    );
  }
}

class _QuantityChip extends StatelessWidget {
  final int quantity;
  final VoidCallback onIncrement;
  final VoidCallback onDecrement;

  const _QuantityChip({
    required this.quantity,
    required this.onIncrement,
    required this.onDecrement,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: AppColors.seed.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(AppRadius.sm),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          _chipButton(Icons.remove, onDecrement),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 6),
            child: Text(
              '$quantity',
              style: const TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w600,
                color: AppColors.seed,
              ),
            ),
          ),
          _chipButton(Icons.add, onIncrement),
        ],
      ),
    );
  }

  Widget _chipButton(IconData icon, VoidCallback onTap) {
    return InkWell(
      onTap: () {
        HapticFeedback.selectionClick();
        onTap();
      },
      borderRadius: BorderRadius.circular(AppRadius.sm),
      child: Padding(
        padding: const EdgeInsets.all(6),
        child: Icon(icon, size: 16, color: AppColors.seed),
      ),
    );
  }
}
