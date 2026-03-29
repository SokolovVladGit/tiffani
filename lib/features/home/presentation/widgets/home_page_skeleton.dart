import 'package:flutter/material.dart';

import '../../../../core/theme/app_colors.dart';

class HomePageSkeleton extends StatelessWidget {
  const HomePageSkeleton({super.key});

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      physics: const NeverScrollableScrollPhysics(),
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _box(width: 200, height: 22),
          const SizedBox(height: 8),
          _box(width: 260, height: 14),
          const SizedBox(height: 24),
          _box(width: double.infinity, height: 44),
          const SizedBox(height: 28),
          _box(width: 120, height: 18),
          const SizedBox(height: 12),
          SizedBox(
            height: 180,
            child: ListView.separated(
              scrollDirection: Axis.horizontal,
              physics: const NeverScrollableScrollPhysics(),
              itemCount: 3,
              separatorBuilder: (_, _) => const SizedBox(width: 10),
              itemBuilder: (_, _) => _box(width: 140, height: 180),
            ),
          ),
          const SizedBox(height: 28),
          _box(width: 100, height: 18),
          const SizedBox(height: 12),
          SizedBox(
            height: 180,
            child: ListView.separated(
              scrollDirection: Axis.horizontal,
              physics: const NeverScrollableScrollPhysics(),
              itemCount: 3,
              separatorBuilder: (_, _) => const SizedBox(width: 10),
              itemBuilder: (_, _) => _box(width: 140, height: 180),
            ),
          ),
        ],
      ),
    );
  }

  Widget _box({required double height, double? width}) {
    return Container(
      width: width,
      height: height,
      decoration: BoxDecoration(
        color: AppColors.skeleton,
        borderRadius: BorderRadius.circular(10),
      ),
    );
  }
}
