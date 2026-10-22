import 'package:app_ui/app_ui.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:home_catalog/home_catalog.dart';

void main() {
  group('catalog and app_ui', () {
    test('agree on the icon names', () {
      expect(
        AppIcons.names.toSet(),
        CatalogSchemas.iconNames.toSet(),
      );
    });

    test('agree on the tone names', () {
      expect(
        AppTone.values.map((tone) => tone.name).toSet(),
        CatalogSchemas.toneNames.toSet(),
      );
    });

    test('agree on the status tag kinds', () {
      for (final kind in CatalogSchemas.tagKinds) {
        expect(StatusTagKind.byName(kind).name, kind == 'new' ? 'isNew' : kind);
      }
    });
  });
}
