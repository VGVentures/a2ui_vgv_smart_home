import 'package:app_ui/app_ui.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group(AppTheme, () {
    test('builds the scheme from the accent token', () {
      final theme = AppTheme.light;

      expect(theme.colorScheme.primary, AppColors.accent);
      expect(theme.scaffoldBackgroundColor, AppColors.surface);
    });

    test('derives the text theme from the type scale', () {
      expect(AppTheme.light.textTheme.titleLarge?.fontSize, 28);
    });
  });

  group(AppIcons, () {
    test('resolves a known name', () {
      expect(AppIcons.byName('oven'), isNot(AppIcons.fallback));
    });

    test('falls back for an unknown or missing name', () {
      expect(AppIcons.byName('nope'), AppIcons.fallback);
      expect(AppIcons.byName(null), AppIcons.fallback);
    });

    test('lists every name', () {
      expect(AppIcons.names, contains('fridge'));
    });
  });
}
