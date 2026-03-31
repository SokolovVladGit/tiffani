import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_radius.dart';
import '../../../../core/theme/app_spacing.dart';
import '../../domain/entities/catalog_filters_entity.dart';
import '../../domain/entities/catalog_sort_option.dart';
import '../bloc/catalog_bloc.dart';
import '../bloc/catalog_event.dart';
import '../cubit/catalog_filter_cubit.dart';
import '../cubit/catalog_filter_state.dart';

class CatalogFilterBar extends StatelessWidget {
  const CatalogFilterBar({super.key});

  @override
  Widget build(BuildContext context) {
    return BlocBuilder<CatalogFilterCubit, CatalogFilterState>(
      builder: (context, state) {
        return Container(
          color: AppColors.surface,
          padding: const EdgeInsets.fromLTRB(
            AppSpacing.lg,
            0,
            AppSpacing.lg,
            AppSpacing.sm,
          ),
          child: Row(
            children: [
              _ChipButton(
                label: 'Filters',
                isActive: state.selectedBrand != null ||
                    state.selectedCategory != null ||
                    state.selectedMark != null,
                onTap: () => _showFilterSheet(context),
              ),
              const SizedBox(width: AppSpacing.sm),
              _ChipButton(
                label: _sortLabel(state.sortOption),
                isActive:
                    state.sortOption != CatalogSortOption.defaultOrder,
                onTap: () => _showSortSheet(context),
              ),
              if (state.hasActiveFilters) ...[
                const Spacer(),
                Material(
                  color: Colors.transparent,
                  child: InkWell(
                    onTap: () {
                      context.read<CatalogFilterCubit>().clearAll();
                      _applyFilters(context);
                    },
                    borderRadius: BorderRadius.circular(AppRadius.xs),
                    child: const Padding(
                      padding: EdgeInsets.symmetric(
                        vertical: AppSpacing.xs,
                        horizontal: AppSpacing.xs,
                      ),
                      child: Text(
                        'Clear',
                        style: TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.w600,
                          color: AppColors.seed,
                        ),
                      ),
                    ),
                  ),
                ),
              ],
            ],
          ),
        );
      },
    );
  }

  String _sortLabel(CatalogSortOption option) {
    return switch (option) {
      CatalogSortOption.defaultOrder => 'Sort',
      CatalogSortOption.priceLowToHigh => 'Price ↑',
      CatalogSortOption.priceHighToLow => 'Price ↓',
      CatalogSortOption.titleAZ => 'A → Z',
    };
  }

  void _applyFilters(BuildContext context) {
    final fs = context.read<CatalogFilterCubit>().state;
    context.read<CatalogBloc>().add(CatalogFiltersApplied(
      CatalogFiltersEntity(
        selectedBrand: fs.selectedBrand,
        selectedCategory: fs.selectedCategory,
        selectedMark: fs.selectedMark,
        sortOption: fs.sortOption,
      ),
    ));
  }

  void _showFilterSheet(BuildContext outerContext) {
    final cubit = outerContext.read<CatalogFilterCubit>();
    final bloc = outerContext.read<CatalogBloc>();
    showModalBottomSheet(
      context: outerContext,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(
          top: Radius.circular(AppRadius.xl),
        ),
      ),
      builder: (_) => BlocProvider.value(
        value: cubit,
        child: _FilterSheet(bloc: bloc),
      ),
    );
  }

  void _showSortSheet(BuildContext outerContext) {
    final cubit = outerContext.read<CatalogFilterCubit>();
    final bloc = outerContext.read<CatalogBloc>();
    showModalBottomSheet(
      context: outerContext,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(
          top: Radius.circular(AppRadius.xl),
        ),
      ),
      builder: (_) => BlocProvider.value(
        value: cubit,
        child: _SortSheet(bloc: bloc),
      ),
    );
  }
}

class _ChipButton extends StatelessWidget {
  final String label;
  final bool isActive;
  final VoidCallback onTap;

