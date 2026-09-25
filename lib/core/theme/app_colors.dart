import 'package:flutter/material.dart';

/// Semantic colour tokens. Never reference raw hex values from widgets —
/// go through [AppColors] so light/dark stay in sync.
abstract final class AppColors {
  // Brand
  static const seed = Color(0xFF2D6A4F);

  // Verification statuses — these carry meaning, not decoration.
  static const supported = Color(0xFF2E7D32);
  static const partial = Color(0xFFB26A00);
  static const contradicted = Color(0xFFC62828);
  static const notFound = Color(0xFF6B6B6B);

  static const supportedDark = Color(0xFF81C784);
  static const partialDark = Color(0xFFFFB74D);
  static const contradictedDark = Color(0xFFE57373);
  static const notFoundDark = Color(0xFF9E9E9E);
}

/// Spacing scale. Use these instead of arbitrary numbers so rhythm stays even.
abstract final class Insets {
  static const xs = 4.0;
  static const sm = 8.0;
  static const md = 16.0;
  static const lg = 24.0;
  static const xl = 32.0;
  static const xxl = 48.0;
}

abstract final class Radii {
  static const card = 12.0;
  static const chip = 999.0;
  static const field = 14.0;
}

/// Breakpoint between the phone layout and the laptop layout.
/// Phones read results; laptops start runs and study the matrix.
const kWideBreakpoint = 840.0;

extension ContextLayout on BuildContext {
  bool get isWide => MediaQuery.sizeOf(this).width >= kWideBreakpoint;
  ThemeData get theme => Theme.of(this);
  TextTheme get text => Theme.of(this).textTheme;
  ColorScheme get colors => Theme.of(this).colorScheme;
}
