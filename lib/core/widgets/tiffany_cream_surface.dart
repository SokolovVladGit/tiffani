import 'package:flutter/material.dart';

import '../theme/app_colors.dart';
import '../theme/app_gradients.dart';

/// TIFFANI's signature premium surface style.
///
/// A core visual primitive that provides restrained, elegant surfaces using
/// subtle grayscale gradients and neutral tones. All depth is achieved through
/// tonal layering — never borders, shadows, or material elevation.
///
/// ## When to use
/// - Selectable chips (categories, brands, filters)
/// - Brand cards and discovery surfaces
/// - Soft interactive containers
/// - Any surface that needs tactile premium presence
///
/// ## When NOT to use
/// - Product images or image overlays
/// - Text-heavy content areas (articles, delivery blocks)
/// - Navigation bars or system chrome
/// - Inputs, buttons with platform conventions (use app theme instead)
///
/// ## Tone families
/// Five neutral grayscale families cycle by [toneIndex].
/// Pass the item's list index for automatic variation.
///
/// ## Usage
/// ```dart
/// TiffanyCreamSurface(
///   toneIndex: index,
///   intensity: isSelected
///       ? TiffanyCreamIntensity.primary
///       : TiffanyCreamIntensity.subtle,
///   borderRadius: AppRadius.lg,
///   padding: EdgeInsets.symmetric(horizontal: 18, vertical: 9),
///   child: Text('Label'),
/// )
/// ```

enum TiffanyCreamIntensity {
  /// Strongest grayscale gradient — visible tonal presence.
  /// Use for: primary selections, brand cards, category chips (selected).
  primary,

  /// Lighter gradient — visible but recessive.
  /// Use for: secondary selections, brand chips (selected).
  secondary,

  /// Flat neutral — background-level surface.
  /// Use for: unselected chips, soft containers.
  subtle,
}

class TiffanyCreamSurface extends StatelessWidget {
  /// Index into the 5-tone palette. Wraps automatically via modulo.
  final int toneIndex;

  /// Visual intensity of the surface.
  final TiffanyCreamIntensity intensity;

  /// Corner radius. Defaults to 14.
  final double borderRadius;

  /// Padding applied inside the surface, around [child].
  final EdgeInsetsGeometry? padding;

  /// Overlays a subtle radial highlight for extra depth on larger surfaces.
  /// Only has visible effect at [TiffanyCreamIntensity.primary].
  final bool glow;

  /// Override for the flat color used at [TiffanyCreamIntensity.subtle].
  /// Defaults to [AppColors.creamSubtle].
  final Color? subtleColor;

  final Widget child;

  const TiffanyCreamSurface({
    super.key,
    required this.toneIndex,
    this.intensity = TiffanyCreamIntensity.primary,
    this.borderRadius = 14,
    this.padding,
    this.glow = false,
    this.subtleColor,
    required this.child,
  });

  // ---------------------------------------------------------------------------
  // Static decoration builder
  // ---------------------------------------------------------------------------

  /// Returns a [BoxDecoration] without instantiating the widget.
  static BoxDecoration decoration({
    required int toneIndex,
    TiffanyCreamIntensity intensity = TiffanyCreamIntensity.primary,
    double borderRadius = 14,
    Color? subtleColor,
  }) {
    final idx = toneIndex % AppGradients.creamToneCount;
    final radius = BorderRadius.circular(borderRadius);
    return switch (intensity) {
      TiffanyCreamIntensity.primary => BoxDecoration(
          gradient: AppGradients.creamPrimary[idx],
          borderRadius: radius,
        ),
      TiffanyCreamIntensity.secondary => BoxDecoration(
          gradient: AppGradients.creamSecondary[idx],
          borderRadius: radius,
        ),
      TiffanyCreamIntensity.subtle => BoxDecoration(
          color: subtleColor ?? AppColors.creamSubtle,
          borderRadius: radius,
        ),
    };
  }

  // ---------------------------------------------------------------------------
  // Build
  // ---------------------------------------------------------------------------

  @override
  Widget build(BuildContext context) {
    final idx = toneIndex % AppGradients.creamToneCount;
    final radius = BorderRadius.circular(borderRadius);

    final Gradient? bg = switch (intensity) {
      TiffanyCreamIntensity.primary => AppGradients.creamPrimary[idx],
      TiffanyCreamIntensity.secondary => AppGradients.creamSecondary[idx],
      TiffanyCreamIntensity.subtle => null,
    };

    final Color? flat = intensity == TiffanyCreamIntensity.subtle
        ? (subtleColor ?? AppColors.creamSubtle)
        : null;

    final showGlow = glow && intensity == TiffanyCreamIntensity.primary;

    Widget content =
        padding != null ? Padding(padding: padding!, child: child) : child;

    if (showGlow) {
      content = Stack(
        children: [
          Positioned.fill(
            child: DecoratedBox(
              decoration: BoxDecoration(
                borderRadius: radius,
                gradient: AppGradients.creamGlow,
              ),
            ),
          ),
          content,
        ],
      );
    }

    return DecoratedBox(
      decoration: BoxDecoration(
        gradient: bg,
        color: flat,
        borderRadius: radius,
      ),
      child: content,
    );
  }
}
