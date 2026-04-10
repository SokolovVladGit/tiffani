import 'package:flutter/material.dart';

import '../theme/app_gradients.dart';
import '../theme/app_shadows.dart';
import '../theme/app_text_styles.dart';

/// TIFFANI's primary call-to-action button.
///
/// A premium monochrome pill button rendered as a near-black surface
/// with white text and a subtle floating shadow.
///
/// ## When to use
/// - Primary form submissions (cart checkout, contact requests)
/// - Primary navigation from empty/success states ("Continue shopping")
/// - Any full-screen or section-level primary action
/// - Add-to-cart with optional leading [icon]
///
/// ## When NOT to use
/// - Secondary actions (use `OutlinedButton` or text link)
/// - Destructive actions (delete, remove)
/// - Small inline controls (favorite toggle, quantity ±)
/// - Retry / error recovery (use standard `ElevatedButton`)
/// - Filter sheet actions (contextual, paired with reset)
///
/// ## States
/// - **Enabled**: near-black gradient, tappable.
/// - **Disabled**: pass `onPressed: null`. Renders at reduced opacity (0.35).
/// - **Loading**: set `isLoading: true`. Shows a white spinner, disables tap.
class TiffanyPrimaryButton extends StatelessWidget {
  /// Label text displayed centered in the button.
  final String label;

  /// Called when the button is tapped. Pass `null` to disable.
  final VoidCallback? onPressed;

  /// When true, shows a spinner and disables interaction.
  final bool isLoading;

  /// Optional leading icon widget (rendered left of the label).
  final Widget? icon;

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
    this.icon,
    this.height = 50,
    this.borderRadius = 22,
    this.expand = true,
  });

  bool get _enabled => onPressed != null && !isLoading;

  @override
  Widget build(BuildContext context) {
    final Widget content;
    if (isLoading) {
      content = const SizedBox(
        height: 20,
        width: 20,
        child: CircularProgressIndicator(
          strokeWidth: 2,
          color: Colors.white,
        ),
      );
    } else if (icon != null) {
      content = Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          icon!,
          const SizedBox(width: 8),
          Text(label, style: AppTextStyles.button),
        ],
      );
    } else {
      content = Text(label, style: AppTextStyles.button);
    }

    Widget surface = SizedBox(
      width: expand ? double.infinity : null,
      height: height,
      child: DecoratedBox(
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(borderRadius),
          gradient: AppGradients.primaryButton,
          boxShadow: _enabled ? AppShadows.ctaButton : null,
        ),
        child: Center(child: content),
      ),
    );

    if (!_enabled) {
      surface = Opacity(opacity: 0.35, child: surface);
    }

    return GestureDetector(
      onTap: _enabled ? onPressed : null,
      child: surface,
    );
  }
}
