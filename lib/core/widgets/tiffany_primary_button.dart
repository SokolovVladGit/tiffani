import 'package:flutter/material.dart';

/// TIFFANI's primary call-to-action button.
///
/// A premium, soft, rose-accented pill button rendered as a single gradient
/// surface with no borders, shadows, or Material chrome. Depth is conveyed
/// through a tonal rose gradient only.
///
/// ## When to use
/// - Primary form submissions (cart checkout, contact requests)
/// - Primary navigation from empty/success states ("Continue shopping")
/// - Any full-screen or section-level primary action
///
/// ## When NOT to use
/// - Secondary actions (use `OutlinedButton` or text link)
/// - Destructive actions (delete, remove)
/// - Small inline controls (favorite toggle, quantity ±)
/// - Retry / error recovery (use standard `ElevatedButton`)
/// - Filter sheet actions (contextual, paired with reset)
/// - Icon-based actions (add-to-cart with icon — use `ElevatedButton.icon`)
///
/// ## States
/// - **Enabled**: full gradient, tappable.
/// - **Disabled**: pass `onPressed: null`. Renders at reduced opacity (0.45),
///   stays within TIFFANI warm visual language — no Material grey.
/// - **Loading**: set `isLoading: true`. Shows a white spinner, disables tap.
class TiffanyPrimaryButton extends StatelessWidget {
  /// Label text displayed centered in the button.
  final String label;

  /// Called when the button is tapped. Pass `null` to disable.
  final VoidCallback? onPressed;

  /// When true, shows a spinner and disables interaction.
  final bool isLoading;

  /// Button height. Defaults to 50.
  final double height;

  /// Corner radius. Defaults to 22.
  final double borderRadius;

  /// Whether the button stretches to fill available width. Defaults to true.
  final bool expand;

  const TiffanyPrimaryButton({
    super.key,
    required this.label,
    this.onPressed,
    this.isLoading = false,
    this.height = 50,
    this.borderRadius = 22,
    this.expand = true,
  });

  static const _gradient = LinearGradient(
    begin: Alignment.topCenter,
    end: Alignment.bottomCenter,
    colors: [
      Color(0xFFD79DA7),
      Color(0xFFCE929E),
      Color(0xFFC48793),
      Color(0xFFC98D97),
    ],
    stops: [0.0, 0.4, 0.75, 1.0],
  );

  static const _labelStyle = TextStyle(
    fontSize: 15,
    fontWeight: FontWeight.w600,
    color: Colors.white,
    letterSpacing: 0.3,
  );

  bool get _enabled => onPressed != null && !isLoading;

  @override
  Widget build(BuildContext context) {
    final content = isLoading
        ? const SizedBox(
            height: 20,
            width: 20,
            child: CircularProgressIndicator(
              strokeWidth: 2,
              color: Colors.white,
            ),
          )
        : Text(label, style: _labelStyle);

    Widget surface = SizedBox(
      width: expand ? double.infinity : null,
      height: height,
      child: DecoratedBox(
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(borderRadius),
          gradient: _gradient,
        ),
        child: Center(child: content),
      ),
    );

    if (!_enabled) {
      surface = Opacity(opacity: 0.45, child: surface);
    }

    return GestureDetector(
      onTap: _enabled ? onPressed : null,
      child: surface,
    );
  }
}
