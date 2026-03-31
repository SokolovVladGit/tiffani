import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/di/injector.dart';
import '../../../../core/router/route_names.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/utils/debounce.dart';
import '../../../cart/presentation/cubit/cart_cubit.dart';
import '../../../cart/presentation/cubit/cart_state.dart';
import '../../../favorites/presentation/cubit/favorites_cubit.dart';
import '../../../favorites/presentation/cubit/favorites_state.dart';
import '../../domain/entities/catalog_filters_entity.dart';
import '../../domain/entities/filter_state.dart';
import '../../domain/usecases/get_all_brands_use_case.dart';
import '../../domain/usecases/get_available_categories_use_case.dart';
import '../../domain/usecases/get_available_marks_use_case.dart';
import '../bloc/catalog_bloc.dart';
import '../bloc/catalog_event.dart';
import '../bloc/catalog_state.dart';
import '../cubit/catalog_filter_cubit.dart';
import '../cubit/filter_cubit.dart';
import '../widgets/catalog_filter_bar.dart';
import '../widgets/catalog_grid.dart';
import '../widgets/catalog_list_skeleton.dart';
import '../widgets/filter_bottom_sheet.dart';

class CatalogPage extends StatefulWidget {
  final String? initialBrand;

  const CatalogPage({super.key, this.initialBrand});

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

  @override
  void initState() {
    super.initState();
    _bloc = sl<CatalogBloc>();
    _filterCubit = sl<FilterCubit>();

    if (widget.initialBrand != null) {
      _catalogFilterCubit = CatalogFilterCubit(
        sl<GetAllBrandsUseCase>(),
        sl<GetAvailableCategoriesUseCase>(),
        sl<GetAvailableMarksUseCase>(),
      );
      _ownsCatalogFilterCubit = true;
      _catalogFilterCubit
        ..loadFilterOptions()
        ..setBrand(widget.initialBrand);
      _bloc.add(CatalogFiltersApplied(
        CatalogFiltersEntity(selectedBrand: widget.initialBrand),
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
        appBar: AppBar(
          title: Text(widget.initialBrand ?? 'Catalog'),
          actions: [
            _FilterButton(cubit: _filterCubit),
            _FavoritesButton(),
            _CartButton(),
          ],
        ),
        body: Column(
          children: [
            Container(
              color: AppColors.surface,
              padding: const EdgeInsets.fromLTRB(16, 4, 16, 8),
              child: TextField(
                controller: _searchController,
                onChanged: _onSearchChanged,
                style: const TextStyle(fontSize: 15),
                decoration: InputDecoration(
                  hintText: 'Search products',
                  prefixIcon: const Icon(Icons.search, size: 20),
                  suffixIcon: ListenableBuilder(
                    listenable: _searchController,
                    builder: (context, _) {
                      if (_searchController.text.isEmpty) {
                        return const SizedBox.shrink();
                      }
                      return IconButton(
                        icon: const Icon(Icons.clear, size: 18),
                        onPressed: () {
                          _searchController.clear();
                          _bloc.add(const CatalogSearchChanged(''));
                        },
                      );
                    },
                  ),
                ),
              ),
            ),
            const CatalogFilterBar(),
            const Divider(height: 1),
            const _ResultCount(),
            const Expanded(child: _CatalogBody()),
          ],
        ),
      ),
    );
  }
}

class _FilterButton extends StatelessWidget {
  final FilterCubit cubit;

  const _FilterButton({required this.cubit});

