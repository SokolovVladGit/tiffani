import 'dart:async';

import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';

import '../../../../core/di/injector.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_radius.dart';
import '../../../../core/theme/app_spacing.dart';
import '../../../catalog/domain/entities/catalog_item_entity.dart';
import '../../../catalog/domain/repositories/catalog_repository.dart';
import '../../../catalog/domain/usecases/get_all_brands_use_case.dart';
import '../../../catalog/domain/usecases/get_available_categories_use_case.dart';
import '../../domain/entities/discount_campaign_target_entity.dart';
import 'admin_target_mapping.dart';

/// Client-friendly editor for an automatic discount campaign's target
/// rows. Emits back a normalized `List<DiscountCampaignTargetEntity>`
/// whenever the owner adds/edits/removes a condition.
///
/// Only produces friendly rows (`all`, `category`, `brand`, `product_id`,
/// all with `exact` match mode). Legacy rows passed in via [targets] are
/// preserved verbatim and rendered as read-only "Расширенное условие"
/// tiles with a delete action.
class AdminTargetEditor extends StatefulWidget {
  final List<DiscountCampaignTargetEntity> targets;
  final ValueChanged<List<DiscountCampaignTargetEntity>> onChanged;

  const AdminTargetEditor({
    super.key,
    required this.targets,
    required this.onChanged,
  });

  @override
  State<AdminTargetEditor> createState() => _AdminTargetEditorState();
}

class _AdminTargetEditorState extends State<AdminTargetEditor> {
  /// Resolved product display cache keyed by product_id. `null` value
  /// means "looked up and not found"; absence means "not attempted yet".
  final Map<String, CatalogItemEntity?> _productCache = {};
  final Set<String> _productInFlight = {};

  @override
  void initState() {
    super.initState();
    _resolvePendingProducts();
  }

  @override
  void didUpdateWidget(covariant AdminTargetEditor oldWidget) {
    super.didUpdateWidget(oldWidget);
    _resolvePendingProducts();
  }

  void _resolvePendingProducts() {
    final repo = sl<CatalogRepository>();
    for (final t in widget.targets) {
      if (t.targetType != DiscountTargetType.productId) continue;
      if (t.matchMode != DiscountTargetMatchMode.exact) continue;
      final value = t.targetValue?.trim();
      if (value == null || value.isEmpty) continue;
      if (_productCache.containsKey(value)) continue;
      if (_productInFlight.contains(value)) continue;
      _productInFlight.add(value);
      repo.getCatalogItemByProductId(value).then((item) {
        if (!mounted) return;
        setState(() {
          _productCache[value] = item;
          _productInFlight.remove(value);
        });
      }).catchError((_) {
        if (!mounted) return;
        setState(() {
          _productCache[value] = null;
          _productInFlight.remove(value);
        });
      });
    }
  }

  void _emit(List<DiscountCampaignTargetEntity> next) {
    widget.onChanged(List.unmodifiable(next));
  }

  void _replaceAtFriendlyIndex(
    int friendlyIndex,
    DiscountCampaignTargetEntity replacement,
  ) {
    final next = <DiscountCampaignTargetEntity>[];
    var seenFriendly = -1;
    for (final t in widget.targets) {
      if (isFriendlyTarget(t)) {
        seenFriendly += 1;
        if (seenFriendly == friendlyIndex) {
          next.add(replacement);
          continue;
        }
      }
      next.add(t);
    }
    _emit(dedupeTargets(next));
  }

  void _removeTarget(DiscountCampaignTargetEntity target) {
    final next = List<DiscountCampaignTargetEntity>.from(widget.targets);
    next.remove(target);
    _emit(next);
  }

  void _addFriendly(DiscountCampaignTargetEntity added) {
    if (added.targetType == DiscountTargetType.all) {
      _setAllCatalogMode(true);
      return;
    }
    final next = widget.targets
        .where((t) => t.targetType != DiscountTargetType.all)
        .toList();
    next.add(added);
    _emit(dedupeTargets(next));
  }

