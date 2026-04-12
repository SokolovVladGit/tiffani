import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/di/injector.dart';
import '../../../../core/router/product_details_payload.dart';
import '../../../../core/router/route_names.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_decorations.dart';
import '../../../../core/theme/app_radius.dart';
import '../../../../core/theme/app_spacing.dart';
import '../../../../core/utils/debounce.dart';
import '../../domain/entities/catalog_filters_entity.dart';
import '../../domain/usecases/get_all_brands_use_case.dart';
import '../../domain/usecases/get_available_categories_use_case.dart';
import '../../domain/usecases/get_available_marks_use_case.dart';
import '../bloc/catalog_bloc.dart';
import '../bloc/catalog_event.dart';
import '../bloc/catalog_state.dart';
import '../cubit/catalog_filter_cubit.dart';
import '../cubit/catalog_filter_state.dart';
import '../cubit/filter_cubit.dart';
import '../widgets/catalog_brand_strip.dart';
import '../widgets/catalog_card.dart';
import '../widgets/catalog_category_grid.dart';

class CatalogPage extends StatefulWidget {
  final String? initialBrand;
  final String? initialCategory;
  final String? initialMark;
  final bool initialSaleOnly;
  final String? title;

  const CatalogPage({
    super.key,
    this.initialBrand,
    this.initialCategory,
    this.initialMark,
    this.initialSaleOnly = false,
    this.title,
  });

  @override
  State<CatalogPage> createState() => _CatalogPageState();
}

class _CatalogPageState extends State<CatalogPage> {
  final _searchController = TextEditingController();
  final _debounce = Debounce(duration: const Duration(milliseconds: 400));
  late final CatalogBloc _bloc;
  late final FilterCubit _filterCubit;
  late final CatalogFilterCubit _catalogFilterCubit;
  bool _ownsCatalogFilterCubit = false;

  bool get _hasInitialFilters =>
      widget.initialBrand != null ||
      widget.initialCategory != null ||
      widget.initialMark != null ||
      widget.initialSaleOnly;

  @override
  void initState() {
    super.initState();
    _bloc = sl<CatalogBloc>();
    _filterCubit = sl<FilterCubit>();

    if (_hasInitialFilters) {
      _catalogFilterCubit = CatalogFilterCubit(
        sl<GetAllBrandsUseCase>(),
        sl<GetAvailableCategoriesUseCase>(),
        sl<GetAvailableMarksUseCase>(),
      );
      _ownsCatalogFilterCubit = true;
      _catalogFilterCubit.loadFilterOptions();
      if (widget.initialBrand != null) {
        _catalogFilterCubit.setBrand(widget.initialBrand);
      }
      if (widget.initialCategory != null) {
        _catalogFilterCubit.setCategory(widget.initialCategory);
      }
      if (widget.initialMark != null) {
        _catalogFilterCubit.setMark(widget.initialMark);
      }
      _bloc.add(CatalogFiltersApplied(
        CatalogFiltersEntity(
          selectedBrand: widget.initialBrand,
          selectedCategory: widget.initialCategory,
          selectedMark: widget.initialMark,
          saleOnly: widget.initialSaleOnly,
        ),
      ));
    } else {
      _catalogFilterCubit = sl<CatalogFilterCubit>();
      _catalogFilterCubit.loadFilterOptions();
      _bloc.add(const CatalogStarted());
    }
  }

  @override
  void dispose() {
    _searchController.dispose();
    _debounce.dispose();
    _bloc.close();
    _filterCubit.close();
    if (_ownsCatalogFilterCubit) _catalogFilterCubit.close();
    super.dispose();
  }

  void _onSearchChanged(String value) {
    _debounce.call(() {
      _bloc.add(CatalogSearchChanged(value));
    });
  }

