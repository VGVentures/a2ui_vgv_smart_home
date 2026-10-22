import 'package:home_catalog/home_catalog.dart';
import 'package:test/test.dart';

void main() {
  group(CatalogSchemas, () {
    test('icon offers every icon name', () {
      expect(CatalogSchemas.icon().value['enum'], CatalogSchemas.iconNames);
    });

    test('icon names are unique', () {
      expect(
        CatalogSchemas.iconNames.toSet(),
        hasLength(CatalogSchemas.iconNames.length),
      );
    });

    test('tone offers the closed set', () {
      expect(CatalogSchemas.tone().value['enum'], [
        'neutral',
        'lighting',
        'energy',
        'climate',
        'security',
        'weather',
      ]);
    });

    test('statusTag requires a label and offers the kinds', () {
      final schema = CatalogSchemas.statusTag().value;
      final properties = schema['properties']! as Map;

      expect(schema['required'], ['label']);
      expect((properties['kind']! as Map)['enum'], [
        'updated',
        'new',
        'moved',
        'info',
      ]);
      expect((properties['icon']! as Map)['enum'], CatalogSchemas.iconNames);
    });
  });
}
