import 'package:flutter/material.dart';

import 'app_colors.dart';

/// Centralized shadow definitions extracted from existing usage.
///
/// Each list preserves the exact values from the original inline definitions.
class AppShadows {
  AppShadows._();

  /// Card-elevated: 2-layer shadow with slightly stronger presence for
  /// monochrome surfaces that need definition against gray backgrounds.
  static const cardElevated = <BoxShadow>[
    BoxShadow(
      color: Color(0x12000000),
      blurRadius: 16,
      spreadRadius: 0,
      offset: Offset(0, 3),
    ),
    BoxShadow(
      color: AppColors.shadowSecondary,
      blurRadius: 4,
      offset: Offset(0, 1),
    ),
  ];

  /// Bottom-bar shadow on catalog detail page (upward, 2-layer).
  /// Slightly stronger for clean separation of the sticky CTA zone.
  static const pageBottomBar = <BoxShadow>[
    BoxShadow(
      color: Color(0x0E000000),
      blurRadius: 8,
      offset: Offset(0, -1),
    ),
    BoxShadow(
      color: Color(0x08000000),
      blurRadius: 24,
      offset: Offset(0, -4),
    ),
  ];

  /// Cart sticky bottom bar shadow (single upward).
  static const cartBottom = <BoxShadow>[
    BoxShadow(
      color: Color(0x0F000000),
      blurRadius: 8,
      offset: Offset(0, -2),
    ),
  ];

  /// Contacts card soft shadow (subtle downward).
  static const contactsCard = <BoxShadow>[
    BoxShadow(
      color: Color(0x08000000),
      blurRadius: 20,
      offset: Offset(0, 4),
    ),
  ];

  /// Primary CTA button — subtle downward shadow for floating feel.
  static const ctaButton = <BoxShadow>[
    BoxShadow(
      color: Color(0x28000000),
      blurRadius: 16,
      spreadRadius: -2,
      offset: Offset(0, 6),
    ),
    BoxShadow(
      color: Color(0x0A000000),
      blurRadius: 4,
      offset: Offset(0, 2),
    ),
  ];

  /// Bottom navigation capsule bar — soft ambient shadow for floating effect.
  static const navBar = <BoxShadow>[
    BoxShadow(
      color: Color(0x14000000),
      blurRadius: 20,
      spreadRadius: 0,
      offset: Offset(0, 4),
    ),
    BoxShadow(
      color: Color(0x08000000),
      blurRadius: 6,
      offset: Offset(0, 1),
    ),
  ];
}
