import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';

import '../../../../core/di/injector.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/utils/price_formatter.dart';
import '../../../cart/domain/entities/cart_item_from_catalog.dart';
import '../../../cart/presentation/cubit/cart_cubit.dart';
import '../../../favorites/presentation/widgets/favorite_button.dart';
import '../../domain/entities/catalog_item_entity.dart';

class CatalogDetailsPage extends StatelessWidget {
  final CatalogItemEntity item;

  const CatalogDetailsPage({super.key, required this.item});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(item.title, maxLines: 1),
        actions: [FavoriteButton(id: item.id)],
      ),
      body: SingleChildScrollView(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _ImageSection(imageUrl: item.imageUrl),
            _ContentSection(item: item),
          ],
        ),
      ),
      bottomNavigationBar: _AddToCartBar(item: item),
    );
  }
}

class _AddToCartBar extends StatelessWidget {
  final CatalogItemEntity item;

  const _AddToCartBar({required this.item});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: EdgeInsets.fromLTRB(
        20,
        12,
        20,
        12 + MediaQuery.of(context).padding.bottom,
      ),
      decoration: const BoxDecoration(
        color: AppColors.surface,
        border: Border(top: BorderSide(color: AppColors.border, width: 0.5)),
      ),
      child: SizedBox(
        width: double.infinity,
        child: ElevatedButton.icon(
          onPressed: () {
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
          icon: const Icon(Icons.add_shopping_cart, size: 18),
          label: const Text('Add to cart'),
        ),
      ),
    );
  }
}

class _ImageSection extends StatelessWidget {
  final String? imageUrl;

  const _ImageSection({this.imageUrl});

  @override
  Widget build(BuildContext context) {
    final url = imageUrl;
    if (url != null && url.isNotEmpty) {
      return CachedNetworkImage(
        imageUrl: url,
        width: double.infinity,
        height: 340,
        fit: BoxFit.contain,
        placeholder: (_, _) => _placeholder(),
        errorWidget: (_, _, _) => _placeholder(),
      );
    }
    return _placeholder();
  }

  Widget _placeholder() {
    return Container(
      width: double.infinity,
      height: 340,
      color: AppColors.surfaceDim,
      child: const Icon(
        Icons.image_outlined,
        size: 48,
        color: AppColors.textTertiary,
      ),
    );
  }
}

class _ContentSection extends StatelessWidget {
  final CatalogItemEntity item;

  const _ContentSection({required this.item});

  @override
  Widget build(BuildContext context) {
    final badgeText = item.badge?.trim();
    final hasBadge = badgeText != null && badgeText.isNotEmpty;

    return Container(
      width: double.infinity,
      decoration: const BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      padding: const EdgeInsets.fromLTRB(20, 20, 20, 40),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (hasBadge) ...[
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
              decoration: BoxDecoration(
                color: AppColors.badgeSurface,
                borderRadius: BorderRadius.circular(6),
              ),
              child: Text(
                badgeText.toUpperCase(),
                style: const TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.w700,
                  color: AppColors.badge,
                  letterSpacing: 0.5,
                ),
              ),
            ),
            const SizedBox(height: 10),
          ],
          Text(
            item.title,
            style: const TextStyle(
              fontSize: 20,
              fontWeight: FontWeight.w700,
              color: AppColors.textPrimary,
              height: 1.25,
            ),
          ),
          if (item.brand != null) ...[
            const SizedBox(height: 4),
            Text(
              item.brand!,
              style: const TextStyle(
                fontSize: 14,
                color: AppColors.textSecondary,
              ),
            ),
          ],
          const SizedBox(height: 14),
          _buildPrice(),
          if (item.edition != null || item.modification != null) ...[
            const SizedBox(height: 16),
            _buildChips(),
          ],
          if (item.shortDescription != null &&
              item.shortDescription!.trim().isNotEmpty) ...[
            const SizedBox(height: 20),
            const _SectionTitle(text: 'Description'),
            const SizedBox(height: 6),
            Text(
              item.shortDescription!,
              style: const TextStyle(
                fontSize: 14,
                color: AppColors.textPrimary,
                height: 1.5,
              ),
            ),
          ],
          if (item.fullDescription != null &&
              item.fullDescription!.trim().isNotEmpty) ...[
            const SizedBox(height: 20),
            const _SectionTitle(text: 'Details'),
            const SizedBox(height: 6),
            Text(
              item.fullDescription!,
              style: const TextStyle(
                fontSize: 14,
                color: AppColors.textPrimary,
                height: 1.5,
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildPrice() {
    final formatted = PriceFormatter.formatRub(item.price);
    if (formatted.isEmpty) return const SizedBox.shrink();

    final showOld =
        item.oldPrice != null &&
        item.price != null &&
        item.oldPrice! > item.price!;

    return Row(
      crossAxisAlignment: CrossAxisAlignment.baseline,
      textBaseline: TextBaseline.alphabetic,
      children: [
        Text(
          formatted,
          style: const TextStyle(
            fontSize: 24,
            fontWeight: FontWeight.w800,
            color: AppColors.textPrimary,
          ),
        ),
        if (showOld) ...[
          const SizedBox(width: 8),
          Text(
            PriceFormatter.formatRub(item.oldPrice),
            style: const TextStyle(
              fontSize: 16,
              color: AppColors.priceOld,
              decoration: TextDecoration.lineThrough,
              decorationColor: AppColors.priceOld,
            ),
          ),
        ],
      ],
    );
  }

  Widget _buildChips() {
    return Wrap(
      spacing: 8,
      runSpacing: 6,
      children: [
        if (item.edition != null && item.edition!.isNotEmpty)
          _InfoChip(label: item.edition!),
        if (item.modification != null && item.modification!.isNotEmpty)
          _InfoChip(label: item.modification!),
      ],
    );
  }
}

class _SectionTitle extends StatelessWidget {
  final String text;

  const _SectionTitle({required this.text});

  @override
  Widget build(BuildContext context) {
    return Text(
      text,
      style: const TextStyle(
        fontSize: 15,
        fontWeight: FontWeight.w600,
        color: AppColors.textPrimary,
      ),
    );
  }
}

class _InfoChip extends StatelessWidget {
  final String label;

  const _InfoChip({required this.label});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
      decoration: BoxDecoration(
        color: AppColors.surfaceDim,
        borderRadius: BorderRadius.circular(8),
      ),
      child: Text(
        label,
        style: const TextStyle(fontSize: 12, color: AppColors.textSecondary),
      ),
    );
  }
}
