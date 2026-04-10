import 'package:flutter/material.dart';

import '../theme/app_colors.dart';
import '../theme/app_spacing.dart';

/// A floating bottom CTA container used for primary page-level actions.
///
/// Replaces the traditional "white slab with border" pattern with a gradient
/// fade backdrop that lets the button itself be the main visual object.
///
/// Usage: pass any button widget as [child]. The bar handles safe-area
/// insets, horizontal padding, and the transparent-to-background fade.
class StickyCtaBar extends StatelessWidget {
  final Widget child;

  const StickyCtaBar({super.key, required this.child});

  @override
  Widget build(BuildContext context) {
    final bottomInset = MediaQuery.of(context).padding.bottom;

    return Container(
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          stops: [0.0, 0.35, 1.0],
          colors: [
            Color(0x00F5F5F5),
            Color(0xE8F5F5F5),
            AppColors.background,
          ],
        ),
      ),
      child: Padding(
        padding: EdgeInsets.fromLTRB(
          AppSpacing.xl,
          AppSpacing.xl,
          AppSpacing.xl,
          AppSpacing.md + bottomInset,
        ),
        child: child,
      ),
    );
  }
}
