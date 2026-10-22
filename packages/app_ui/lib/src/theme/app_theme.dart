import 'package:app_ui/src/theme/app_colors.dart';
import 'package:app_ui/src/theme/app_spacing.dart';
import 'package:app_ui/src/theme/app_typography.dart';
import 'package:flutter/material.dart';

/// {@template app_theme}
/// The panel theme. Light only, tuned for a landscape wall mount.
/// {@endtemplate}
abstract final class AppTheme {
  /// The light [ThemeData] of the panel, built from the [AppColors],
  /// [AppSpacing] and [AppTypography] tokens.
  static ThemeData get light {
    final colorScheme =
        ColorScheme.fromSeed(
          seedColor: AppColors.accent,
          primary: AppColors.accent,
          onPrimary: AppColors.onAccent,
        ).copyWith(
          surface: AppColors.surface,
          onSurface: AppColors.ink,
          surfaceContainerHighest: AppColors.fill,
          onSurfaceVariant: AppColors.ink2,
          outlineVariant: AppColors.line,
          error: AppColors.danger,
        );

    return ThemeData(
      useMaterial3: true,
      colorScheme: colorScheme,
      scaffoldBackgroundColor: AppColors.surface,
      textTheme: AppTypography.textTheme,
      appBarTheme: AppBarTheme(
        backgroundColor: AppColors.surface,
        foregroundColor: AppColors.ink,
        surfaceTintColor: Colors.transparent,
        elevation: 0,
        scrolledUnderElevation: 0,
        centerTitle: false,
        titleTextStyle: AppTypography.title,
      ),
      cardTheme: const CardThemeData(
        color: AppColors.surfaceRaised,
        surfaceTintColor: Colors.transparent,
        elevation: 0,
        margin: EdgeInsets.zero,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.all(
            Radius.circular(AppSpacing.cardRadius),
          ),
        ),
      ),
      dividerTheme: const DividerThemeData(
        color: AppColors.line,
        thickness: 1,
        space: 1,
      ),
      filledButtonTheme: FilledButtonThemeData(
        style: FilledButton.styleFrom(
          backgroundColor: AppColors.accent,
          foregroundColor: AppColors.onAccent,
          minimumSize: const Size(0, AppSpacing.tapTarget),
          padding: const EdgeInsets.symmetric(horizontal: AppSpacing.s6),
          textStyle: AppTypography.body,
          shape: const StadiumBorder(),
        ),
      ),
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          backgroundColor: AppColors.fill,
          foregroundColor: AppColors.ink,
          elevation: 0,
          minimumSize: const Size(0, AppSpacing.tapTarget),
          padding: const EdgeInsets.symmetric(horizontal: AppSpacing.s6),
          textStyle: AppTypography.body,
          shape: const StadiumBorder(),
        ),
      ),
      textButtonTheme: TextButtonThemeData(
        style: TextButton.styleFrom(
          foregroundColor: AppColors.ink,
          minimumSize: const Size(0, AppSpacing.tapTarget),
          textStyle: AppTypography.body,
          shape: const StadiumBorder(),
        ),
      ),
      segmentedButtonTheme: SegmentedButtonThemeData(
        style: SegmentedButton.styleFrom(
          backgroundColor: AppColors.fill,
          foregroundColor: AppColors.ink2,
          selectedBackgroundColor: AppColors.accent,
          selectedForegroundColor: AppColors.onAccent,
          side: BorderSide.none,
          textStyle: AppTypography.labelStrong,
        ),
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: AppColors.fill,
        contentPadding: const EdgeInsets.symmetric(
          horizontal: AppSpacing.s5,
          vertical: AppSpacing.s3,
        ),
        hintStyle: AppTypography.bodyMedium.copyWith(color: AppColors.ink3),
        border: _fieldBorder(),
        enabledBorder: _fieldBorder(),
        focusedBorder: _fieldBorder(color: AppColors.accent),
        errorBorder: _fieldBorder(color: AppColors.danger),
        focusedErrorBorder: _fieldBorder(color: AppColors.danger),
      ),
      progressIndicatorTheme: const ProgressIndicatorThemeData(
        color: AppColors.accent,
        linearTrackColor: AppColors.fillStrong,
        circularTrackColor: AppColors.fillStrong,
      ),
    );
  }

  static OutlineInputBorder _fieldBorder({Color color = Colors.transparent}) {
    return OutlineInputBorder(
      borderRadius: BorderRadius.circular(AppSpacing.pillRadius),
      borderSide: BorderSide(color: color),
    );
  }
}
