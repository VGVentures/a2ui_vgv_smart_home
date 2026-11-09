import 'package:app_ui/src/theme/app_colors.dart';
import 'package:flutter/material.dart';

/// {@template app_typography}
/// The type tokens of the panel, from the Google GenUI Demo Figma file.
///
/// Both faces are bundled with the package, so nothing is fetched at runtime.
/// The fonts are variable, so the weight is also set on the `wght` axis.
/// {@endtemplate}
abstract final class AppTypography {
  /// The UI face.
  static const String fontFamily = 'HostGrotesk';

  /// The data face, for figures and times.
  static const String monoFamily = 'RobotoMono';

  static const _package = 'app_ui';

  static TextStyle _style({
    required String family,
    required double size,
    required double lineHeight,
    required FontWeight weight,
    double letterSpacing = 0,
    Color color = AppColors.ink,
  }) {
    return TextStyle(
      fontFamily: family,
      package: _package,
      fontSize: size,
      fontWeight: weight,
      fontVariations: [FontVariation.weight(weight.value.toDouble())],
      height: lineHeight / size,
      letterSpacing: letterSpacing,
      color: color,
    );
  }

  /// A [TextStyle] in the UI face ([fontFamily]), [size] logical pixels tall on
  /// a [lineHeight] line, at [weight] with [letterSpacing] in [color].
  static TextStyle ui({
    required double size,
    required double lineHeight,
    required FontWeight weight,
    double letterSpacing = 0,
    Color color = AppColors.ink,
  }) {
    return _style(
      family: fontFamily,
      size: size,
      lineHeight: lineHeight,
      weight: weight,
      letterSpacing: letterSpacing,
      color: color,
    );
  }

  /// `display/large`.
  static TextStyle get displayLarge => ui(
    size: 88,
    lineHeight: 92,
    weight: FontWeight.w300,
    letterSpacing: -7.04,
  );

  /// `display/medium`.
  static TextStyle get displayMedium => ui(
    size: 76,
    lineHeight: 80,
    weight: FontWeight.w300,
    letterSpacing: -6.08,
  );

  /// `display/small`.
  static TextStyle get displaySmall => ui(
    size: 64,
    lineHeight: 67,
    weight: FontWeight.w300,
    letterSpacing: -5.12,
  );

  /// `headline/large`.
  static TextStyle get headlineLarge => ui(
    size: 56,
    lineHeight: 58,
    weight: FontWeight.w300,
    letterSpacing: -4.48,
  );

  /// `headline/medium`.
  static TextStyle get headlineMedium => ui(
    size: 44,
    lineHeight: 46,
    weight: FontWeight.w300,
    letterSpacing: -2.2,
  );

  /// `headline/small`.
  static TextStyle get headlineSmall => ui(
    size: 32,
    lineHeight: 36,
    weight: FontWeight.w300,
    letterSpacing: -0.96,
  );

  /// `headline/small-emphasized`.
  static TextStyle get headlineSmallEmphasized => ui(
    size: 32,
    lineHeight: 40,
    weight: FontWeight.w400,
    letterSpacing: -0.96,
  );

  /// `title/large`.
  static TextStyle get titleLarge => ui(
    size: 28,
    lineHeight: 38,
    weight: FontWeight.w400,
    letterSpacing: -0.84,
  );

  /// `title/medium`.
  static TextStyle get titleMedium => ui(
    size: 26,
    lineHeight: 32,
    weight: FontWeight.w400,
    letterSpacing: -0.78,
  );

  /// `title/small`.
  static TextStyle get titleSmall => ui(
    size: 22,
    lineHeight: 29,
    weight: FontWeight.w500,
    letterSpacing: -0.44,
  );

  /// `body/large`.
  static TextStyle get bodyLarge => ui(
    size: 18,
    lineHeight: 24,
    weight: FontWeight.w400,
    letterSpacing: -0.18,
  );

  /// `body/large-emphasized`.
  static TextStyle get bodyLargeEmphasized => ui(
    size: 20,
    lineHeight: 27,
    weight: FontWeight.w500,
    letterSpacing: -0.4,
  );

  /// `body/medium`.
  static TextStyle get bodyMedium => ui(
    size: 15,
    lineHeight: 20,
    weight: FontWeight.w400,
    letterSpacing: -0.07,
  );

  /// `label/large`.
  static TextStyle get labelLarge => ui(
    size: 18,
    lineHeight: 24,
    weight: FontWeight.w500,
    letterSpacing: -0.18,
  );

  /// `label/medium`.
  static TextStyle get labelMedium => ui(
    size: 15,
    lineHeight: 20,
    weight: FontWeight.w500,
    letterSpacing: -0.07,
  );

  /// `label/medium-emphasized`.
  static TextStyle get labelMediumEmphasized => ui(
    size: 15,
    lineHeight: 20,
    weight: FontWeight.w600,
    letterSpacing: -0.07,
  );

  /// Section headers: `title/small`.
  static TextStyle get title => titleSmall;

  /// Item titles: `label/large`.
  static TextStyle get body => labelLarge;

  /// Labels and subtitles: `body/medium` in the secondary ink.
  static TextStyle get label => bodyMedium.copyWith(color: AppColors.ink2);

  /// Chip and control labels: `label/medium`.
  static TextStyle get labelStrong => labelMedium;

  /// The Material text theme, built from the scale above.
  static TextTheme get textTheme => TextTheme(
    displayLarge: displayLarge,
    displayMedium: displayMedium,
    displaySmall: displaySmall,
    headlineLarge: headlineLarge,
    headlineMedium: headlineMedium,
    headlineSmall: headlineSmall,
    titleLarge: titleLarge,
    titleMedium: titleMedium,
    titleSmall: titleSmall,
    bodyLarge: bodyLarge,
    bodyMedium: bodyMedium,
    bodySmall: bodyMedium,
    labelLarge: labelLarge,
    labelMedium: labelMedium,
    labelSmall: labelMedium,
  );
}
