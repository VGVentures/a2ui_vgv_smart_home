import 'package:app_ui/app_ui.dart';
import 'package:flutter/painting.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group(AppTypography, () {
    test('turns the Figma line height into a multiplier', () {
      final style = AppTypography.displayMedium;

      expect(style.fontSize, 76);
      expect(style.height, 80 / 76);
      expect(style.letterSpacing, -6.08);
    });

    test('sets the weight on the variable font axis', () {
      final style = AppTypography.titleSmall;

      expect(style.fontFamily, contains(AppTypography.fontFamily));
      expect(style.fontVariations, const [FontVariation.weight(500)]);
    });

    test('keeps the aliases on the Figma scale', () {
      expect(AppTypography.title.fontSize, 22);
      expect(AppTypography.body.fontSize, 18);
      expect(AppTypography.label.fontSize, 15);
      expect(AppTypography.label.color, AppColors.ink2);
      expect(AppTypography.labelStrong.fontWeight, FontWeight.w500);
    });

    test('builds every Material role', () {
      final theme = AppTypography.textTheme;

      expect(theme.displayLarge?.fontSize, 88);
      expect(theme.labelSmall?.fontSize, 15);
    });

    test('exposes the Figma display and headline styles', () {
      expect(AppTypography.displayLarge.fontSize, 88);
      expect(AppTypography.displaySmall.fontSize, 64);
      expect(AppTypography.headlineLarge.fontSize, 56);
      expect(AppTypography.headlineMedium.fontSize, 44);
      expect(AppTypography.headlineSmall.fontSize, 32);
      expect(AppTypography.headlineSmallEmphasized.height, 40 / 32);
    });

    test('exposes the Figma title, body and label styles', () {
      expect(AppTypography.titleLarge.fontSize, 28);
      expect(AppTypography.titleMedium.fontSize, 26);
      expect(AppTypography.bodyLarge.fontSize, 18);
      expect(AppTypography.bodyLargeEmphasized.fontSize, 20);
      expect(AppTypography.bodyMedium.fontSize, 15);
      expect(AppTypography.labelLarge.fontSize, 18);
      expect(AppTypography.labelMedium.fontSize, 15);
      expect(AppTypography.labelMediumEmphasized.fontWeight, FontWeight.w600);
    });
  });
}