  /// Toggles all-catalog mode.
  ///
  /// On enable: keeps any legacy advanced rows (mark / prefix / contains /
  /// product_tilda_uid / variant_id) in saved state and appends a single
  /// canonical `all` row. The engine treats `all` as an OR short-circuit,
  /// so legacy rows are semantically redundant but not destructively lost
  /// if the owner toggles back off.
  /// On disable: removes the `all` row; other targets remain as-is.
  void _setAllCatalogMode(bool enabled) {
    if (enabled) {
      final preserved = widget.targets
          .where((t) =>
              t.targetType != DiscountTargetType.all && isAdvancedTarget(t))
          .toList();
      preserved.add(buildAllTarget());
      _emit(dedupeTargets(preserved));
    } else {
      final next = widget.targets
          .where((t) => t.targetType != DiscountTargetType.all)
          .toList();
      _emit(dedupeTargets(next));
    }
  }

  Future<void> _onAddPressed() async {
    final kind = await showModalBottomSheet<FriendlyTargetKind>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      backgroundColor: AppColors.surface,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(AppRadius.xl)),
      ),
      builder: (_) => const _TargetTypePickerSheet(),
    );
    if (!mounted || kind == null) return;
    await _pickAndAdd(kind);
  }

  Future<void> _pickAndAdd(FriendlyTargetKind kind) async {
    switch (kind) {
      case FriendlyTargetKind.all:
        _setAllCatalogMode(true);
        break;
      case FriendlyTargetKind.category:
        final value = await _pickCategory(initial: null);
        if (value != null) _addFriendly(buildCategoryTarget(value));
        break;
      case FriendlyTargetKind.brand:
        final value = await _pickBrand(initial: null);
        if (value != null) _addFriendly(buildBrandTarget(value));
        break;
      case FriendlyTargetKind.product:
        final picked = await _pickProduct();
        if (picked != null) {
          _productCache[picked.productId] = picked;
          _addFriendly(buildProductTarget(picked.productId));
        }
        break;
    }
  }

  Future<void> _onEditFriendly(
    int friendlyIndex,
    DiscountCampaignTargetEntity target,
  ) async {
    final kind = friendlyKindOf(target);
    switch (kind) {
      case FriendlyTargetKind.all:
      case null:
        return;
      case FriendlyTargetKind.category:
        final value = await _pickCategory(initial: target.targetValue);
        if (value != null) {
          _replaceAtFriendlyIndex(friendlyIndex, buildCategoryTarget(value));
        }
        break;
      case FriendlyTargetKind.brand:
        final value = await _pickBrand(initial: target.targetValue);
        if (value != null) {
          _replaceAtFriendlyIndex(friendlyIndex, buildBrandTarget(value));
        }
        break;
      case FriendlyTargetKind.product:
        final picked = await _pickProduct();
        if (picked != null) {
          _productCache[picked.productId] = picked;
          _replaceAtFriendlyIndex(
            friendlyIndex,
            buildProductTarget(picked.productId),
          );
        }
        break;
    }
  }

  Future<String?> _pickCategory({required String? initial}) {
    return showModalBottomSheet<String>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      backgroundColor: AppColors.surface,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(AppRadius.xl)),
      ),
      builder: (_) => _CategoryPickerSheet(initial: initial),
    );
  }

  Future<String?> _pickBrand({required String? initial}) {
    return showModalBottomSheet<String>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      backgroundColor: AppColors.surface,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(AppRadius.xl)),
      ),
      builder: (_) => _BrandPickerSheet(initial: initial),
    );
  }

  Future<CatalogItemEntity?> _pickProduct() {
    return showModalBottomSheet<CatalogItemEntity>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      backgroundColor: AppColors.surface,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(AppRadius.xl)),
      ),
      builder: (_) => const _ProductPickerSheet(),
    );
  }

  @override
  Widget build(BuildContext context) {
    final targets = widget.targets;
    final isAllMode = hasAllTarget(targets);
    final visibleTargets = isAllMode
        ? const <DiscountCampaignTargetEntity>[]
        : targets
            .where((t) => t.targetType != DiscountTargetType.all)
            .toList(growable: false);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _AllCatalogToggle(
          selected: isAllMode,
          onTap: () => _setAllCatalogMode(!isAllMode),
        ),
        if (!isAllMode) ...[
          const SizedBox(height: AppSpacing.sm),
          if (visibleTargets.isEmpty) ...[
            const _EmptyConditionsHint(),
          ] else ...[
            const _OrSemanticsHint(),
            const SizedBox(height: AppSpacing.xs),
            for (var i = 0, fi = 0; i < visibleTargets.length; i++)
              Padding(
                padding: const EdgeInsets.only(bottom: AppSpacing.sm),
                child: _buildTile(
                  visibleTargets[i],
                  i,
                  isFriendlyTarget(visibleTargets[i]) ? fi++ : -1,
                ),
              ),
          ],
          const SizedBox(height: AppSpacing.xs),
          _AddConditionButton(onTap: _onAddPressed),
        ],
      ],
    );
  }

  Widget _buildTile(
    DiscountCampaignTargetEntity target,
    int indexInAll,
    int friendlyIndex,
  ) {
    if (!isFriendlyTarget(target)) {
      return _AdvancedTile(
        target: target,
        onRemove: () => _removeTarget(target),
      );
    }
    final kind = friendlyKindOf(target);
    switch (kind) {
      case FriendlyTargetKind.all:
        // All-catalog mode is handled by the top toggle card, not rendered
        // as a tile. This branch is unreachable in practice because
        // `visibleTargets` filters out `all` rows.
        return const SizedBox.shrink();
      case FriendlyTargetKind.category:
        return _FriendlyValueTile(
          icon: Icons.category_outlined,
          typeLabel: 'Категория',
          valueLabel: target.targetValue ?? '—',
          onEdit: () => _onEditFriendly(friendlyIndex, target),
          onRemove: () => _removeTarget(target),
        );
      case FriendlyTargetKind.brand:
        return _FriendlyValueTile(
          icon: Icons.local_offer_outlined,
          typeLabel: 'Бренд',
          valueLabel: target.targetValue ?? '—',
          onEdit: () => _onEditFriendly(friendlyIndex, target),
          onRemove: () => _removeTarget(target),
        );
      case FriendlyTargetKind.product:
        final productId = (target.targetValue ?? '').trim();
        final cached = _productCache[productId];
        final inFlight = _productInFlight.contains(productId);
        return _ProductTile(
          productId: productId,
          resolved: cached,
          isLoading: inFlight && cached == null,
          onEdit: () => _onEditFriendly(friendlyIndex, target),
          onRemove: () => _removeTarget(target),
        );
      case null:
        return _AdvancedTile(
          target: target,
          onRemove: () => _removeTarget(target),
        );
    }
  }
}

