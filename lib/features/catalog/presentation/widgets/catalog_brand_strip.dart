import 'package:flutter/material.dart';

import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_radius.dart';
import '../../../../core/theme/app_spacing.dart';
import '../../../../core/widgets/tiffany_cream_surface.dart';

class CatalogBrandStrip extends StatelessWidget {
  final List<String> brands;
  final String? selectedBrand;
  final ValueChanged<String?> onBrandTap;

  const CatalogBrandStrip({
    super.key,
    required this.brands,
    required this.selectedBrand,
    required this.onBrandTap,
  });

  @override
  Widget build(BuildContext context) {
    if (brands.isEmpty) return const SizedBox.shrink();

    final items = [null, ...brands];

    return Padding(
      padding: const EdgeInsets.only(
        top: AppSpacing.sm,
        bottom: AppSpacing.sm,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          const Padding(
            padding: EdgeInsets.only(
              left: AppSpacing.lg,
              bottom: 6,
            ),
            child: Text(
              'Бренды',
              style: TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w600,
                color: AppColors.textSecondary,
              ),
            ),
          ),
          SizedBox(
            height: 32,
            child: ListView.separated(
              scrollDirection: Axis.horizontal,
              padding: const EdgeInsets.symmetric(horizontal: AppSpacing.lg),
              itemCount: items.length,
              separatorBuilder: (_, __) =>
                  const SizedBox(width: 6),
              itemBuilder: (context, index) {
                final brand = items[index];
                final isSelected = brand == selectedBrand;
                return _BrandChip(
                  label: brand ?? 'Все',
                  isSelected: isSelected,
                  index: index,
                  onTap: () => onBrandTap(brand),
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}

class _BrandChip extends StatelessWidget {
  final String label;
  final bool isSelected;
  final int index;
  final VoidCallback onTap;

  const _BrandChip({
    required this.label,
    required this.isSelected,
    required this.index,
    required this.onTap,
  });

  static const _brandSubtleColor = AppColors.chipSubtle;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: TiffanyCreamSurface(
        toneIndex: index,
        intensity: isSelected
            ? TiffanyCreamIntensity.primary
            : TiffanyCreamIntensity.subtle,
        borderRadius: AppRadius.md,
        subtleColor: _brandSubtleColor,
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 7),
        child: Text(
          label,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: TextStyle(
            fontSize: 12,
            fontWeight: isSelected ? FontWeight.w700 : FontWeight.w500,
            color: isSelected
                ? AppColors.textPrimary
                : AppColors.textSecondary,
            height: 1.3,
          ),
        ),
      ),
    );
  }
}
