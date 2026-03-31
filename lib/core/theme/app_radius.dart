import 'package:flutter/material.dart';

class AppRadius {
  AppRadius._();

  /// Badges, small chips (4)
  static const double xs = 4;

  /// Controls, quantity chips, filter chips (8)
  static const double sm = 8;

  /// Inputs, buttons, horizontal cards, bottom sheet top (12)
  static const double md = 12;

  /// Product cards, cart tiles, form containers (14)
  static const double lg = 14;

  /// Bottom sheets, brand cards (16)
  static const double xl = 16;

  /// Content overlay surfaces (20)
  static const double xxl = 20;

  static BorderRadius circular(double radius) => BorderRadius.circular(radius);
}