// ---------------------------------------------------------------------------
// Tiles
// ---------------------------------------------------------------------------

class _AddConditionButton extends StatelessWidget {
  final VoidCallback onTap;

  const _AddConditionButton({required this.onTap});

  @override
  Widget build(BuildContext context) {
    return OutlinedButton.icon(
      onPressed: onTap,
      icon: const Icon(Icons.add, size: 18),
      label: const Text('Добавить условие'),
      style: OutlinedButton.styleFrom(
        padding: const EdgeInsets.symmetric(vertical: AppSpacing.md),
        side: BorderSide(color: AppColors.border.withValues(alpha: 0.8)),
      ),
    );
  }
}

class _EmptyConditionsHint extends StatelessWidget {
  const _EmptyConditionsHint();

  @override
  Widget build(BuildContext context) {
    return const Padding(
      padding: EdgeInsets.symmetric(vertical: AppSpacing.xs),
      child: Text(
        'Добавьте категории, бренды или товары.',
        style: TextStyle(
          fontSize: 12,
          color: AppColors.textTertiary,
          height: 1.35,
        ),
      ),
    );
  }
}

class _OrSemanticsHint extends StatelessWidget {
  const _OrSemanticsHint();

  @override
  Widget build(BuildContext context) {
    return const Text(
      'Скидка применится, если товар подходит под любое условие.',
      style: TextStyle(
        fontSize: 12,
        color: AppColors.textTertiary,
        height: 1.35,
      ),
    );
  }
}

class _AllCatalogToggle extends StatelessWidget {
  final bool selected;
  final VoidCallback onTap;

