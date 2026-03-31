import 'package:flutter/material.dart';

import '../../../../core/theme/app_decorations.dart';
import '../../../../core/theme/app_radius.dart';
import '../../../../core/theme/app_spacing.dart';

class CartListSkeleton extends StatelessWidget {
  const CartListSkeleton({super.key});

  @override
  Widget build(BuildContext context) {
    return ListView.builder(
      physics: const NeverScrollableScrollPhysics(),
      padding: const EdgeInsets.only(
        top: AppSpacing.xs,
        bottom: AppSpacing.lg,
      ),
      itemCount: 3,
      itemBuilder: (context, index) {
        return Container(
          margin: const EdgeInsets.symmetric(
            horizontal: AppSpacing.lg,
            vertical: AppSpacing.xs,
          ),
          padding: const EdgeInsets.all(AppSpacing.md),
          decoration: AppDecorations.cardSoft(),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                width: 72,
                height: 72,
                decoration: AppDecorations.skeleton(radius: AppRadius.md),
              ),
              const SizedBox(width: AppSpacing.md),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _bar(height: 14),
                    const SizedBox(height: AppSpacing.xs),
                    _bar(width: 100, height: 14),
                    const SizedBox(height: AppSpacing.xs),
                    _bar(width: 70, height: 12),
                    const SizedBox(height: AppSpacing.md),
                    Row(
                      children: [
                        _bar(width: 60, height: 15),
                        const Spacer(),
                        _bar(width: 80, height: 28),
                      ],
                    ),
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
