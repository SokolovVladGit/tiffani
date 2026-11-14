import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';

import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_radius.dart';
import '../../../../core/theme/app_spacing.dart';
import '../../../../core/widgets/app_image_placeholder.dart';

const catalogGalleryStripKey = Key('catalog-gallery-strip');
const catalogGalleryFallbackKey = Key('catalog-gallery-fallback');

class CatalogGalleryMainImage extends StatelessWidget {
  final String? url;
  final double height;

  const CatalogGalleryMainImage({
    super.key,
    required this.url,
    required this.height,
  });

  @override
  Widget build(BuildContext context) {
    if (url != null && url!.isNotEmpty) {
      return CachedNetworkImage(
        imageUrl: url!,
        width: double.infinity,
        height: height,
        fit: BoxFit.contain,
        placeholder: (_, _) => SizedBox(
          width: double.infinity,
          height: height,
        ),
        errorWidget: (_, _, _) => _fallback(),
      );
    }
    return _fallback();
  }

  Widget _fallback() {
    return AppImagePlaceholder(
      key: catalogGalleryFallbackKey,
      width: double.infinity,
      height: height,
      iconSize: 48,
    );
  }
}

/// Horizontal thumbnails. Hidden when the gallery has a single image.
class CatalogGalleryThumbnails extends StatelessWidget {
  final List<String> urls;
  final int selectedIndex;
  final ValueChanged<int> onSelected;

  const CatalogGalleryThumbnails({
    super.key,
    required this.urls,
    required this.selectedIndex,
    required this.onSelected,
  });

  static const double _size = 48;

  @override
  Widget build(BuildContext context) {
    if (urls.length <= 1) return const SizedBox.shrink();
    return Container(
      key: catalogGalleryStripKey,
      width: double.infinity,
      color: AppColors.surface,
      padding: const EdgeInsets.only(
        top: AppSpacing.sm,
        bottom: AppSpacing.md,
      ),
      child: SizedBox(
        height: _size + 4,
        child: ListView.separated(
          scrollDirection: Axis.horizontal,
          padding: const EdgeInsets.symmetric(horizontal: AppSpacing.xl),
          itemCount: urls.length,
          separatorBuilder: (_, _) => const SizedBox(width: AppSpacing.md),
          itemBuilder: (context, index) {
            final isSelected = index == selectedIndex;
            return GestureDetector(
              key: ValueKey('catalog-thumb-$index'),
              onTap: () => onSelected(index),
              child: AnimatedScale(
                scale: isSelected ? 1.04 : 1.0,
                duration: const Duration(milliseconds: 180),
                child: AnimatedOpacity(
                  opacity: isSelected ? 1.0 : 0.65,
                  duration: const Duration(milliseconds: 180),
                  child: AnimatedContainer(
                    duration: const Duration(milliseconds: 180),
                    width: _size,
                    height: _size,
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(AppRadius.sm),
                      border: Border.all(
                        color: isSelected
                            ? AppColors.seed.withValues(alpha: 0.4)
                            : Colors.transparent,
                        width: 1,
                      ),
                    ),
                    child: ClipRRect(
                      borderRadius: BorderRadius.circular(AppRadius.sm - 1),
                      child: CachedNetworkImage(
                        imageUrl: urls[index],
                        width: _size,
                        height: _size,
                        fit: BoxFit.contain,
                        placeholder: (_, _) => const SizedBox.shrink(),
                        errorWidget: (_, _, _) => AppImagePlaceholder(
                          width: _size,
                          height: _size,
                        ),
                      ),
                    ),
                  ),
                ),
              ),
            );
          },
        ),
      ),
    );
  }
}