  const _AllCatalogToggle({required this.selected, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return InkWell(
      borderRadius: BorderRadius.circular(AppRadius.md),
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(
          horizontal: AppSpacing.md,
          vertical: AppSpacing.md,
        ),
        decoration: BoxDecoration(
          color: selected ? AppColors.surfaceWarm : AppColors.surface,
          borderRadius: BorderRadius.circular(AppRadius.md),
          border: Border.all(
            color: selected
                ? AppColors.textPrimary
                : AppColors.border.withValues(alpha: 0.6),
            width: selected ? 1.0 : 0.6,
          ),
        ),
        child: Row(
          children: [
            _SelectableIndicator(selected: selected),
            const SizedBox(width: AppSpacing.md),
            const Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'На весь каталог',
                    style: TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w700,
                      color: AppColors.textPrimary,
                    ),
                  ),
                  SizedBox(height: 2),
                  Text(
                    'Скидка действует на все товары.',
                    style: TextStyle(
                      fontSize: 12,
                      color: AppColors.textTertiary,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _SelectableIndicator extends StatelessWidget {
  final bool selected;
  const _SelectableIndicator({required this.selected});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 22,
      height: 22,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        color: selected ? AppColors.textPrimary : Colors.transparent,
        border: Border.all(
          color: selected ? AppColors.textPrimary : AppColors.border,
          width: 1.2,
        ),
      ),
      alignment: Alignment.center,
      child: selected
          ? const Icon(Icons.check, size: 14, color: AppColors.surface)
          : null,
    );
  }
}

class _TileContainer extends StatelessWidget {
  final Widget child;
  final VoidCallback? onTap;

  const _TileContainer({required this.child, this.onTap});

  @override
  Widget build(BuildContext context) {
    final decorated = Container(
      padding: const EdgeInsets.symmetric(
        horizontal: AppSpacing.md,
        vertical: AppSpacing.md,
      ),
      decoration: BoxDecoration(
        color: AppColors.surfaceWarm,
        borderRadius: BorderRadius.circular(AppRadius.md),
        border: Border.all(color: AppColors.border.withValues(alpha: 0.5)),
      ),
      child: child,
    );
    if (onTap == null) return decorated;
    return InkWell(
      borderRadius: BorderRadius.circular(AppRadius.md),
      onTap: onTap,
      child: decorated,
    );
  }
}

class _FriendlyValueTile extends StatelessWidget {
  final IconData icon;
  final String typeLabel;
  final String valueLabel;
  final VoidCallback onEdit;
  final VoidCallback onRemove;

  const _FriendlyValueTile({
    required this.icon,
    required this.typeLabel,
    required this.valueLabel,
    required this.onEdit,
    required this.onRemove,
  });

  @override
  Widget build(BuildContext context) {
    return _TileContainer(
      onTap: onEdit,
      child: Row(
        children: [
          Icon(icon, size: 20, color: AppColors.textSecondary),
          const SizedBox(width: AppSpacing.sm),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  typeLabel,
                  style: const TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w700,
                    letterSpacing: 0.8,
                    color: AppColors.textTertiary,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  valueLabel,
                  style: const TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                    color: AppColors.textPrimary,
                  ),
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                ),
              ],
            ),
          ),
          _RemoveIconButton(onPressed: onRemove),
        ],
      ),
    );
  }
}

class _ProductTile extends StatelessWidget {
  final String productId;
  final CatalogItemEntity? resolved;
  final bool isLoading;
  final VoidCallback onEdit;
  final VoidCallback onRemove;

  const _ProductTile({
    required this.productId,
    required this.resolved,
    required this.isLoading,
    required this.onEdit,
    required this.onRemove,
  });

  @override
  Widget build(BuildContext context) {
    final title = resolved?.title.trim();
    final imageUrl = resolved?.imageUrl;
    final brand = resolved?.brand;
    final category = resolved?.category;
    final subtitleParts = <String>[
      if (brand != null && brand.trim().isNotEmpty) brand.trim(),
      if (category != null && category.trim().isNotEmpty) category.trim(),
    ];
    final String displayTitle;
    final String? displaySubtitle;
    if (title != null && title.isNotEmpty) {
      displayTitle = title;
      displaySubtitle =
          subtitleParts.isEmpty ? null : subtitleParts.join(' · ');
    } else if (isLoading) {
      displayTitle = 'Загрузка…';
      displaySubtitle = null;
    } else {
      displayTitle = 'Выбранный товар';
      displaySubtitle = 'Название товара не удалось загрузить';
    }

    return _TileContainer(
      onTap: onEdit,
      child: Row(
        children: [
          _ProductThumb(imageUrl: imageUrl),
          const SizedBox(width: AppSpacing.md),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Товар',
                  style: TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w700,
                    letterSpacing: 0.8,
                    color: AppColors.textTertiary,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  displayTitle,
                  style: const TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                    color: AppColors.textPrimary,
                  ),
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                ),
                if (displaySubtitle != null) ...[
                  const SizedBox(height: 2),
                  Text(
                    displaySubtitle,
                    style: const TextStyle(
                      fontSize: 12,
                      color: AppColors.textTertiary,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ],
              ],
            ),
          ),
          _RemoveIconButton(onPressed: onRemove),
        ],
      ),
    );
  }
}

