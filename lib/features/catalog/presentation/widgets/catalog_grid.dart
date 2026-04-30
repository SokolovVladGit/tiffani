import 'package:flutter/material.dart';

import '../../../../core/router/product_details_payload.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_spacing.dart';
import '../../../../core/utils/navigation_guard.dart';
import '../../../../core/utils/product_hero_tag.dart';
import '../../domain/entities/catalog_item_entity.dart';
import 'catalog_card.dart';

class CatalogGrid extends StatefulWidget {
  final List<CatalogItemEntity> items;
  final bool isLoadingMore;
  final VoidCallback? onLoadMore;

  const CatalogGrid({
    super.key,
    required this.items,
    this.isLoadingMore = false,
    this.onLoadMore,
  });

  @override
  State<CatalogGrid> createState() => _CatalogGridState();
}

class _CatalogGridState extends State<CatalogGrid> {
  final _scrollController = ScrollController();
  bool _loadMoreTriggered = false;

  static const _prefetchThreshold = 0.75;

  @override
  void initState() {
    super.initState();
    _scrollController.addListener(_onScroll);
  }

  @override
  void didUpdateWidget(covariant CatalogGrid oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.items.length != oldWidget.items.length ||
        widget.isLoadingMore != oldWidget.isLoadingMore) {
      _loadMoreTriggered = false;
    }
  }

  @override
  void dispose() {
    _scrollController.removeListener(_onScroll);
    _scrollController.dispose();
    super.dispose();
  }

  void _onScroll() {
    if (_loadMoreTriggered) return;
    if (widget.onLoadMore == null) return;
    if (!_scrollController.hasClients) return;

    final position = _scrollController.position;
    if (position.maxScrollExtent <= 0) return;

    final ratio = position.pixels / position.maxScrollExtent;
    if (ratio >= _prefetchThreshold) {
      _loadMoreTriggered = true;
      widget.onLoadMore!();
    }
  }

  @override
  Widget build(BuildContext context) {
    final itemCount = widget.items.length + (widget.isLoadingMore ? 1 : 0);
    return ListView.builder(
      controller: _scrollController,
      itemCount: itemCount,
      padding: const EdgeInsets.only(top: AppSpacing.xs, bottom: AppSpacing.lg),
      itemBuilder: (context, index) {
        if (index >= widget.items.length) {
          return const _BottomLoader();
        }
        final item = widget.items[index];
        final heroTag = ProductHeroTag.catalog(item.id);
        return CatalogCard(
          key: ValueKey(heroTag),
          item: item,
          heroTag: heroTag,
          onTap: () => NavigationGuard.pushCatalogDetailsOnce(
            context,
            ProductDetailsPayload(item: item, heroTag: heroTag),
          ),
        );
      },
    );
  }
}

class _BottomLoader extends StatelessWidget {
  const _BottomLoader();

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: AppSpacing.xl),
      child: Center(
        child: SizedBox(
          width: 24,
          height: 24,
          child: CircularProgressIndicator(
            strokeWidth: 2,
            color: AppColors.seed,
          ),
        ),
      ),
    );
  }
}
