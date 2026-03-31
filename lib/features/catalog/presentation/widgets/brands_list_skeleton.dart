import 'package:flutter/material.dart';

import '../../../../core/theme/app_decorations.dart';
import '../../../../core/theme/app_spacing.dart';

class BrandsListSkeleton extends StatelessWidget {
  const BrandsListSkeleton({super.key});

  @override
  Widget build(BuildContext context) {
    return ListView.builder(
      physics: const NeverScrollableScrollPhysics(),
      padding: const EdgeInsets.only(bottom: AppSpacing.xxxl),
      itemCount: 4,
      itemBuilder: (context, groupIndex) {
        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(
                AppSpacing.lg,
                AppSpacing.xl,
                AppSpacing.lg,
                AppSpacing.xs,
              ),
              child: _bar(width: 16, height: 13),
            ),
            for (int i = 0; i < 3; i++)
              Padding(
                padding: const EdgeInsets.symmetric(
                  horizontal: AppSpacing.lg,
                  vertical: AppSpacing.lg,
                ),
                child: _bar(
                  width: 80.0 + (groupIndex * 20 + i * 30) % 80,
                  height: 14,
                ),
              ),
          ],
        );
      },
    );
  }

  Widget _bar({required double width, required double height}) {
    return Container(
      width: width,
      height: height,
      decoration: AppDecorations.skeleton(),
    );
  }
}