  @override
  Widget build(BuildContext context) {
    return BlocBuilder<FilterCubit, FilterState>(
      bloc: cubit,
      buildWhen: (prev, curr) =>
          prev.hasActiveFilters != curr.hasActiveFilters,
      builder: (context, filterState) {
        return IconButton(
          onPressed: () => showFilterBottomSheet(
            context,
            cubit,
            onApply: () {
              context.read<CatalogBloc>().add(
                    CatalogAttributeFiltersApplied(cubit.state.selected),
                  );
            },
          ),
          icon: Badge(
            isLabelVisible: filterState.hasActiveFilters,
            smallSize: 8,
            child: const Icon(Icons.tune),
          ),
        );
      },
    );
  }
}

class _FavoritesButton extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return BlocBuilder<FavoritesCubit, FavoritesState>(
      bloc: sl<FavoritesCubit>(),
      buildWhen: (prev, curr) => prev.ids.length != curr.ids.length,
      builder: (context, state) {
        final count = state.ids.length;
        return IconButton(
          onPressed: () => context.push(RouteNames.favorites),
          icon: Badge(
            isLabelVisible: count > 0,
            label: Text('$count'),
            child: Icon(
              count > 0 ? Icons.favorite : Icons.favorite_border,
            ),
          ),
        );
      },
    );
  }
}

class _CartButton extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return BlocProvider.value(
      value: sl<CartCubit>(),
      child: BlocBuilder<CartCubit, CartState>(
        buildWhen: (prev, curr) => prev.totalItems != curr.totalItems,
        builder: (context, state) {
          final count = state.totalItems;
          return IconButton(
            onPressed: () {
              final shell = StatefulNavigationShell.maybeOf(context);
              if (shell != null) {
                shell.goBranch(3);
              } else {
                context.push(RouteNames.cart);
              }
            },
            icon: Badge(
              isLabelVisible: count > 0,
              label: Text('$count'),
              child: const Icon(Icons.shopping_bag_outlined),
            ),
          );
        },
      ),
    );
  }
}

class _ResultCount extends StatelessWidget {
  const _ResultCount();

  @override
  Widget build(BuildContext context) {
    return BlocBuilder<CatalogBloc, CatalogState>(
      buildWhen: (prev, curr) =>
          prev.totalCount != curr.totalCount || prev.status != curr.status,
      builder: (context, state) {
        if (state.status != CatalogStatus.success) {
          return const SizedBox.shrink();
        }
        final count = state.totalCount;
        return Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
          child: Text(
            '$count ${count == 1 ? 'product' : 'products'} found',
            style: TextStyle(
              fontSize: 13,
              color: AppColors.textSecondary,
            ),
          ),
        );
      },
    );
  }
}

class _CatalogBody extends StatelessWidget {
  const _CatalogBody();

  @override
  Widget build(BuildContext context) {
    return BlocBuilder<CatalogBloc, CatalogState>(
      builder: (context, state) {
        final child = switch (state.status) {
          CatalogStatus.initial ||
          CatalogStatus.loading => const CatalogListSkeleton(),
          CatalogStatus.failure => _FailureView(
            message: state.errorMessage ?? 'Something went wrong',
          ),
          CatalogStatus.success when state.items.isEmpty => _EmptyView(
            isSearching: state.isSearching,
            hasActiveFilters: state.hasActiveFilters,
            onClearFilters: () {
              context.read<FilterCubit>().clear();
              context.read<CatalogFilterCubit>().clearAll();
              context.read<CatalogBloc>()
                ..add(const CatalogAttributeFiltersApplied({}))
                ..add(CatalogFiltersApplied(const CatalogFiltersEntity()));
            },
          ),
          CatalogStatus.success => CatalogGrid(
            items: state.items,
            isLoadingMore: state.isLoadingMore,
            onLoadMore: () {
              context
                  .read<CatalogBloc>()
                  .add(const CatalogLoadMoreRequested());
            },
          ),
        };
        return AnimatedSwitcher(
          duration: const Duration(milliseconds: 200),
          child: child,
        );
      },
    );
  }
}

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
            if (isSearching || hasActiveFilters)
              Text(
                'No products match your search or filters',
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w500,
                  color: AppColors.textSecondary,
                ),
              )
            else
              Text(
                'No products found',
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
                  'Clear filters',
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
              style: TextStyle(fontSize: 14, color: AppColors.textSecondary),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 20),
            ElevatedButton(
              onPressed: () {
                context.read<CatalogBloc>().add(const CatalogRefreshed());
              },
              child: const Text('Retry'),
            ),
          ],
        ),
      ),
    );
  }
}
