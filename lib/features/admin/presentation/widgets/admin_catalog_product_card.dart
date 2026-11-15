import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';

import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_radius.dart';
import '../../../../core/theme/app_spacing.dart';
import '../../../../core/widgets/app_image_placeholder.dart';
import '../../domain/entities/admin_catalog_product.dart';

class AdminCatalogProductCard extends StatelessWidget {
  final AdminCatalogProduct product;
  final bool isMutating;
  final bool isEditLoading;
  final ValueChanged<bool> onVisibilityChanged;
  final VoidCallback? onEdit;

  const AdminCatalogProductCard({
    super.key,
    required this.product,
    required this.isMutating,
    this.isEditLoading = false,
    required this.onVisibilityChanged,
    this.onEdit,
  });

  @override
  Widget build(BuildContext context) {
    final subtitle = _subtitleParts();
    final hiddenFromCatalog = !product.appIsVisible;
    final sourceInactive = !product.isActive;
    final showUid = product.tildaUid != null && product.tildaUid!.trim().isNotEmpty;

    return Opacity(
      opacity: sourceInactive ? 0.78 : 1,
      child: Container(
        padding: const EdgeInsets.all(AppSpacing.md),
        decoration: BoxDecoration(
          color: AppColors.surface.withValues(alpha: 0.92),
          borderRadius: BorderRadius.circular(AppRadius.lg),
          border: Border.all(
            color: AppColors.border.withValues(alpha: 0.45),
            width: 0.5,
          ),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _Thumbnail(photoUrl: product.photo),
                const SizedBox(width: AppSpacing.md),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        product.title,
                        style: const TextStyle(
                          fontSize: 15,
                          fontWeight: FontWeight.w700,
                          color: AppColors.textPrimary,
                          height: 1.3,
                        ),
                        softWrap: true,
                      ),
                      if (subtitle.isNotEmpty) ...[
                        const SizedBox(height: 4),
                        Text(
                          subtitle,
                          style: const TextStyle(
                            fontSize: 12,
                            color: AppColors.textSecondary,
                            height: 1.35,
                          ),
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ],
                      if (showUid) ...[
                        const SizedBox(height: 4),
                        Text(
                          'UID ${product.tildaUid}',
                          style: const TextStyle(
                            fontSize: 11,
                            color: AppColors.textTertiary,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ],
                      const SizedBox(height: AppSpacing.sm),
                      Wrap(
                        spacing: AppSpacing.xs,
                        runSpacing: AppSpacing.xs,
                        children: [
                          _CatalogBadge(
                            label: product.isTildaImported ? 'Tilda' : 'В приложении',
                            style: product.isTildaImported
                                ? _CatalogBadgeStyle.neutral
                                : _CatalogBadgeStyle.accent,
                          ),
                          if (sourceInactive)
                            const _CatalogBadge(
                              label: 'Неактивен',
                              style: _CatalogBadgeStyle.muted,
                            ),
                          if (hiddenFromCatalog)
                            const _CatalogBadge(
                              label: 'Скрыт',
                              style: _CatalogBadgeStyle.outline,
                            ),
                        ],
                      ),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: AppSpacing.md),
            Row(
              children: [
                Expanded(
                  child: _VisibilityControl(
                    visible: product.appIsVisible,
                    enabled: !isMutating,
                    onChanged: onVisibilityChanged,
                  ),
                ),
                if (!product.isTildaImported && onEdit != null) ...[
                  const SizedBox(width: AppSpacing.sm),
                  Semantics(
                    button: true,
                    label: 'Редактировать товар',
                    child: IconButton(
                      onPressed: isMutating || isEditLoading ? null : onEdit,
                      tooltip: 'Редактировать',
                      visualDensity: VisualDensity.compact,
                      style: IconButton.styleFrom(
                        foregroundColor: AppColors.textSecondary,
                        minimumSize: const Size(44, 44),
                        padding: const EdgeInsets.all(10),
                      ),
                      icon: isEditLoading
                          ? const SizedBox(
                              width: 20,
                              height: 20,
                              child: CircularProgressIndicator.adaptive(
                                strokeWidth: 2,
                              ),
                            )
                          : const Icon(Icons.edit_outlined, size: 20),
                    ),
                  ),
                ],
              ],
            ),
          ],
        ),
      ),
    );
  }

