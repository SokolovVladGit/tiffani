import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_radius.dart';
import '../../../../core/theme/app_spacing.dart';
import '../../domain/entities/filter_state.dart';
import '../cubit/filter_cubit.dart';

const _filterOptions = <String, List<String>>{
  'skin_type': ['dry', 'oily', 'combination', 'sensitive'],
  'effect': ['hydrating', 'soothing', 'anti-aging'],
  'volume': ['30ml', '50ml', '100ml'],
};

const _sectionLabels = <String, String>{
  'skin_type': 'Skin Type',
  'effect': 'Effect',
  'volume': 'Volume',
};

void showFilterBottomSheet(
  BuildContext context,
  FilterCubit cubit, {
  VoidCallback? onApply,
}) {
  showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(
        top: Radius.circular(AppRadius.xl),
      ),
    ),
    backgroundColor: AppColors.surface,
    builder: (_) => BlocProvider.value(
      value: cubit,
      child: _FilterSheetContent(onApply: onApply),
    ),
  );
}

class _FilterSheetContent extends StatelessWidget {
  final VoidCallback? onApply;

  const _FilterSheetContent({this.onApply});

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(
          AppSpacing.xl,
          AppSpacing.md,
          AppSpacing.xl,
          AppSpacing.lg,
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Center(
              child: Container(
                width: 36,
                height: 4,
                decoration: BoxDecoration(
                  color: AppColors.border,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
            ),
            const SizedBox(height: AppSpacing.lg),
            const Text(
              'Filters',
              style: TextStyle(
                fontSize: 17,
                fontWeight: FontWeight.w700,
                color: AppColors.textPrimary,
              ),
            ),
            const SizedBox(height: AppSpacing.lg),
            BlocBuilder<FilterCubit, FilterState>(
              builder: (context, state) {
                return Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    for (final entry in _filterOptions.entries) ...[
                      _SectionTitle(
                        text: _sectionLabels[entry.key] ?? entry.key,
                      ),
                      const SizedBox(height: AppSpacing.sm),
                      Wrap(
                        spacing: AppSpacing.sm,
                        runSpacing: 6,
                        children: entry.value.map((value) {
                          final selected =
                              state.isSelected(entry.key, value);
                          return FilterChip(
                            label: Text(value),
                            selected: selected,
                            onSelected: (_) => context
                                .read<FilterCubit>()
                                .toggle(entry.key, value),
                            selectedColor: AppColors.badgeSurface,
                            checkmarkColor: AppColors.seed,
                            side: BorderSide(
                              color: selected
                                  ? AppColors.seed
                                  : AppColors.border,
                            ),
                            labelStyle: TextStyle(
                              fontSize: 13,
                              color: selected
                                  ? AppColors.seed
                                  : AppColors.textPrimary,
                            ),
                            shape: RoundedRectangleBorder(
                              borderRadius:
                                  BorderRadius.circular(AppRadius.sm),
                            ),
                          );
                        }).toList(),
                      ),
                      const SizedBox(height: AppSpacing.lg),
                    ],
                  ],
                );
              },
            ),
            const SizedBox(height: AppSpacing.sm),
            Row(
              children: [
                Expanded(
                  child: OutlinedButton(
                    onPressed: () {
                      context.read<FilterCubit>().clear();
                    },
                    style: OutlinedButton.styleFrom(
                      side: const BorderSide(color: AppColors.border),
                      shape: RoundedRectangleBorder(
                        borderRadius:
                            BorderRadius.circular(AppRadius.md),
                      ),
                      padding: const EdgeInsets.symmetric(
                        vertical: AppSpacing.lg,
                      ),
                    ),
                    child: const Text(
                      'Clear',
                      style: TextStyle(color: AppColors.textSecondary),
                    ),
                  ),
                ),
                const SizedBox(width: AppSpacing.md),
                Expanded(
                  child: ElevatedButton(
                    onPressed: () {
                      Navigator.pop(context);
                      onApply?.call();
                    },
                    child: const Text('Apply'),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
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
        fontSize: 14,
        fontWeight: FontWeight.w600,
        color: AppColors.textPrimary,
      ),
    );
  }
}
