import 'package:flutter/material.dart';

import '../theme/app_colors.dart';

class AppImagePlaceholder extends StatelessWidget {
  final double width;
  final double height;
  final double iconSize;
  final BorderRadius? borderRadius;

  const AppImagePlaceholder({
    super.key,
    required this.width,
    required this.height,
    this.iconSize = 28,
    this.borderRadius,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      width: width,
      height: height,
      decoration: BoxDecoration(
        color: AppColors.surfaceDim,
        borderRadius: borderRadius,
      ),
      child: Icon(
        Icons.image_outlined,
        size: iconSize,
        color: AppColors.textTertiary,
      ),
    );
  }
}