  String _subtitleParts() {
    final parts = <String>[];
    final brand = product.brand?.trim();
    final category = product.category?.trim();
    if (brand != null && brand.isNotEmpty) parts.add(brand);
    if (category != null && category.isNotEmpty) parts.add(category);
    return parts.join(' · ');
  }
}

class _VisibilityControl extends StatelessWidget {
  final bool visible;
  final bool enabled;
  final ValueChanged<bool> onChanged;

  const _VisibilityControl({
    required this.visible,
    required this.enabled,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(
        horizontal: AppSpacing.md,
        vertical: AppSpacing.xs,
      ),
      decoration: BoxDecoration(
        color: AppColors.surfaceDim.withValues(alpha: 0.65),
        borderRadius: BorderRadius.circular(AppRadius.md),
      ),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  visible ? 'В приложении' : 'Скрыт в каталоге',
                  style: const TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                    color: AppColors.textPrimary,
                  ),
                ),
                Text(
                  visible ? 'Виден покупателям' : 'Не показывается в каталоге',
                  style: const TextStyle(
                    fontSize: 11,
                    color: AppColors.textTertiary,
                    height: 1.3,
                  ),
                ),
              ],
            ),
          ),
          Semantics(
            label: visible ? 'Скрыть в каталоге' : 'Показать в каталоге',
            child: Switch.adaptive(
              value: visible,
              onChanged: enabled ? onChanged : null,
            ),
          ),
        ],
      ),
    );
  }
}

class _Thumbnail extends StatelessWidget {
  final String? photoUrl;
  const _Thumbnail({this.photoUrl});

  static const double _size = 64;

  @override
  Widget build(BuildContext context) {
    final url = photoUrl?.trim();
    return ClipRRect(
      borderRadius: BorderRadius.circular(AppRadius.md),
      child: SizedBox(
        width: _size,
        height: _size,
        child: DecoratedBox(
          decoration: BoxDecoration(
            color: AppColors.surfaceDim,
            border: Border.all(
              color: AppColors.border.withValues(alpha: 0.4),
              width: 0.5,
            ),
          ),
          child: url != null && url.isNotEmpty
              ? CachedNetworkImage(
                  imageUrl: url,
                  fit: BoxFit.cover,
                  placeholder: (_, _) => const AppImagePlaceholder(
                    width: _size,
                    height: _size,
                  ),
                  errorWidget: (_, _, _) => const AppImagePlaceholder(
                    width: _size,
                    height: _size,
                  ),
                )
              : const AppImagePlaceholder(width: _size, height: _size),
        ),
      ),
    );
  }
}

enum _CatalogBadgeStyle { neutral, accent, muted, outline }

class _CatalogBadge extends StatelessWidget {
  final String label;
  final _CatalogBadgeStyle style;

  const _CatalogBadge({
    required this.label,
    this.style = _CatalogBadgeStyle.neutral,
  });

  @override
  Widget build(BuildContext context) {
    final (Color bg, Color fg, Border? border) = switch (style) {
      _CatalogBadgeStyle.neutral => (
          AppColors.surfaceDim,
          AppColors.textSecondary,
          null,
        ),
      _CatalogBadgeStyle.accent => (
          AppColors.badgeSurface,
          AppColors.textPrimary,
          null,
        ),
      _CatalogBadgeStyle.muted => (
          AppColors.surfaceDim,
          AppColors.textTertiary,
          Border.all(color: AppColors.border, width: 0.5),
        ),
      _CatalogBadgeStyle.outline => (
          AppColors.surface,
          AppColors.textSecondary,
          Border.all(color: AppColors.border, width: 0.5),
        ),
    };

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(AppRadius.sm),
        border: border,
      ),
      child: Text(
        label,
        style: TextStyle(
          fontSize: 10,
          fontWeight: FontWeight.w600,
          letterSpacing: 0.2,
          color: fg,
        ),
      ),
    );
  }
}