class _ProductThumb extends StatelessWidget {
  final String? imageUrl;
  const _ProductThumb({required this.imageUrl});

  static const double size = 44;

  @override
  Widget build(BuildContext context) {
    final placeholder = Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        color: AppColors.surfaceDim,
        borderRadius: BorderRadius.circular(AppRadius.sm),
      ),
      child: const Icon(
        Icons.image_outlined,
        size: 18,
        color: AppColors.textTertiary,
      ),
    );
    final url = imageUrl?.trim();
    if (url == null || url.isEmpty) return placeholder;
    return ClipRRect(
      borderRadius: BorderRadius.circular(AppRadius.sm),
      child: CachedNetworkImage(
        imageUrl: url,
        width: size,
        height: size,
        fit: BoxFit.cover,
        placeholder: (_, _) => placeholder,
        errorWidget: (_, _, _) => placeholder,
      ),
    );
  }
}

class _AdvancedTile extends StatelessWidget {
  final DiscountCampaignTargetEntity target;
  final VoidCallback onRemove;

  const _AdvancedTile({required this.target, required this.onRemove});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(
        horizontal: AppSpacing.md,
        vertical: AppSpacing.md,
      ),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(AppRadius.md),
        border: Border.all(color: AppColors.border.withValues(alpha: 0.6)),
      ),
      child: Row(
        children: [
          const Icon(
            Icons.build_outlined,
            size: 18,
            color: AppColors.textTertiary,
          ),
          const SizedBox(width: AppSpacing.sm),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Расширенное условие',
                  style: TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w700,
                    letterSpacing: 0.8,
                    color: AppColors.textTertiary,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  advancedTargetSummary(target),
                  style: const TextStyle(
                    fontSize: 13,
                    color: AppColors.textPrimary,
                    height: 1.35,
                  ),
                ),
              ],
            ),
          ),
          _RemoveIconButton(onPressed: onRemove),
        ],
      ),
    );
  }
}

class _RemoveIconButton extends StatelessWidget {
  final VoidCallback onPressed;
  const _RemoveIconButton({required this.onPressed});

  @override
  Widget build(BuildContext context) {
    return IconButton(
      onPressed: onPressed,
      visualDensity: VisualDensity.compact,
      icon: const Icon(
        Icons.delete_outline,
        size: 20,
        color: AppColors.textTertiary,
      ),
      tooltip: 'Удалить',
    );
  }
}

// ---------------------------------------------------------------------------
// Pickers
// ---------------------------------------------------------------------------

class _SheetScaffold extends StatelessWidget {
  final String title;
  final Widget child;
  final double maxHeightFactor;

  const _SheetScaffold({
    required this.title,
    required this.child,
    this.maxHeightFactor = 0.85,
  });

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      top: false,
      child: ConstrainedBox(
        constraints: BoxConstraints(
          maxHeight: MediaQuery.of(context).size.height * maxHeightFactor,
        ),
        child: Padding(
          padding: EdgeInsets.only(
            bottom: MediaQuery.of(context).viewInsets.bottom,
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const SizedBox(height: AppSpacing.sm),
              Container(
                width: 36,
                height: 4,
                decoration: BoxDecoration(
                  color: AppColors.border,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
              Padding(
                padding: const EdgeInsets.fromLTRB(
                  AppSpacing.lg,
                  AppSpacing.md,
                  AppSpacing.sm,
                  AppSpacing.sm,
                ),
                child: Row(
                  children: [
                    Expanded(
                      child: Text(
                        title,
                        style: const TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w700,
                          color: AppColors.textPrimary,
                        ),
                      ),
                    ),
                    IconButton(
                      icon: const Icon(Icons.close),
                      onPressed: () => Navigator.of(context).maybePop(),
                    ),
                  ],
                ),
              ),
              Flexible(child: child),
            ],
          ),
        ),
      ),
    );
  }
}

class _TargetTypePickerSheet extends StatelessWidget {
  const _TargetTypePickerSheet();

