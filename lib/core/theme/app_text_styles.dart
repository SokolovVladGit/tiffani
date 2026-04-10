import 'package:flutter/material.dart';

import 'app_colors.dart';

/// Semantic typography tokens for the monochrome design system.
///
/// System / Material default font family is intentionally not set.
class AppTextStyles {
  AppTextStyles._();

  // ---------------------------------------------------------------------------
  // Headlines
  // ---------------------------------------------------------------------------

  /// Home hero brand logotype (28/w800, white, letterSpacing 4).
  static const hero = TextStyle(
    fontSize: 28,
    fontWeight: FontWeight.w800,
    color: Colors.white,
    letterSpacing: 4,
    height: 1.1,
  );

  /// Info hero title, article hero title (26/w800).
  static const heroTitle = TextStyle(
    fontSize: 26,
    fontWeight: FontWeight.w800,
    color: AppColors.textPrimary,
    height: 1.15,
    letterSpacing: -0.3,
  );

  /// CTA block title, page-level section title (21-22/w800).
  static const pageTitle = TextStyle(
    fontSize: 22,
    fontWeight: FontWeight.w800,
    color: AppColors.textPrimary,
    height: 1.2,
    letterSpacing: -0.2,
  );

  // ---------------------------------------------------------------------------
  // Section headers
  // ---------------------------------------------------------------------------

  /// Section header title (17/w800).
  static const sectionTitle = TextStyle(
    fontSize: 17,
    fontWeight: FontWeight.w800,
    color: AppColors.textPrimary,
    letterSpacing: -0.2,
  );

  /// Section header "see all" action (13/w500, actionMuted).
  static const sectionAction = TextStyle(
    fontSize: 13,
    fontWeight: FontWeight.w500,
    color: AppColors.actionMuted,
    letterSpacing: 0.3,
  );

  // ---------------------------------------------------------------------------
  // Cards
  // ---------------------------------------------------------------------------

  /// Card title — product name, article title (14/w600).
  static const cardTitle = TextStyle(
    fontSize: 14,
    fontWeight: FontWeight.w600,
    color: AppColors.textPrimary,
    height: 1.3,
  );

  /// Small card title — compact product cards (12/w600).
  static const cardTitleSmall = TextStyle(
    fontSize: 12,
    fontWeight: FontWeight.w600,
    color: AppColors.textPrimary,
    height: 1.25,
  );

  // ---------------------------------------------------------------------------
  // Body text
  // ---------------------------------------------------------------------------

  /// Default body text (15/w400).
  static const body = TextStyle(
    fontSize: 15,
    color: AppColors.textSecondary,
    height: 1.4,
  );

  /// Medium-emphasis body (14/w400, secondary).
  static const bodyMedium = TextStyle(
    fontSize: 14,
    color: AppColors.textSecondary,
    height: 1.5,
  );

  /// Smaller body text for descriptions (14/w400, secondary, taller line).
  static const bodySecondary = TextStyle(
    fontSize: 14,
    color: AppColors.textSecondary,
    height: 1.6,
  );

  // ---------------------------------------------------------------------------
  // Captions / labels
  // ---------------------------------------------------------------------------

  /// Caption text — brand, category, metadata (13/w600, secondary).
  static const caption = TextStyle(
    fontSize: 13,
    fontWeight: FontWeight.w600,
    color: AppColors.textSecondary,
  );

  /// Micro text — badges, small labels, stock indicators (11/w500).
  static const micro = TextStyle(
    fontSize: 11,
    fontWeight: FontWeight.w500,
    color: AppColors.textTertiary,
    letterSpacing: 1.2,
  );

  /// Uppercase letterSpaced section label (11/w500, labelMuted).
  static const label = TextStyle(
    fontSize: 11,
    fontWeight: FontWeight.w500,
    color: AppColors.labelMuted,
    letterSpacing: 1.1,
  );

  // ---------------------------------------------------------------------------
  // Prices
  // ---------------------------------------------------------------------------

  /// Current price (16/w700).
  static const price = TextStyle(
    fontSize: 16,
    fontWeight: FontWeight.w700,
    color: AppColors.textPrimary,
  );

  /// Old / strikethrough price (12, priceOld, lineThrough).
  static const oldPrice = TextStyle(
    fontSize: 12,
    color: AppColors.priceOld,
    decoration: TextDecoration.lineThrough,
    decorationColor: AppColors.priceOld,
  );

  // ---------------------------------------------------------------------------
  // Buttons
  // ---------------------------------------------------------------------------

  /// Primary CTA button label (15/w600, white).
  static const button = TextStyle(
    fontSize: 15,
    fontWeight: FontWeight.w600,
    color: Colors.white,
    letterSpacing: 0.5,
  );

  /// Cart badge label (10/w600, white).
  static const badgeLabel = TextStyle(
    color: Colors.white,
    fontSize: 10,
    fontWeight: FontWeight.w600,
  );

  // ---------------------------------------------------------------------------
  // Error / empty state
  // ---------------------------------------------------------------------------

  /// Error / empty state message (14, secondary).
  static const errorBody = TextStyle(
    fontSize: 14,
    color: AppColors.textSecondary,
    height: 1.4,
  );
}
