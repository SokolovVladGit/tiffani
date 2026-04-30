import 'package:flutter/material.dart';

import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_radius.dart';
import '../../../../core/theme/app_spacing.dart';

/// Monochrome premium brand tile.
///
/// Strict black-and-white treatment: soft off-white surface, hairline
/// border, restrained downward shadow, centered serif-like typography.
/// No tonal variation per index — each tile reads as part of one set.
class TopBrandCard extends StatefulWidget {
  final String name;
  final int index;
  final VoidCallback onTap;

  const TopBrandCard({
    super.key,
    required this.name,
    required this.index,
    required this.onTap,
  });

  static const double cardWidth = 110;

  @override
  State<TopBrandCard> createState() => _TopBrandCardState();
}

class _TopBrandCardState extends State<TopBrandCard> {
  bool _pressed = false;

  // Two near-identical warm whites form a barely-perceptible vertical
  // gradient — gives the tile a soft tactile sheen without color.
  static const _surfaceTop = Color(0xFFFAF9F6);
  static const _surfaceBottom = Color(0xFFF3F1ED);
  static const _border = Color(0x14000000);
  static const _shadow = <BoxShadow>[
    BoxShadow(
      color: Color(0x0F000000),
      blurRadius: 22,
      spreadRadius: -4,
      offset: Offset(0, 8),
    ),
  ];

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTapDown: (_) => setState(() => _pressed = true),
      onTapUp: (_) {
        setState(() => _pressed = false);
        widget.onTap();
      },
      onTapCancel: () => setState(() => _pressed = false),
      child: AnimatedScale(
        scale: _pressed ? 0.96 : 1.0,
        duration: const Duration(milliseconds: 140),
        curve: Curves.easeOut,
        child: Container(
          width: TopBrandCard.cardWidth,
          decoration: BoxDecoration(
            gradient: const LinearGradient(
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
              colors: [_surfaceTop, _surfaceBottom],
            ),
            borderRadius: BorderRadius.circular(AppRadius.xl),
            border: Border.all(color: _border, width: 0.5),
            boxShadow: _shadow,
          ),
          child: Stack(
            children: [
              // Subtle identity hairline — short, refined, centered. Reads
              // like a quiet wordmark rule, not decoration.
              Positioned(
                top: 14,
                left: 0,
                right: 0,
                child: Center(
                  child: Container(
                    width: 16,
                    height: 1,
                    color: AppColors.textPrimary.withValues(alpha: 0.22),
                  ),
                ),
              ),
              Center(
                child: Padding(
                  padding: const EdgeInsets.symmetric(
                    horizontal: AppSpacing.md,
                  ),
                  child: Text(
                    widget.name,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    textAlign: TextAlign.center,
                    style: const TextStyle(
                      fontSize: 12.5,
                      fontWeight: FontWeight.w600,
                      color: AppColors.textPrimary,
                      height: 1.3,
                      letterSpacing: 1.2,
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
