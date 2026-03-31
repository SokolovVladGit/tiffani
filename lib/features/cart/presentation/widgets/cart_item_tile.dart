import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_decorations.dart';
import '../../../../core/theme/app_radius.dart';
import '../../../../core/theme/app_spacing.dart';
import '../../../../core/utils/price_formatter.dart';
import '../../../../core/widgets/app_image_placeholder.dart';
import '../../domain/entities/cart_item_entity.dart';

class CartItemTile extends StatelessWidget {
  final CartItemEntity item;
  final VoidCallback onIncrement;
  final VoidCallback onDecrement;
  final VoidCallback onRemove;

  const CartItemTile({
    super.key,
    required this.item,
    required this.onIncrement,
    required this.onDecrement,
    required this.onRemove,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.symmetric(
        horizontal: AppSpacing.lg,
        vertical: AppSpacing.xs,
      ),
      decoration: AppDecorations.cardSoft(),
      padding: const EdgeInsets.all(AppSpacing.md),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildImage(),
          const SizedBox(width: AppSpacing.md),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
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
                    style: const TextStyle(
                      fontSize: 11,
                      color: AppColors.textTertiary,
                    ),
                  ),
                ],
                const SizedBox(height: AppSpacing.sm),
                Row(
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          if (item.quantity > 1 && item.price != null)
                            Text(
                              '${PriceFormatter.formatRub(item.price)} × ${item.quantity}',
                              style: const TextStyle(
                                fontSize: 12,
                                color: AppColors.textSecondary,
                              ),
                            ),
                          Text(
                            PriceFormatter.formatRub(_subtotal),
                            style: const TextStyle(
                              fontSize: 15,
                              fontWeight: FontWeight.w700,
                              color: AppColors.textPrimary,
                            ),
                          ),
                        ],
                      ),
                    ),
                    _QuantityControls(
                      quantity: item.quantity,
                      onIncrement: onIncrement,
                      onDecrement: onDecrement,
                    ),
                    const SizedBox(width: AppSpacing.sm),
                    _RemoveButton(onRemove: onRemove),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildImage() {
    const size = 72.0;
    final radius = BorderRadius.circular(AppRadius.md);
    final url = item.imageUrl;
    if (url != null && url.isNotEmpty) {
      return ClipRRect(
        borderRadius: radius,
        child: CachedNetworkImage(
          imageUrl: url,
          width: size,
          height: size,
          fit: BoxFit.contain,
          placeholder: (_, _) => AppImagePlaceholder(
            width: size,
            height: size,
            iconSize: 24,
            borderRadius: radius,
          ),
          errorWidget: (_, _, _) => AppImagePlaceholder(
            width: size,
            height: size,
            iconSize: 24,
            borderRadius: radius,
          ),
        ),
      );
    }
    return AppImagePlaceholder(
      width: size,
      height: size,
      iconSize: 24,
      borderRadius: radius,
    );
  }

  double? get _subtotal =>
      item.price != null ? item.price! * item.quantity : item.price;

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

class _QuantityControls extends StatelessWidget {
  final int quantity;
  final VoidCallback onIncrement;
  final VoidCallback onDecrement;

  const _QuantityControls({
    required this.quantity,
    required this.onIncrement,
    required this.onDecrement,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: AppColors.surfaceDim,
        borderRadius: BorderRadius.circular(AppRadius.sm),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          _button(Icons.remove, onDecrement),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 10),
            child: Text(
              '$quantity',
              style: const TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w600,
                color: AppColors.textPrimary,
              ),
            ),
          ),
          _button(Icons.add, onIncrement),
        ],
      ),
    );
  }

  Widget _button(IconData icon, VoidCallback onTap) {
    return InkWell(
      onTap: () {
        HapticFeedback.selectionClick();
        onTap();
      },
      borderRadius: BorderRadius.circular(AppRadius.sm),
      child: Padding(
        padding: const EdgeInsets.all(6),
        child: Icon(icon, size: 16, color: AppColors.textSecondary),
      ),
    );
  }
}

class _RemoveButton extends StatelessWidget {
  final VoidCallback onRemove;

  const _RemoveButton({required this.onRemove});

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onRemove,
      borderRadius: BorderRadius.circular(AppRadius.sm),
      child: const Padding(
        padding: EdgeInsets.all(6),
        child: Icon(
          Icons.delete_outline,
          size: 18,
          color: AppColors.textTertiary,
        ),
      ),
    );
  }
}