  const _ChipButton({
    required this.label,
    required this.isActive,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(20),
        child: Container(
          padding: const EdgeInsets.symmetric(
            horizontal: AppSpacing.md,
            vertical: 6,
          ),
          decoration: BoxDecoration(
            color: isActive
                ? AppColors.seed.withValues(alpha: 0.1)
                : AppColors.surfaceDim,
            borderRadius: BorderRadius.circular(20),
            border: isActive
                ? Border.all(color: AppColors.seed, width: 1)
                : null,
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                label,
                style: TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w500,
                  color:
                      isActive ? AppColors.seed : AppColors.textSecondary,
                ),
              ),
              const SizedBox(width: AppSpacing.xs),
              Icon(
                Icons.keyboard_arrow_down,
                size: 16,
                color:
                    isActive ? AppColors.seed : AppColors.textTertiary,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _FilterSheet extends StatelessWidget {
  final CatalogBloc bloc;

  const _FilterSheet({required this.bloc});

  @override
  Widget build(BuildContext context) {
    return BlocBuilder<CatalogFilterCubit, CatalogFilterState>(
      builder: (context, state) {
        final cubit = context.read<CatalogFilterCubit>();
        return Padding(
          padding: EdgeInsets.fromLTRB(
            AppSpacing.xl,
            AppSpacing.xl,
            AppSpacing.xl,
            AppSpacing.xl + MediaQuery.of(context).padding.bottom,
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'Filters',
                style: TextStyle(
                  fontSize: 17,
                  fontWeight: FontWeight.w700,
                  color: AppColors.textPrimary,
                ),
              ),
              const SizedBox(height: AppSpacing.lg),
              _buildDropdown(
                label: 'Brand',
                value: state.selectedBrand,
                items: state.availableBrands,
                onChanged: (v) => cubit.setBrand(v),
              ),
              const SizedBox(height: AppSpacing.md),
              _buildDropdown(
                label: 'Category',
                value: state.selectedCategory,
                items: state.availableCategories,
                onChanged: (v) => cubit.setCategory(v),
              ),
              const SizedBox(height: AppSpacing.md),
              _buildDropdown(
                label: 'Badge',
                value: state.selectedMark,
                items: state.availableMarks,
                onChanged: (v) => cubit.setMark(v),
              ),
              const SizedBox(height: AppSpacing.xl),
              Row(
                children: [
                  Expanded(
                    child: OutlinedButton(
                      onPressed: () {
                        cubit.clearAll();
                        _apply(context);
                        Navigator.pop(context);
                      },
                      style: OutlinedButton.styleFrom(
                        side: const BorderSide(color: AppColors.border),
                      ),
                      child: const Text('Clear'),
                    ),
                  ),
                  const SizedBox(width: AppSpacing.md),
                  Expanded(
                    child: ElevatedButton(
                      onPressed: () {
                        _apply(context);
                        Navigator.pop(context);
                      },
                      child: const Text('Apply'),
                    ),
                  ),
                ],
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildDropdown({
    required String label,
    required String? value,
    required List<String> items,
    required ValueChanged<String?> onChanged,
  }) {
    return DropdownButtonFormField<String>(
      initialValue: items.contains(value) ? value : null,
      decoration: InputDecoration(labelText: label),
      isExpanded: true,
      items: [
        const DropdownMenuItem(value: null, child: Text('All')),
        ...items.map((v) => DropdownMenuItem(value: v, child: Text(v))),
      ],
      onChanged: onChanged,
    );
  }

  void _apply(BuildContext context) {
    final fs = context.read<CatalogFilterCubit>().state;
    bloc.add(CatalogFiltersApplied(CatalogFiltersEntity(
      selectedBrand: fs.selectedBrand,
      selectedCategory: fs.selectedCategory,
      selectedMark: fs.selectedMark,
      sortOption: fs.sortOption,
    )));
  }
}

class _SortSheet extends StatelessWidget {
  final CatalogBloc bloc;

  const _SortSheet({required this.bloc});

  @override
  Widget build(BuildContext context) {
    return BlocBuilder<CatalogFilterCubit, CatalogFilterState>(
      builder: (context, state) {
        final cubit = context.read<CatalogFilterCubit>();
        return Padding(
          padding: EdgeInsets.fromLTRB(
            AppSpacing.xl,
            AppSpacing.xl,
            AppSpacing.xl,
            AppSpacing.xl + MediaQuery.of(context).padding.bottom,
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'Sort by',
                style: TextStyle(
                  fontSize: 17,
                  fontWeight: FontWeight.w700,
                  color: AppColors.textPrimary,
                ),
              ),
              const SizedBox(height: AppSpacing.sm),
              RadioGroup<CatalogSortOption>(
                groupValue: state.sortOption,
                onChanged: (v) {
                  if (v != null) cubit.setSortOption(v);
                },
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: CatalogSortOption.values
                      .map((opt) => RadioListTile<CatalogSortOption>(
                            value: opt,
                            title: Text(_sortLabel(opt)),
                            contentPadding: EdgeInsets.zero,
                            dense: true,
                          ))
                      .toList(),
                ),
              ),
              const SizedBox(height: AppSpacing.md),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: () {
                    final fs = cubit.state;
                    bloc.add(CatalogFiltersApplied(CatalogFiltersEntity(
                      selectedBrand: fs.selectedBrand,
                      selectedCategory: fs.selectedCategory,
                      selectedMark: fs.selectedMark,
                      sortOption: fs.sortOption,
                    )));
                    Navigator.pop(context);
                  },
                  child: const Text('Apply'),
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  String _sortLabel(CatalogSortOption opt) {
    return switch (opt) {
      CatalogSortOption.defaultOrder => 'Default',
      CatalogSortOption.priceLowToHigh => 'Price: Low to High',
      CatalogSortOption.priceHighToLow => 'Price: High to Low',
      CatalogSortOption.titleAZ => 'Title: A → Z',
    };
  }
}
