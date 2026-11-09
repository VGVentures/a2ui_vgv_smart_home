import 'package:flutter/material.dart';

/// {@template app_colors}
/// The color tokens of the panel, from the Google GenUI Demo Figma file.
///
/// The `brand*` values are the raw palette (`brand/<hue>/<step>` in Figma).
/// The rest are the semantic roles the widgets use. Every color in the app
/// comes from here, so swap a value and the whole panel follows.
/// {@endtemplate}
abstract final class AppColors {
  /// `brand/neutral/000`.
  static const brandNeutral000 = Color(0xFFFFFFFF);

  /// `brand/neutral/100`.
  static const brandNeutral100 = Color(0xFFF6F7FC);

  /// `brand/neutral/200`.
  static const brandNeutral200 = Color(0xFFCBD0DB);

  /// `brand/neutral/300`.
  static const brandNeutral300 = Color(0xFF838998);

  /// `brand/neutral/400`.
  static const brandNeutral400 = Color(0xFF5C6271);

  /// `brand/blue/100`.
  static const brandBlue100 = Color(0xFFDEE7FF);

  /// `brand/blue/200`.
  static const brandBlue200 = Color(0xFF2E56FF);

  /// `brand/blue/300`.
  static const brandBlue300 = Color(0xFF020F30);

  /// `brand/aqua/100`.
  static const brandAqua100 = Color(0xFFDFF7FF);

  /// `brand/aqua/200`.
  static const brandAqua200 = Color(0xFF3FCFFF);

  /// `brand/aqua/300`.
  static const brandAqua300 = Color(0xFF004C65);

  /// `brand/green/100`.
  static const brandGreen100 = Color(0xFFE6FFE6);

  /// `brand/green/200`.
  static const brandGreen200 = Color(0xFF7DFF7D);

  /// `brand/green/300`.
  static const brandGreen300 = Color(0xFF025002);

  /// `brand/orange/100`.
  static const brandOrange100 = Color(0xFFFEE5D9);

  /// `brand/orange/200`.
  static const brandOrange200 = Color(0xFFF07239);

  /// `brand/orange/300`.
  static const brandOrange300 = Color(0xFF462110);

  /// `brand/yellow/100`.
  static const brandYellow100 = Color(0xFFFFEBC7);

  /// `brand/yellow/200`.
  static const brandYellow200 = Color(0xFFEBB727);

  /// `brand/yellow/300`.
  static const brandYellow300 = Color(0xFF674C00);

  /// `brand/purple/100`.
  static const brandPurple100 = Color(0xFFEDDAFF);

  /// `brand/purple/200`.
  static const brandPurple200 = Color(0xFF9261FE);

  /// `brand/purple/300`.
  static const brandPurple300 = Color(0xFF341C6A);

  /// `brand/magenta/100`.
  static const brandMagenta100 = Color(0xFFF4CCF3);

  /// `brand/magenta/200`.
  static const brandMagenta200 = Color(0xFFEE6EEC);

  /// `brand/magenta/300`.
  static const brandMagenta300 = Color(0xFF630E61);

  /// The single brand accent.
  static const Color accent = brandBlue200;

  /// A darker accent, for text that needs contrast on a tint.
  static const Color accentInk = brandBlue300;

  /// A soft accent tint, for accent-washed fills.
  static const Color accentSoft = brandBlue100;

  /// Content drawn on top of the ink fill (`primary/on-primary`).
  static const Color onPrimary = Color(0xFFF6F5F2);

  /// Content drawn on top of [accent].
  static const Color onAccent = brandNeutral000;

  /// Healthy, done, on track.
  static const Color success = brandGreen300;

  /// A lighter [success] for what glows or sits on a light surface: the
  /// completed check, its border and the light behind it.
  static const Color successLight = Color(0xFF34C759);

  /// A soft [success] tint.
  static const Color successSoft = brandGreen100;

  /// Needs attention soon.
  static const Color warning = brandYellow200;

  /// A soft [warning] tint.
  static const Color warningSoft = brandYellow100;

  /// Needs attention now.
  static const Color danger = brandOrange200;

  /// A soft [danger] tint.
  static const Color dangerSoft = brandOrange100;

  /// The raised card surface (`color/surfaces/Surface`).
  static const Color surfaceRaised = brandNeutral000;

  /// The page background behind every screen (`semantic/background`).
  static const Color surface = brandNeutral100;

  /// A borderless fill for chips and inline surfaces.
  static const Color fill = brandNeutral200;

  /// A warm beige fill for pills and buttons that sit on a white card.
  static const Color fillWarm = Color(0xFFEFEDE8);

  /// A slightly darker warm fill (`surface/surface-container-high`).
  static const Color surfaceContainerHigh = Color(0xFFECEAE5);

  /// A heavier [fill], for tracks and inactive bars.
  static const Color fillStrong = brandNeutral300;

  /// Primary text (`semantic/text/primary`).
  static const Color ink = brandBlue300;

  /// Secondary text (`color/text/secondary`).
  static const Color ink2 = brandNeutral300;

  /// Tertiary text.
  static const Color ink3 = brandNeutral300;

  /// Hairline separators (`color/outline/divider-subtle`).
  static const line = Color(0xFFEAE7E1);

  /// The white veil laid over a tinted card for chips, bubbles and controls
  /// (`ext/overlay-on-tint`).
  static const Color overlayOnTint = Color(0x99FFFFFF);

  /// A stronger [overlayOnTint] (`ext/overlay-on-tint-strong`).
  static const Color overlayOnTintStrong = Color(0xB2FFFFFF);

  /// The border of an urgent card (`error/error-outline`).
  static const Color errorOutline = Color(0x99F0443A);

  /// Text on an urgent card's wash (`error/on-error-container`).
  static const Color onErrorContainer = Color(0xFF5F0E0A);

  /// The sparkle that marks anything the assistant offers.
  static const Color spark = Color(0xFFF7A84A);

  /// The dark bezel around the panel. Hardware, not in the Figma tokens.
  static const bezel = Color(0xFF1B1B1F);

  /// The bezel's edge highlight. Hardware, not in the Figma tokens.
  static const bezelEdge = Color(0xFF3A3A40);
}
