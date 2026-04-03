import 'package:flutter/material.dart';

import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_radius.dart';
import '../../../../core/theme/app_spacing.dart';
import '../../../../core/widgets/tiffany_cream_surface.dart';

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
        scale: _pressed ? 0.97 : 1.0,
        duration: const Duration(milliseconds: 120),
        curve: Curves.easeOut,
        child: SizedBox(
          width: TopBrandCard.cardWidth,
          child: TiffanyCreamSurface(
            toneIndex: widget.index,
            intensity: TiffanyCreamIntensity.primary,
            borderRadius: AppRadius.xl,
            glow: true,
            child: Center(
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
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                    color: AppColors.textPrimary,
                    height: 1.3,
                    letterSpacing: 0.5,
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
