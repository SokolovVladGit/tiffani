import 'package:flutter/rendering.dart';

/// Clips the top edge of a rectangle into a subtle organic arc.
///
/// Bottom, left, and right edges remain straight. The top edge uses a
/// cubic Bézier that mirrors the visual language of [HeroCurveClipper],
/// creating a convex rise toward the center. The control-point offsets
/// (0.36 / 0.64) and the asymmetric corner depths are shared with the
/// hero clipper so both edges read as one design system.
///
/// Designed to visually "bookend" the hero curve: the hero's bottom
/// edge dips down; this footer's top edge rises up.
class FooterCurveClipper extends CustomClipper<Path> {
  /// Maximum height the curve's apex rises above the corner start points.
  final double amplitude;

  const FooterCurveClipper({this.amplitude = 12.0});

  @override
  Path getClip(Size size) {
    final h = size.height;
    final w = size.width;

    // Mirror the hero's asymmetry — left corner sits slightly deeper.
    final leftY = amplitude;
    final rightY = amplitude * 0.92;

    return Path()
      ..moveTo(0, leftY)
      ..cubicTo(
        w * 0.36, 0, // cp1 — matches hero's off-center pull
        w * 0.64, 0, // cp2 — wider right shoulder
        w, rightY,
      )
      ..lineTo(w, h)
      ..lineTo(0, h)
      ..close();
  }

  @override
  bool shouldReclip(FooterCurveClipper oldClipper) =>
      oldClipper.amplitude != amplitude;
}