  @override
  Widget build(BuildContext context) {
    return _SheetScaffold(
      title: 'Добавить условие',
      maxHeightFactor: 0.55,
      child: ListView(
        shrinkWrap: true,
        padding: const EdgeInsets.fromLTRB(
          AppSpacing.lg,
          0,
          AppSpacing.lg,
          AppSpacing.lg,
        ),
        children: const [
          _TypeOption(
            kind: FriendlyTargetKind.category,
            icon: Icons.category_outlined,
            title: 'Категория',
            subtitle: 'Например: Уход за волосами',
          ),
          _TypeOption(
            kind: FriendlyTargetKind.brand,
            icon: Icons.local_offer_outlined,
            title: 'Бренд',
            subtitle: 'Например: L’Oréal',
          ),
          _TypeOption(
            kind: FriendlyTargetKind.product,
            icon: Icons.inventory_2_outlined,
            title: 'Товар',
            subtitle: 'Выбрать конкретный товар из каталога',
          ),
        ],
      ),
    );
  }
}

class _TypeOption extends StatelessWidget {
  final FriendlyTargetKind kind;
  final IconData icon;
  final String title;
  final String subtitle;

  const _TypeOption({
    required this.kind,
    required this.icon,
    required this.title,
    required this.subtitle,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: AppSpacing.sm),
      child: InkWell(
        borderRadius: BorderRadius.circular(AppRadius.md),
        onTap: () => Navigator.of(context).pop(kind),
        child: Container(
          padding: const EdgeInsets.symmetric(
            horizontal: AppSpacing.md,
            vertical: AppSpacing.md,
          ),
          decoration: BoxDecoration(
            color: AppColors.surfaceWarm,
            borderRadius: BorderRadius.circular(AppRadius.md),
            border: Border.all(color: AppColors.border.withValues(alpha: 0.6)),
          ),
          child: Row(
            children: [
              Icon(icon, size: 22, color: AppColors.textPrimary),
              const SizedBox(width: AppSpacing.md),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: const TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.w700,
                        color: AppColors.textPrimary,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      subtitle,
                      style: const TextStyle(
                        fontSize: 12,
                        color: AppColors.textTertiary,
                      ),
                    ),
                  ],
                ),
              ),
              const Icon(Icons.chevron_right,
                  color: AppColors.textTertiary, size: 20),
            ],
          ),
        ),
      ),
    );
  }
}

// --- Category picker --------------------------------------------------------

class _CategoryPickerSheet extends StatefulWidget {
  final String? initial;
  const _CategoryPickerSheet({required this.initial});

  @override
  State<_CategoryPickerSheet> createState() => _CategoryPickerSheetState();
}

class _CategoryPickerSheetState extends State<_CategoryPickerSheet> {
  late Future<List<String>> _future;
  final TextEditingController _queryCtrl = TextEditingController();

  @override
  void initState() {
    super.initState();
    _future = sl<GetAvailableCategoriesUseCase>().call();
  }

  @override
  void dispose() {
    _queryCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return _SheetScaffold(
      title: 'Выберите категорию',
      child: _StringListPickerBody(
        queryCtrl: _queryCtrl,
        initial: widget.initial,
        future: _future,
        emptyLabel: 'Категории не найдены',
      ),
    );
  }
}

// --- Brand picker -----------------------------------------------------------

class _BrandPickerSheet extends StatefulWidget {
  final String? initial;
  const _BrandPickerSheet({required this.initial});

  @override
  State<_BrandPickerSheet> createState() => _BrandPickerSheetState();
}

class _BrandPickerSheetState extends State<_BrandPickerSheet> {
  late Future<List<String>> _future;
  final TextEditingController _queryCtrl = TextEditingController();

  @override
  void initState() {
    super.initState();
    _future = sl<GetAllBrandsUseCase>().call();
  }

  @override
  void dispose() {
    _queryCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return _SheetScaffold(
      title: 'Выберите бренд',
      child: _StringListPickerBody(
        queryCtrl: _queryCtrl,
        initial: widget.initial,
        future: _future,
        emptyLabel: 'Бренды не найдены',
      ),
    );
  }
}

class _StringListPickerBody extends StatefulWidget {
  final TextEditingController queryCtrl;
  final String? initial;
  final Future<List<String>> future;
  final String emptyLabel;

  const _StringListPickerBody({
    required this.queryCtrl,
    required this.initial,
    required this.future,
    required this.emptyLabel,
  });

  @override
  State<_StringListPickerBody> createState() => _StringListPickerBodyState();
}

class _StringListPickerBodyState extends State<_StringListPickerBody> {
  @override
  void initState() {
    super.initState();
    widget.queryCtrl.addListener(_onQueryChanged);
  }

