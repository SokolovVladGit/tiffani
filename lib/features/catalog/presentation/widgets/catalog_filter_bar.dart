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

/// Opens the unified filter + sort bottom sheet.
void showCatalogFilterSheet(BuildContext context, CatalogBloc bloc) {
  final cubit = context.read<CatalogFilterCubit>();
  showModalBottomSheet(
    context: context,
    isScrollControlled: true,
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(
        top: Radius.circular(AppRadius.xl),
      ),
    ),
    builder: (_) => BlocProvider.value(
      value: cubit,
      child: _CatalogFilterSheet(bloc: bloc),
    ),
  );
}

class _CatalogFilterSheet extends StatelessWidget {
  final CatalogBloc bloc;

  const _CatalogFilterSheet({required this.bloc});

  @override
  Widget build(BuildContext context) {
    return BlocBuilder<CatalogFilterCubit, CatalogFilterState>(
      builder: (context, state) {
        final cubit = context.read<CatalogFilterCubit>();
        return SafeArea(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(
              AppSpacing.xl,
              AppSpacing.xl,
              AppSpacing.xl,
              AppSpacing.lg,
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Фильтры и сортировка',
                  style: TextStyle(
                    fontSize: 17,
                    fontWeight: FontWeight.w700,
                    color: AppColors.textPrimary,
                  ),
                ),
                const SizedBox(height: AppSpacing.lg),
                _buildDropdown(
                  label: 'Бренд',
                  value: state.selectedBrand,
                  items: state.availableBrands,
                  onChanged: (v) => cubit.setBrand(v),
                ),
                const SizedBox(height: AppSpacing.md),
                _buildDropdown(
                  label: 'Категория',
                  value: state.selectedCategory,
                  items: state.availableCategories,
                  onChanged: (v) => cubit.setCategory(v),
                ),
                const SizedBox(height: AppSpacing.md),
                _buildDropdown(
                  label: 'Метка',
                  value: state.selectedMark,
                  items: state.availableMarks,
                  onChanged: (v) => cubit.setMark(v),
                ),
                const SizedBox(height: AppSpacing.lg),
                const Text(
                  'Сортировка',
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                    color: AppColors.textPrimary,
                  ),
                ),
                const SizedBox(height: AppSpacing.xs),
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
                              title: Text(
                                _sortLabel(opt),
                                style: const TextStyle(fontSize: 14),
                              ),
                              contentPadding: EdgeInsets.zero,
                              dense: true,
                              visualDensity: VisualDensity.compact,
                            ))
                        .toList(),
                  ),
                ),
                const SizedBox(height: AppSpacing.lg),
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
                        child: const Text('Сбросить'),
                      ),
                    ),
                    const SizedBox(width: AppSpacing.md),
                    Expanded(
                      child: ElevatedButton(
                        onPressed: () {
                          _apply(context);
                          Navigator.pop(context);
                        },
                        child: const Text('Применить'),
                      ),
                    ),
                  ],
                ),
              ],
            ),
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
        const DropdownMenuItem(value: null, child: Text('Все')),
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

  static String _sortLabel(CatalogSortOption opt) {
    return switch (opt) {
      CatalogSortOption.defaultOrder => 'По умолчанию',
      CatalogSortOption.priceLowToHigh => 'Цена: по возрастанию',
      CatalogSortOption.priceHighToLow => 'Цена: по убыванию',
      CatalogSortOption.titleAZ => 'Название: А → Я',
    };
  }
}