  @override
  Widget build(BuildContext context) {
    return MultiBlocProvider(
      providers: [
        BlocProvider.value(value: _bloc),
        BlocProvider.value(value: _catalogFilterCubit),
        BlocProvider.value(value: _filterCubit),
      ],
      child: Scaffold(
        backgroundColor: Colors.transparent,
        extendBodyBehindAppBar: true,
        appBar: AppBar(
          backgroundColor: Colors.transparent,
          surfaceTintColor: Colors.transparent,
          shadowColor: Colors.transparent,
          elevation: 0,
          scrolledUnderElevation: 0,
          title: Text(widget.title ?? widget.initialBrand ?? 'Каталог'),
        ),
        body: Stack(
          children: [
            Positioned.fill(
              child: Image.asset(
                'assets/images/home/bg.jpg',
                fit: BoxFit.cover,
              ),
            ),
            const Positioned.fill(
              child: ColoredBox(color: Color(0x38FFFFFF)),
            ),
            SafeArea(
              child: Column(
                children: [
                  _SearchBar(
                    controller: _searchController,
                    onChanged: _onSearchChanged,
                    onClear: () {
                      _searchController.clear();
                      _bloc.add(const CatalogSearchChanged(''));
                    },
                  ),
                  Expanded(child: _CatalogScrollBody(bloc: _bloc)),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Search bar — pinned above scroll
// ---------------------------------------------------------------------------

class _SearchBar extends StatelessWidget {
  final TextEditingController controller;
  final ValueChanged<String> onChanged;
  final VoidCallback onClear;

  const _SearchBar({
    required this.controller,
    required this.onChanged,
    required this.onClear,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 4, 16, 6),
      child: TextField(
        controller: controller,
        onChanged: onChanged,
        style: const TextStyle(fontSize: 15),
        decoration: InputDecoration(
          hintText: 'Поиск товаров',
          filled: true,
          fillColor: const Color(0xDEFFFFFF),
          prefixIcon: const Icon(Icons.search, size: 20),
          suffixIcon: ListenableBuilder(
            listenable: controller,
            builder: (context, _) {
              if (controller.text.isEmpty) {
                return const SizedBox.shrink();
              }
              return IconButton(
                icon: const Icon(Icons.clear, size: 18),
                onPressed: onClear,
              );
            },
          ),
        ),
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Scrollable body — discovery + products in one scroll
// ---------------------------------------------------------------------------

class _CatalogScrollBody extends StatefulWidget {
  final CatalogBloc bloc;

  const _CatalogScrollBody({required this.bloc});

  @override
  State<_CatalogScrollBody> createState() => _CatalogScrollBodyState();
}

class _CatalogScrollBodyState extends State<_CatalogScrollBody> {
  final _scrollController = ScrollController();
  bool _loadMoreTriggered = false;

  static const _prefetchThreshold = 0.75;

  @override
  void initState() {
    super.initState();
    _scrollController.addListener(_onScroll);
  }

  @override
  void dispose() {
    _scrollController.removeListener(_onScroll);
    _scrollController.dispose();
    super.dispose();
  }

  void _onScroll() {
    if (_loadMoreTriggered) return;
    if (!_scrollController.hasClients) return;
    final pos = _scrollController.position;
    if (pos.maxScrollExtent <= 0) return;
    if (pos.pixels / pos.maxScrollExtent >= _prefetchThreshold) {
      _loadMoreTriggered = true;
      widget.bloc.add(const CatalogLoadMoreRequested());
    }
  }

  void _applyFilters(BuildContext context) {
    final fs = context.read<CatalogFilterCubit>().state;
    widget.bloc.add(CatalogFiltersApplied(CatalogFiltersEntity(
      selectedBrand: fs.selectedBrand,
      selectedCategory: fs.selectedCategory,
      selectedMark: fs.selectedMark,
      sortOption: fs.sortOption,
    )));
  }

  void _onCategoryTap(BuildContext context, String? category) {
    final cubit = context.read<CatalogFilterCubit>();
    cubit.setCategory(category);
    _applyFilters(context);
  }

  void _onBrandTap(BuildContext context, String? brand) {
    final cubit = context.read<CatalogFilterCubit>();
    cubit.setBrand(brand);
    _applyFilters(context);
  }

  @override
  Widget build(BuildContext context) {
    return BlocBuilder<CatalogBloc, CatalogState>(
      buildWhen: (prev, curr) =>
          prev.status != curr.status ||
          prev.items.length != curr.items.length ||
          prev.isLoadingMore != curr.isLoadingMore ||
          prev.totalCount != curr.totalCount,
      builder: (context, catalogState) {
        _loadMoreTriggered = false;
        return BlocBuilder<CatalogFilterCubit, CatalogFilterState>(
          buildWhen: (prev, curr) =>
              prev.availableCategories != curr.availableCategories ||
              prev.availableBrands != curr.availableBrands ||
              prev.selectedCategory != curr.selectedCategory ||
              prev.selectedBrand != curr.selectedBrand,
          builder: (context, filterState) {
            return CustomScrollView(
              controller: _scrollController,
              slivers: [
                // -- Category discovery grid --
                SliverToBoxAdapter(
                  child: CatalogCategoryGrid(
                    categories: filterState.availableCategories,
                    selectedCategory: filterState.selectedCategory,
                    onCategoryTap: (c) => _onCategoryTap(context, c),
                  ),
                ),
                // -- Brand discovery strip --
                SliverToBoxAdapter(
                  child: CatalogBrandStrip(
                    brands: filterState.availableBrands,
                    selectedBrand: filterState.selectedBrand,
                    onBrandTap: (b) => _onBrandTap(context, b),
                  ),
                ),
                // -- Result count --
                if (catalogState.status == CatalogStatus.success)
                  SliverToBoxAdapter(
                    child: _ResultCount(totalCount: catalogState.totalCount),
                  ),
                // -- Content based on state --
                ..._buildContentSlivers(context, catalogState),
              ],
            );
          },
        );
      },
    );
  }

  List<Widget> _buildContentSlivers(
    BuildContext context,
    CatalogState state,
  ) {
    return switch (state.status) {
      CatalogStatus.initial || CatalogStatus.loading => [
          SliverList.builder(
            itemCount: 6,
            itemBuilder: (_, _) => const _SkeletonCard(),
          ),
        ],
      CatalogStatus.failure => [
          SliverFillRemaining(
            hasScrollBody: false,
            child: _FailureView(
              message: state.errorMessage ?? 'Что-то пошло не так',
            ),
          ),
        ],
      CatalogStatus.success when state.items.isEmpty => [
          SliverFillRemaining(
            hasScrollBody: false,
            child: _EmptyView(
              isSearching: state.isSearching,
              hasActiveFilters: state.hasActiveFilters,
              onClearFilters: () {
                context.read<FilterCubit>().clear();
                context.read<CatalogFilterCubit>().clearAll();
                widget.bloc
                  ..add(const CatalogAttributeFiltersApplied({}))
                  ..add(
                      CatalogFiltersApplied(const CatalogFiltersEntity()));
              },
            ),
          ),
        ],
      CatalogStatus.success => [
          SliverList.builder(
            itemCount:
                state.items.length + (state.isLoadingMore ? 1 : 0),
            itemBuilder: (context, index) {
              if (index >= state.items.length) {
                return const _BottomLoader();
              }
              final item = state.items[index];
              final heroTag = 'catalog-${item.id}';
              return CatalogCard(
                item: item,
                heroTag: heroTag,
                onTap: () => context.push(
                  RouteNames.catalogDetails,
                  extra:
                      ProductDetailsPayload(item: item, heroTag: heroTag),
                ),
              );
            },
          ),
        ],
    };
  }
}

// ---------------------------------------------------------------------------
// Skeleton card
// ---------------------------------------------------------------------------

class _SkeletonCard extends StatelessWidget {
  const _SkeletonCard();

  static const double _imageSize = 108;

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.symmetric(
        horizontal: AppSpacing.lg,
        vertical: 5,
      ),
      padding: const EdgeInsets.all(AppSpacing.md),
      decoration: AppDecorations.cardSoft(),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: _imageSize,
            height: _imageSize,
            decoration: AppDecorations.skeleton(radius: AppRadius.md),
          ),
          const SizedBox(width: AppSpacing.lg),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _bar(width: 48, height: 14),
                const SizedBox(height: AppSpacing.xs),
                _bar(height: 14),
                const SizedBox(height: 4),
                _bar(width: 140, height: 14),
                const SizedBox(height: 2),
                _bar(width: 100, height: 11),
                const SizedBox(height: AppSpacing.sm),
                _bar(width: 72, height: 16),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _bar({double? width, required double height}) {
    return Container(
      width: width ?? double.infinity,
      height: height,
      decoration: AppDecorations.skeleton(),
    );
  }
}

// ---------------------------------------------------------------------------
// Result count
// ---------------------------------------------------------------------------

class _ResultCount extends StatelessWidget {
  final int totalCount;

  const _ResultCount({required this.totalCount});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: AppSpacing.lg, vertical: 8),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 5),
            decoration: BoxDecoration(
              color: const Color(0xCCFFFFFF),
              borderRadius: BorderRadius.circular(14),
              border: Border.all(
                color: const Color(0x80FFFFFF),
                width: 1,
              ),
            ),
            child: Text(
              _label(totalCount),
              style: const TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w600,
                color: AppColors.textSecondary,
              ),
            ),
          ),
        ],
      ),
    );
  }

  static String _label(int count) {
    if (count == 0) return 'Ничего не найдено';
    final mod10 = count % 10;
    final mod100 = count % 100;
    if (mod10 == 1 && mod100 != 11) return '$count товар';
    if (mod10 >= 2 && mod10 <= 4 && (mod100 < 12 || mod100 > 14)) {
      return '$count товара';
    }
    return '$count товаров';
  }
}

// ---------------------------------------------------------------------------
// Bottom loader
// ---------------------------------------------------------------------------

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

// ---------------------------------------------------------------------------
// Empty view
// ---------------------------------------------------------------------------

class _EmptyView extends StatelessWidget {
  final bool isSearching;
  final bool hasActiveFilters;
  final VoidCallback onClearFilters;

  const _EmptyView({
    this.isSearching = false,
    this.hasActiveFilters = false,
    required this.onClearFilters,
  });

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              Icons.search_off_rounded,
              size: 48,
              color: AppColors.textTertiary,
            ),
            const SizedBox(height: 12),
            Text(
              (isSearching || hasActiveFilters)
                  ? 'Ничего не найдено по вашему запросу'
                  : 'Товары не найдены',
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w500,
                color: AppColors.textSecondary,
              ),
            ),
            if (hasActiveFilters) ...[
              const SizedBox(height: 12),
              GestureDetector(
                onTap: onClearFilters,
                child: Text(
                  'Сбросить фильтры',
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w500,
                    color: AppColors.seed,
                  ),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Failure view
// ---------------------------------------------------------------------------

class _FailureView extends StatelessWidget {
  final String message;

  const _FailureView({required this.message});

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              Icons.error_outline_rounded,
              size: 48,
              color: AppColors.textTertiary,
            ),
            const SizedBox(height: 12),
            Text(
              message,
              style:
                  TextStyle(fontSize: 14, color: AppColors.textSecondary),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 20),
            ElevatedButton(
              onPressed: () {
                context.read<CatalogBloc>().add(const CatalogRefreshed());
              },
              child: const Text('Повторить'),
            ),
          ],
        ),
      ),
    );
  }
}