  @override
  void dispose() {
    widget.queryCtrl.removeListener(_onQueryChanged);
    super.dispose();
  }

  void _onQueryChanged() {
    if (!mounted) return;
    setState(() {});
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(
            AppSpacing.lg,
            0,
            AppSpacing.lg,
            AppSpacing.sm,
          ),
          child: TextField(
            controller: widget.queryCtrl,
            decoration: const InputDecoration(
              hintText: 'Поиск',
              prefixIcon: Icon(Icons.search, size: 20),
            ),
          ),
        ),
        Expanded(
          child: FutureBuilder<List<String>>(
            future: widget.future,
            builder: (context, snapshot) {
              if (snapshot.connectionState != ConnectionState.done) {
                return const Center(
                  child: Padding(
                    padding: EdgeInsets.all(AppSpacing.xl),
                    child: CircularProgressIndicator.adaptive(),
                  ),
                );
              }
              if (snapshot.hasError) {
                return Padding(
                  padding: const EdgeInsets.all(AppSpacing.lg),
                  child: Text(
                    'Не удалось загрузить список',
                    style: TextStyle(color: AppColors.textSecondary),
                    textAlign: TextAlign.center,
                  ),
                );
              }
              final all = snapshot.data ?? const <String>[];
              final query = widget.queryCtrl.text.trim().toLowerCase();
              final filtered = query.isEmpty
                  ? all
                  : all
                      .where((v) => v.toLowerCase().contains(query))
                      .toList(growable: false);
              if (filtered.isEmpty) {
                return Padding(
                  padding: const EdgeInsets.all(AppSpacing.lg),
                  child: Text(
                    widget.emptyLabel,
                    style: const TextStyle(color: AppColors.textSecondary),
                    textAlign: TextAlign.center,
                  ),
                );
              }
              return ListView.separated(
                padding: const EdgeInsets.fromLTRB(
                  AppSpacing.lg,
                  0,
                  AppSpacing.lg,
                  AppSpacing.lg,
                ),
                itemCount: filtered.length,
                separatorBuilder: (_, _) => const SizedBox(height: 4),
                itemBuilder: (context, index) {
                  final value = filtered[index];
                  final selected = value == widget.initial;
                  return InkWell(
                    borderRadius: BorderRadius.circular(AppRadius.md),
                    onTap: () => Navigator.of(context).pop(value),
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: AppSpacing.md,
                        vertical: AppSpacing.md,
                      ),
                      decoration: BoxDecoration(
                        color: selected
                            ? AppColors.surfaceWarm
                            : Colors.transparent,
                        borderRadius: BorderRadius.circular(AppRadius.md),
                        border: Border.all(
                          color: selected
                              ? AppColors.textPrimary
                              : AppColors.border.withValues(alpha: 0.4),
                          width: selected ? 1.0 : 0.6,
                        ),
                      ),
                      child: Row(
                        children: [
                          Expanded(
                            child: Text(
                              value,
                              style: TextStyle(
                                fontSize: 14,
                                fontWeight: selected
                                    ? FontWeight.w700
                                    : FontWeight.w500,
                                color: AppColors.textPrimary,
                              ),
                            ),
                          ),
                          if (selected)
                            const Icon(Icons.check,
                                size: 18, color: AppColors.textPrimary),
                        ],
                      ),
                    ),
                  );
                },
              );
            },
          ),
        ),
      ],
    );
  }
}

// --- Product picker ---------------------------------------------------------

class _ProductPickerSheet extends StatefulWidget {
  const _ProductPickerSheet();

  @override
  State<_ProductPickerSheet> createState() => _ProductPickerSheetState();
}

class _ProductPickerSheetState extends State<_ProductPickerSheet> {
  final TextEditingController _queryCtrl = TextEditingController();
  Timer? _debounce;
  String _activeQuery = '';
  int _requestSeq = 0;
  bool _loading = false;
  String? _error;
  List<CatalogItemEntity> _results = const [];

  @override
  void initState() {
    super.initState();
    _queryCtrl.addListener(_onQueryChanged);
    // Initial load: empty query returns first page of catalog.
    _runSearch('');
  }

  @override
  void dispose() {
    _debounce?.cancel();
    _queryCtrl.dispose();
    super.dispose();
  }

  void _onQueryChanged() {
    _debounce?.cancel();
    _debounce = Timer(const Duration(milliseconds: 300), () {
      final q = _queryCtrl.text.trim();
      if (q == _activeQuery) return;
      _runSearch(q);
    });
  }

