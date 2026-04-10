import 'package:flutter/material.dart';

class AppColors {
  AppColors._();

  /// Primary accent — used for focused inputs, active selection indicators,
  /// elevated buttons, and badges. Pure black in monochrome.
  static const Color seed = Color(0xFF111111);

  static const Color background = Color(0xFFF5F5F5);
  static const Color surface = Color(0xFFFFFFFF);
  static const Color surfaceDim = Color(0xFFEEEEEE);

  static const Color textPrimary = Color(0xFF111111);
  static const Color textSecondary = Color(0xFF6B6B6B);
  static const Color textTertiary = Color(0xFFA0A0A0);

  static const Color border = Color(0xFFE0E0E0);
  static const Color divider = Color(0xFFF0F0F0);

  /// Badge background — black for high-contrast monochrome badges.
  static const Color badge = Color(0xFF111111);
  static const Color badgeSurface = Color(0xFFF0F0F0);

  /// Discount / sale — expressed via dark fill, not color.
  static const Color discount = Color(0xFF111111);

  static const Color priceOld = Color(0xFF999999);

  static const Color skeleton = Color(0xFFE8E8E8);
  static const Color surfaceWarm = Color(0xFFFAFAFA);

  /// Stock available — dark gray (readable without green).
  static const Color stockAvailable = Color(0xFF444444);

  /// Stock limited — medium gray (readable without amber).
  static const Color stockLimited = Color(0xFF888888);

  /// Sale badge surface — light gray fill with dark text.
  static const Color saleBadgeSurface = Color(0xFFF0F0F0);

  // ---------------------------------------------------------------------------
  // Interaction / accent tones
  // ---------------------------------------------------------------------------

  /// Action color for tappable links and interactive highlights.
  static const Color action = Color(0xFF333333);

  /// Section-header "see all" action text and chevron.
  static const Color actionMuted = Color(0xFF888888);

  // ---------------------------------------------------------------------------
  // Neutral tones (content)
  // ---------------------------------------------------------------------------

  /// Near-black used for delivery / dense body text.
  static const Color textDense = Color(0xFF222222);

  /// Muted label for delivery section group labels.
  static const Color labelMuted = Color(0xFF999999);

  /// Indicator for gallery dots and carousel controls.
  static const Color indicator = Color(0xFFAAAAAA);

  /// Placeholder / hint text inside form fields.
  static const Color inputHint = Color(0xFFB0B0B0);

  // ---------------------------------------------------------------------------
  // Shell / navigation tones
  // ---------------------------------------------------------------------------

  /// Bottom nav inactive icon/label color.
  static const Color navInactive = Color(0xFF999999);

  /// Bottom nav active pill background.
  static const Color navActivePill = Color(0xFFD9D9D9);

  /// Bottom nav container surface (pure white for contrast against scaffold).
  static const Color navSurface = Color(0xFFFFFFFF);

  /// Bottom nav container border.
  static const Color navBorder = Color(0xFFE8E8E8);

  // ---------------------------------------------------------------------------
  // Surfaces (contextual)
  // ---------------------------------------------------------------------------

  /// Form field fill.
  static const Color inputFill = Color(0xFFF3F3F3);

  /// CTA block background.
  static const Color ctaSurface = Color(0xFFFAFAFA);

  /// Delivery note badge background.
  static const Color deliveryNoteSurface = Color(0xFFEEEEEE);

  /// No-image store card background.
  static const Color storeSurface = Color(0xFFF5F5F5);

  /// Region card gradient start.
  static const Color regionGradientStart = Color(0xFFFAFAFA);

  /// Region card gradient end.
  static const Color regionGradientEnd = Color(0xFFF5F5F5);

  /// Contacts card gradient start.
  static const Color contactsGradientStart = Color(0xFFFCFCFC);

  /// Contacts card gradient end.
  static const Color contactsGradientEnd = Color(0xFFF7F7F7);

  /// Bottom nav bar gradient start.
  static const Color navBarGradientStart = Color(0xFFF5F5F5);

  /// Bottom nav bar gradient end.
  static const Color navBarGradientEnd = Color(0xFFEEEEEE);

  /// Chip unselected subtle background.
  static const Color chipSubtle = Color(0xFFEEEEEE);

  // ---------------------------------------------------------------------------
  // Footer (dark surface)
  // ---------------------------------------------------------------------------

  /// Footer background — near-black.
  static const Color footerSurface = Color(0xFF141414);

  /// Footer primary text — off-white.
  static const Color footerTextPrimary = Color(0xFFF0F0F0);

  /// Footer secondary text — muted gray on dark.
  static const Color footerTextSecondary = Color(0xFF999999);

  /// Footer group label — dimmed letterSpaced uppercase.
  static const Color footerLabel = Color(0xFF666666);

  /// Footer tappable link text — bright on dark for emphasis.
  static const Color footerAction = Color(0xFFDDDDDD);

  /// Footer thin divider between groups.
  static const Color footerDivider = Color(0xFF2C2C2C);

  /// Footer icon tint.
  static const Color footerIcon = Color(0xFF777777);

  /// Footer watermark text.
  static const Color footerWatermark = Color(0xFF333333);

  // ---------------------------------------------------------------------------
  // Shadow tones
  // ---------------------------------------------------------------------------

  /// Card-elevated primary shadow.
  static const Color shadowPrimary = Color(0x0D000000);

  /// Card-elevated secondary (tight) shadow.
  static const Color shadowSecondary = Color(0x06000000);

  // ---------------------------------------------------------------------------
  // Surface palette defaults (used by TiffanyCreamSurface)
  // ---------------------------------------------------------------------------

  /// Default flat color for TiffanyCreamSurface subtle intensity.
  static const Color creamSubtle = Color(0xFFF0F0F0);
}
