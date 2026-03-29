import 'package:flutter/material.dart';

import '../../../../core/theme/app_colors.dart';

class StoresDeliverySkeleton extends StatelessWidget {
  const StoresDeliverySkeleton({super.key});

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      physics: const NeverScrollableScrollPhysics(),
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _box(width: 100, height: 18),
          const SizedBox(height: 12),
          _card(),
          const SizedBox(height: 8),
          _card(),
          const SizedBox(height: 28),
          _box(width: 80, height: 18),
          const SizedBox(height: 12),
          _card(),
          const SizedBox(height: 8),
          _card(),
        ],
      ),
    );
  }

  Widget _box({required double width, required double height}) {
    return Container(
      width: width,
      height: height,
      decoration: BoxDecoration(
        color: AppColors.skeleton,
        borderRadius: BorderRadius.circular(8),
      ),
    );
  }

  Widget _card() {
    return Container(
      width: double.infinity,
      height: 80,
      decoration: BoxDecoration(
        color: AppColors.skeleton,
        borderRadius: BorderRadius.circular(14),
      ),
    );
  }
}