  Future<void> _runSearch(String query) async {
    final seq = ++_requestSeq;
    setState(() {
      _loading = true;
      _error = null;
      _activeQuery = query;
    });
    try {
      final page = await sl<CatalogRepository>().searchCatalog(
        query: query,
        from: 0,
        to: 49,
      );
      if (!mounted || seq != _requestSeq) return;
      // Dedupe by productId (search returns variants).
      final seen = <String>{};
      final deduped = <CatalogItemEntity>[];
      for (final item in page.items) {
        if (seen.add(item.productId)) deduped.add(item);
      }
      setState(() {
        _results = deduped;
        _loading = false;
      });
    } catch (e) {
      if (!mounted || seq != _requestSeq) return;
      setState(() {
        _error = 'Не удалось загрузить товары';
        _loading = false;
        _results = const [];
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return _SheetScaffold(
      title: 'Выберите товар',
      child: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(
              AppSpacing.lg,
              0,
              AppSpacing.lg,
              AppSpacing.sm,
            ),
            child: TextField(
              controller: _queryCtrl,
              decoration: const InputDecoration(
                hintText: 'Поиск по названию',
                prefixIcon: Icon(Icons.search, size: 20),
              ),
            ),
          ),
          Expanded(child: _buildBody()),
        ],
      ),
    );
  }

  Widget _buildBody() {
    if (_loading && _results.isEmpty) {
      return const Center(
        child: Padding(
          padding: EdgeInsets.all(AppSpacing.xl),
          child: CircularProgressIndicator.adaptive(),
        ),
      );
    }
    if (_error != null && _results.isEmpty) {
      return Padding(
        padding: const EdgeInsets.all(AppSpacing.lg),
        child: Text(
          _error!,
          style: const TextStyle(color: AppColors.textSecondary),
          textAlign: TextAlign.center,
        ),
      );
    }
    if (_results.isEmpty) {
      return const Padding(
        padding: EdgeInsets.all(AppSpacing.lg),
        child: Text(
          'Ничего не найдено',
          style: TextStyle(color: AppColors.textSecondary),
          textAlign: TextAlign.center,
        ),
      );
    }
    return ListView.separated(
      padding: const EdgeInsets.fromLTRB(
        AppSpacing.lg,
        0,
        AppSpacing.lg,
        AppSpacing.lg,
      ),
      itemCount: _results.length,
      separatorBuilder: (_, _) => const SizedBox(height: AppSpacing.xs),
      itemBuilder: (context, index) {
        final item = _results[index];
        return _ProductPickerRow(
          item: item,
          onTap: () => Navigator.of(context).pop(item),
        );
      },
    );
  }
}

class _ProductPickerRow extends StatelessWidget {
  final CatalogItemEntity item;
  final VoidCallback onTap;

  const _ProductPickerRow({required this.item, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final subtitleParts = <String>[
      if ((item.brand ?? '').trim().isNotEmpty) item.brand!.trim(),
      if ((item.category ?? '').trim().isNotEmpty) item.category!.trim(),
    ];
    final priceText = _formatPrice(item.price);
    return InkWell(
      borderRadius: BorderRadius.circular(AppRadius.md),
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(
          horizontal: AppSpacing.md,
          vertical: AppSpacing.sm,
        ),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(AppRadius.md),
          border: Border.all(color: AppColors.border.withValues(alpha: 0.4)),
        ),
        child: Row(
          children: [
            _ProductThumb(imageUrl: item.imageUrl),
            const SizedBox(width: AppSpacing.md),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    item.title,
                    style: const TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w600,
                      color: AppColors.textPrimary,
                    ),
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
                  if (subtitleParts.isNotEmpty) ...[
                    const SizedBox(height: 2),
                    Text(
                      subtitleParts.join(' · '),
                      style: const TextStyle(
                        fontSize: 12,
                        color: AppColors.textTertiary,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ],
                ],
              ),
            ),
            if (priceText != null) ...[
              const SizedBox(width: AppSpacing.sm),
              Text(
                priceText,
                style: const TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w700,
                  color: AppColors.textPrimary,
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  static String? _formatPrice(double? price) {
    if (price == null) return null;
    if (price == price.roundToDouble()) {
      return '${price.toInt()} ₽';
    }
    return '${price.toStringAsFixed(2)} ₽';
  }
}
