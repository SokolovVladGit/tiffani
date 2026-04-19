import 'dart:ui';

import 'package:flutter/material.dart';

import '../theme/app_colors.dart';

/// Frosted-glass back button for hero/image surfaces.
///
/// Designed to overlay dark photographic content (e.g. glossary hero,
/// article cover). Uses a backdrop blur with a translucent white fill so
/// it remains legible on both light and dark imagery without competing
/// with the content beneath.
///
/// Use [AppBackButton] instead when overlaying a flat light surface.
class FrostedBackButton extends StatelessWidget {
  final VoidCallback? onTap;
  final double size;
  final Color iconColor;
  final Color fillColor;

  const FrostedBackButton({
    super.key,
    this.onTap,
    this.size = 36,
    this.iconColor = AppColors.textPrimary,
    this.fillColor = const Color(0x80FFFFFF),
  });

  @override
  Widget build(BuildContext context) {
    final hitArea = size + 8;

    return GestureDetector(
      onTap: onTap ?? () => Navigator.of(context).maybePop(),
      behavior: HitTestBehavior.opaque,
      child: SizedBox(
        width: hitArea,
        height: hitArea,
        child: Center(
          child: ClipOval(
            child: BackdropFilter(
              filter: ImageFilter.blur(sigmaX: 8, sigmaY: 8),
              child: Container(
                width: size,
                height: size,
                alignment: Alignment.center,
                color: fillColor,
                child: Icon(
                  Icons.arrow_back_ios_new_rounded,
                  size: 16,
                  color: iconColor,
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
