import 'package:flutter/material.dart';

import '../../../../core/theme/app_decorations.dart';
import '../../../../core/theme/app_radius.dart';
import '../../../../core/theme/app_spacing.dart';

class CatalogListSkeleton extends StatelessWidget {
  const CatalogListSkeleton({super.key});

  static const double _imageSize = 108;

  @override
  Widget build(BuildContext context) {
    return ListView.builder(
      itemCount: 6,
      physics: const NeverScrollableScrollPhysics(),
      padding: const EdgeInsets.only(
        top: AppSpacing.xs,
        bottom: AppSpacing.lg,
      ),
      itemBuilder: (context, index) {
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
      },
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
