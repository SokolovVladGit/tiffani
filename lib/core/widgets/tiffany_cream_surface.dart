import 'package:flutter/material.dart';

/// TIFFANI's signature soft premium surface style.
///
/// A core visual primitive that provides creamy, airy, tactile surfaces using
/// pastel gradients and warm neutral tones. All depth is achieved through
/// gradient and tonal layering — never borders, shadows, or material elevation.
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
/// Five pastel families cycle by [toneIndex]:
/// 0 = rose, 1 = lavender, 2 = peach, 3 = mauve, 4 = purple.
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
  /// Full pastel gradient — strongest tactile presence.
  /// Use for: primary selections, Home brand cards, category chips (selected).
  primary,

  /// Softer gradient (~70-80% of primary range) — visible but recessive.
  /// Use for: secondary selections, brand chips (selected).
  secondary,

  /// Flat warm neutral — background-level surface.
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

  /// Overlays a subtle radial glow for extra depth on larger surfaces.
  /// Only has visible effect at [TiffanyCreamIntensity.primary].
  final bool glow;

  /// Override for the flat color used at [TiffanyCreamIntensity.subtle].
  /// Defaults to [defaultSubtleColor].
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
  // Palette — 5 pastel families: rose, lavender, peach, mauve, purple
  // ---------------------------------------------------------------------------

  static const toneCount = 5;

  /// Primary intensity — full pastel 3-stop gradients.
  static const primaryGradients = <LinearGradient>[
    LinearGradient(
      begin: Alignment.topLeft,
      end: Alignment.bottomRight,
      colors: [Color(0xFFF5E6EA), Color(0xFFF0D5DC), Color(0xFFEDD0D8)],
    ),
    LinearGradient(
      begin: Alignment.topLeft,
      end: Alignment.bottomRight,
      colors: [Color(0xFFEDE5F5), Color(0xFFE3DAF0), Color(0xFFDDD2EC)],
    ),
    LinearGradient(
      begin: Alignment.topLeft,
      end: Alignment.bottomRight,
      colors: [Color(0xFFF7E8E0), Color(0xFFF2DDD2), Color(0xFFF0D5C8)],
    ),
    LinearGradient(
      begin: Alignment.topLeft,
      end: Alignment.bottomRight,
      colors: [Color(0xFFF0E0EB), Color(0xFFE8D4E2), Color(0xFFE2CCDB)],
    ),
    LinearGradient(
      begin: Alignment.topLeft,
      end: Alignment.bottomRight,
      colors: [Color(0xFFE8E4F2), Color(0xFFDED8EC), Color(0xFFD6D0E6)],
    ),
  ];

  /// Secondary intensity — same hues, ~4-6pt lighter per channel.
  static const secondaryGradients = <LinearGradient>[
    LinearGradient(
      begin: Alignment.topLeft,
      end: Alignment.bottomRight,
      colors: [Color(0xFFF7EBED), Color(0xFFF4DDE3), Color(0xFFF1D9DF)],
    ),
    LinearGradient(
      begin: Alignment.topLeft,
      end: Alignment.bottomRight,
      colors: [Color(0xFFF0E9F7), Color(0xFFE8E0F3), Color(0xFFE3DAEF)],
    ),
    LinearGradient(
      begin: Alignment.topLeft,
      end: Alignment.bottomRight,
      colors: [Color(0xFFF9ECE5), Color(0xFFF5E2D9), Color(0xFFF3DCD1)],
    ),
    LinearGradient(
      begin: Alignment.topLeft,
      end: Alignment.bottomRight,
      colors: [Color(0xFFF3E5EE), Color(0xFFECDBE7), Color(0xFFE7D4E1)],
    ),
    LinearGradient(
      begin: Alignment.topLeft,
      end: Alignment.bottomRight,
      colors: [Color(0xFFECE8F4), Color(0xFFE3DEF0), Color(0xFFDDD8EB)],
    ),
  ];

  /// Default flat color for subtle intensity.
  static const defaultSubtleColor = Color(0xFFF0EBEE);

  /// Radial glow overlay for larger primary surfaces.
  static const glowOverlay = RadialGradient(
    center: Alignment(-0.5, -0.5),
    radius: 1.0,
    colors: [Color(0x4DFFFFFF), Color(0x00FFFFFF)],
  );

  // ---------------------------------------------------------------------------
  // Static decoration builder
  // ---------------------------------------------------------------------------

  /// Returns a [BoxDecoration] without instantiating the widget.
  /// Useful for custom layouts that need the decoration directly.
  static BoxDecoration decoration({
    required int toneIndex,
    TiffanyCreamIntensity intensity = TiffanyCreamIntensity.primary,
    double borderRadius = 14,
    Color? subtleColor,
  }) {
    final idx = toneIndex % toneCount;
    final radius = BorderRadius.circular(borderRadius);
    return switch (intensity) {
      TiffanyCreamIntensity.primary => BoxDecoration(
          gradient: primaryGradients[idx],
          borderRadius: radius,
        ),
      TiffanyCreamIntensity.secondary => BoxDecoration(
          gradient: secondaryGradients[idx],
          borderRadius: radius,
        ),
      TiffanyCreamIntensity.subtle => BoxDecoration(
          color: subtleColor ?? defaultSubtleColor,
          borderRadius: radius,
        ),
    };
  }

  // ---------------------------------------------------------------------------
  // Build
  // ---------------------------------------------------------------------------

  @override
  Widget build(BuildContext context) {
    final idx = toneIndex % toneCount;
    final radius = BorderRadius.circular(borderRadius);

    final Gradient? bg = switch (intensity) {
      TiffanyCreamIntensity.primary => primaryGradients[idx],
      TiffanyCreamIntensity.secondary => secondaryGradients[idx],
      TiffanyCreamIntensity.subtle => null,
    };

    final Color? flat = intensity == TiffanyCreamIntensity.subtle
        ? (subtleColor ?? defaultSubtleColor)
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
                gradient: glowOverlay,
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
