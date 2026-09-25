import 'package:flutter/material.dart';

/// Both bundled fonts are variable (Hanken Grotesk wght 100–900, Libre Caslon
/// Text wght 400–700). Declaring weights in pubspec is not enough: Flutter
/// reaches an interpolated instance only when the TextStyle carries a matching
/// [FontVariation]. Setting `fontWeight` alone gets you the default 400 master,
/// sometimes faux-bolded by the rasteriser — which looks subtly wrong and is
/// hard to diagnose later.
///
/// So every style here sets both: `fontWeight` (for Flutter's own layout and
/// for accessibility bold-text) and `fontVariations` (for the actual shape).
abstract final class AppFonts {
  /// UI chrome — labels, buttons, titles, metadata.
  static const sans = 'HankenGrotesk';

  /// Sustained reading — the synthesis and source passages. A serif at
  /// reading sizes measurably eases long-form reading, and this app asks
  /// researchers to read paragraphs, not scan a dashboard.
  static const serif = 'LibreCaslonText';

  static const _sansMin = 100.0;
  static const _sansMax = 900.0;
  static const _serifMin = 400.0;
  static const _serifMax = 700.0;
}

/// Builds a style on the UI sans, clamping the weight to the axis range.
TextStyle sansStyle({
  double size = 14,
  double weight = 400,
  double? height,
  double? letterSpacing,
  Color? color,
  FontStyle? fontStyle,
}) {
  final w = weight.clamp(AppFonts._sansMin, AppFonts._sansMax);
  return TextStyle(
    fontFamily: AppFonts.sans,
    fontSize: size,
    height: height,
    letterSpacing: letterSpacing,
    color: color,
    fontStyle: fontStyle,
    fontWeight: _nearestWeight(w),
    fontVariations: [FontVariation('wght', w)],
  );
}

/// Builds a style on the reading serif.
TextStyle serifStyle({
  double size = 16,
  double weight = 400,
  double? height,
  double? letterSpacing,
  Color? color,
  FontStyle? fontStyle,
}) {
  final w = weight.clamp(AppFonts._serifMin, AppFonts._serifMax);
  return TextStyle(
    fontFamily: AppFonts.serif,
    fontSize: size,
    height: height,
    letterSpacing: letterSpacing,
    color: color,
    fontStyle: fontStyle,
    fontWeight: _nearestWeight(w),
    fontVariations: [FontVariation('wght', w)],
  );
}

/// Flutter still wants a discrete [FontWeight]; round to the nearest 100 so
/// layout metrics and the variable axis agree.
FontWeight _nearestWeight(double w) =>
    FontWeight.values[((w / 100).round() - 1).clamp(0, 8)];

/// The app's text scale. Sizes are deliberately few — a screen with nine
/// distinct text sizes reads as noise.
abstract final class AppTypography {
  static TextTheme textTheme() => TextTheme(
        // Display / headline — Ask screen prompt, page titles.
        headlineLarge: sansStyle(size: 30, weight: 600, height: 1.2),
        headlineSmall: sansStyle(size: 24, weight: 600, height: 1.25),

        // Titles — card headings, paper titles, app bar.
        titleLarge: sansStyle(size: 20, weight: 600, height: 1.3),
        titleMedium: sansStyle(size: 17, weight: 600, height: 1.35),
        titleSmall: sansStyle(size: 15, weight: 600, height: 1.4),

        // Body — UI copy. Long-form reading overrides to the serif locally.
        bodyLarge: sansStyle(size: 16, height: 1.5),
        bodyMedium: sansStyle(size: 14, height: 1.5),
        bodySmall: sansStyle(size: 13, height: 1.45),

        // Labels — chips, metadata, buttons.
        labelLarge: sansStyle(size: 14, weight: 600, letterSpacing: 0.1),
        labelMedium: sansStyle(size: 12, weight: 600, letterSpacing: 0.2),
        labelSmall: sansStyle(size: 11, weight: 600, letterSpacing: 0.3),
      );

  /// The synthesis paragraphs. Generous line height because this is the one
  /// place a researcher reads several hundred words without stopping.
  static TextStyle reading({Color? color}) =>
      serifStyle(size: 17, height: 1.75, color: color);

  /// A quoted source passage — same serif, slightly smaller, so the eye
  /// recognises it as the paper's voice rather than the app's.
  static TextStyle quotation({Color? color}) =>
      serifStyle(size: 15.5, height: 1.65, color: color);
}
