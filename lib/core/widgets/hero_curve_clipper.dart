import 'package:flutter/rendering.dart';

/// Clips the bottom edge of a rectangle into a subtle organic arc.
///
/// The top, left, and right edges remain straight. The bottom edge
/// uses a cubic Bézier with intentionally offset control points and
/// slightly asymmetric corner depths so the shape reads as natural
/// rather than mathematically perfect.
class HeroCurveClipper extends CustomClipper<Path> {
  /// Maximum depth of the curve (at the deeper corner).
  final double amplitude;

  const HeroCurveClipper({this.amplitude = 14.0});

  @override
  Path getClip(Size size) {
    final h = size.height;
    final w = size.width;

    // Corners sit at slightly different heights to break symmetry.
    final leftY = h - amplitude * 0.92;
    final rightY = h - amplitude;

    return Path()
      ..lineTo(0, leftY)
      ..cubicTo(
        w * 0.36, h, // cp1 — pulls the curve's apex left of center
        w * 0.64, h, // cp2 — wider right shoulder for a softer exit
        w, rightY,
      )
      ..lineTo(w, 0)
      ..close();
  }

  @override
  bool shouldReclip(HeroCurveClipper oldClipper) =>
      oldClipper.amplitude != amplitude;
}

/// Clips the top of a strip so its upper edge matches [HeroCurveClipper]'s
/// bottom curve when the strip is shifted up by [overlap] into the hero.
///
/// Use with [Transform.translate] `Offset(0, -overlap)` so the curve aligns
/// with the hero’s visible bottom edge.
class HeroContinuationClipper extends CustomClipper<Path> {
  final double amplitude;
  final double overlap;

  const HeroContinuationClipper({
    this.amplitude = 14.0,
    this.overlap = 14.0,
  });

  @override
  Path getClip(Size size) {
    final w = size.width;
    final h = size.height;
    final leftY = overlap - amplitude * 0.92;
    final rightY = overlap - amplitude;

    return Path()
      ..moveTo(0, leftY)
      ..cubicTo(
        w * 0.36,
        overlap,
        w * 0.64,
        overlap,
        w,
        rightY,
      )
      ..lineTo(w, h)
      ..lineTo(0, h)
      ..close();
  }

  @override
  bool shouldReclip(HeroContinuationClipper oldClipper) =>
      oldClipper.amplitude != amplitude || oldClipper.overlap != overlap;
}
