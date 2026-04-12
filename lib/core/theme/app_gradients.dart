import 'package:flutter/material.dart';

import 'app_colors.dart';

/// Centralized gradient definitions — monochrome premium palette.
class AppGradients {
  AppGradients._();

  // ---------------------------------------------------------------------------
  // TiffanyPrimaryButton — warm mid-tone premium CTA
  // ---------------------------------------------------------------------------

  /// Clean warm-neutral graphite gradient — mid-tone, refined luxury.
  static const primaryButton = LinearGradient(
    begin: Alignment.topCenter,
    end: Alignment.bottomCenter,
    colors: [
      Color(0xFF928C86),
      Color(0xFF76716B),
    ],
  );

  // ---------------------------------------------------------------------------
  // TiffanyCreamSurface — 5 neutral tone families
  // ---------------------------------------------------------------------------

  static const creamToneCount = 5;

  /// Primary intensity — subtle warm-to-cool gray gradient families.
  /// Each is visually distinct but firmly monochrome.
  static const creamPrimary = <LinearGradient>[
    LinearGradient(
      begin: Alignment.topLeft,
      end: Alignment.bottomRight,
      colors: [Color(0xFFEAEAEA), Color(0xFFE2E2E2), Color(0xFFDDDDDD)],
    ),
    LinearGradient(
      begin: Alignment.topLeft,
      end: Alignment.bottomRight,
      colors: [Color(0xFFEDEDED), Color(0xFFE5E5E5), Color(0xFFE0E0E0)],
    ),
    LinearGradient(
      begin: Alignment.topLeft,
      end: Alignment.bottomRight,
      colors: [Color(0xFFE8E8E8), Color(0xFFE0E0E0), Color(0xFFDADADA)],
    ),
    LinearGradient(
      begin: Alignment.topLeft,
      end: Alignment.bottomRight,
      colors: [Color(0xFFEBEBEB), Color(0xFFE3E3E3), Color(0xFFDEDEDE)],
    ),
    LinearGradient(
      begin: Alignment.topLeft,
      end: Alignment.bottomRight,
      colors: [Color(0xFFEEEEEE), Color(0xFFE6E6E6), Color(0xFFE1E1E1)],
    ),
  ];

  /// Secondary intensity — lighter versions of primary.
  static const creamSecondary = <LinearGradient>[
    LinearGradient(
      begin: Alignment.topLeft,
      end: Alignment.bottomRight,
      colors: [Color(0xFFF0F0F0), Color(0xFFEAEAEA), Color(0xFFE6E6E6)],
    ),
    LinearGradient(
      begin: Alignment.topLeft,
      end: Alignment.bottomRight,
      colors: [Color(0xFFF2F2F2), Color(0xFFECECEC), Color(0xFFE8E8E8)],
    ),
    LinearGradient(
      begin: Alignment.topLeft,
      end: Alignment.bottomRight,
      colors: [Color(0xFFEFEFEF), Color(0xFFE9E9E9), Color(0xFFE4E4E4)],
    ),
    LinearGradient(
      begin: Alignment.topLeft,
      end: Alignment.bottomRight,
      colors: [Color(0xFFF1F1F1), Color(0xFFEBEBEB), Color(0xFFE7E7E7)],
    ),
    LinearGradient(
      begin: Alignment.topLeft,
      end: Alignment.bottomRight,
      colors: [Color(0xFFF3F3F3), Color(0xFFEDEDED), Color(0xFFE9E9E9)],
    ),
  ];

  /// Extremely subtle radial highlight for large primary surfaces.
  static const creamGlow = RadialGradient(
    center: Alignment(-0.5, -0.5),
    radius: 1.0,
    colors: [Color(0x1AFFFFFF), Color(0x00FFFFFF)],
  );

  // ---------------------------------------------------------------------------
  // Navigation bar
  // ---------------------------------------------------------------------------

  /// Bottom navigation capsule bar — solid white surface (shadow provides
  /// the floating definition; gradient kept for API compatibility).
  static const navBar = LinearGradient(
    begin: Alignment.topCenter,
    end: Alignment.bottomCenter,
    colors: [AppColors.navSurface, AppColors.navSurface],
  );

  // ---------------------------------------------------------------------------
  // Contacts card
  // ---------------------------------------------------------------------------

  /// Contacts card background gradient.
  static const contactsCard = LinearGradient(
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
    colors: [AppColors.contactsGradientStart, AppColors.contactsGradientEnd],
  );

  // ---------------------------------------------------------------------------
  // Region card
  // ---------------------------------------------------------------------------

  /// Delivery region card background gradient.
  static const regionCard = LinearGradient(
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
    colors: [AppColors.regionGradientStart, AppColors.regionGradientEnd],
  );
}
