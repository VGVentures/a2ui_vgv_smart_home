import 'package:app_ui/src/theme/app_colors.dart';
import 'package:flutter/material.dart';

/// {@template app_tone}
/// The color of a card, chosen by the kind of device or message.
///
/// A closed set that mirrors the catalog's `tone` enum: the model never sends
/// colors. Each tone is a wash from the top right of the card over white.
/// {@endtemplate}
enum AppTone {
  /// White, no wash.
  neutral(wash: null, ink: AppColors.ink, accent: AppColors.accent),

  /// Scenes, lights, countdowns, blinds.
  lighting(
    wash: AppColors.brandYellow100,
    ink: AppColors.brandYellow300,
    accent: AppColors.brandYellow200,
  ),

  /// The car and the energy meter.
  energy(
    wash: AppColors.brandGreen100,
    ink: AppColors.brandGreen300,
    accent: AppColors.brandGreen300,
  ),

  /// Thermostats and heat.
  climate(
    wash: AppColors.brandOrange100,
    ink: AppColors.brandOrange300,
    accent: AppColors.brandOrange200,
  ),

  /// Locks, garage, doorbell.
  security(
    wash: AppColors.brandBlue100,
    ink: AppColors.brandBlue300,
    accent: AppColors.brandBlue200,
  ),

  /// Outside weather.
  weather(
    wash: AppColors.brandAqua100,
    ink: AppColors.brandAqua300,
    accent: AppColors.brandAqua200,
  );

  /// {@macro app_tone}
  const AppTone({required this.wash, required this.ink, required this.accent});

  /// The wash color, or null when the card stays white.
  final Color? wash;

  /// Text and icon color that reads on [wash].
  final Color ink;

  /// The saturated color, for switches and icon bubbles.
  final Color accent;

  /// The tone named [name], or [fallback] when it is null or unknown.
  static AppTone byName(String? name, {AppTone fallback = neutral}) {
    for (final tone in values) {
      if (tone.name == name) return tone;
    }
    return fallback;
  }

  /// The decoration painted over the card surface, or null for [neutral].
  Gradient? get gradient {
    final wash = this.wash;
    if (wash == null) return null;
    return RadialGradient(
      center: Alignment.topRight,
      radius: 1.3,
      colors: [wash, wash.withValues(alpha: 0)],
    );
  }
}
