import 'package:app_ui/app_ui.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group(AppIcons, () {
    test('resolves every name it lists', () {
      for (final name in AppIcons.names) {
        expect(AppIcons.byName(name), isNot(AppIcons.fallback), reason: name);
      }
    });

    test('falls back for null and unknown names', () {
      expect(AppIcons.byName(null), AppIcons.fallback);
      expect(AppIcons.byName('nope'), AppIcons.fallback);
    });
  });
}
