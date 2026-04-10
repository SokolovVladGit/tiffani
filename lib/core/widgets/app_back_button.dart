import 'package:flutter/cupertino.dart';

import '../theme/app_colors.dart';

/// Circular back button matching the product-details hero style.
///
/// 36×36 circle, `AppColors.background` fill, chevron icon.
/// Used in app bars and overlaid navigation controls.
class AppBackButton extends StatelessWidget {
  final VoidCallback? onTap;

  const AppBackButton({super.key, this.onTap});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap ?? () => Navigator.of(context).maybePop(),
      behavior: HitTestBehavior.opaque,
      child: Container(
        width: 36,
        height: 36,
        decoration: const BoxDecoration(
          color: AppColors.background,
          shape: BoxShape.circle,
        ),
        child: const Icon(
          CupertinoIcons.chevron_back,
          size: 18,
          color: AppColors.textPrimary,
        ),
      ),
    );
  }
}
