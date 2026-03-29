import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/router/route_names.dart';
import '../../../../core/theme/app_colors.dart';
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
  bool _loadMoreTriggered = false;

  @override
  void didUpdateWidget(covariant CatalogGrid oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.items.length != oldWidget.items.length ||
        widget.isLoadingMore != oldWidget.isLoadingMore) {
      _loadMoreTriggered = false;
    }
  }

  void _onItemBuilt(int index) {
    if (_loadMoreTriggered) return;
    if (widget.onLoadMore == null) return;
    if (index >= widget.items.length - 5) {
      _loadMoreTriggered = true;
      widget.onLoadMore!();
    }
  }

  @override
  Widget build(BuildContext context) {
    final itemCount = widget.items.length + (widget.isLoadingMore ? 1 : 0);
    return ListView.builder(
      itemCount: itemCount,
      padding: const EdgeInsets.only(top: 4, bottom: 16),
      itemBuilder: (context, index) {
        if (index >= widget.items.length) {
          return const _BottomLoader();
        }
        _onItemBuilt(index);
        final item = widget.items[index];
        return CatalogCard(
          item: item,
          onTap: () => context.push(RouteNames.catalogDetails, extra: item),
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
      padding: const EdgeInsets.symmetric(vertical: 20),
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
