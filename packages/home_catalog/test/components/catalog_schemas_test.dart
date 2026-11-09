import 'package:a2ui_core/a2ui_core.dart';
import 'package:home_catalog/home_catalog.dart';
import 'package:json_schema_builder/json_schema_builder.dart';
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

    group('component', () {
      final schema = CatalogSchemas.component(
        'Thing',
        description: 'A thing.',
        properties: {'label': S.string()},
        required: ['label'],
      ).value;
      final properties = schema['properties']! as Map;

      test('names the component and requires it first', () {
        expect((properties['component']! as Map)['const'], 'Thing');
        expect(schema['required'], ['component', 'label']);
      });

      test('lets it span 1 to 12 columns in a Row', () {
        final weight = properties['weight']! as Map;
        expect(weight['type'], 'integer');
        expect(weight['minimum'], 1);
        expect(weight['maximum'], gridColumns);
        expect(schema['required'], isNot(contains('weight')));
      });
    });

    group('dynamic values', () {
      test('a string is a literal, a binding or a function', () {
        final schema = CatalogSchemas.dynamicString(description: 'A line.');
        expect(schema.value['oneOf'], hasLength(3));
        expect(schema.value['description'], 'A line.');
      });

      test('keeps the common description without one of its own', () {
        expect(
          CatalogSchemas.dynamicString().value['description'],
          CommonSchemasV1.dynamicString.value['description'],
        );
      });

      test('a string can be limited to a set of literals', () {
        final schema = CatalogSchemas.dynamicString(enumValues: ['a', 'b']);
        final branches = (schema.value['oneOf']! as List)
            .cast<Map<String, Object?>>();
        expect(branches, hasLength(3));
        expect(branches.first['enum'], ['a', 'b']);
      });

      test('a number and a boolean take the same three forms', () {
        expect(CatalogSchemas.dynamicNumber().value['oneOf'], hasLength(3));
        expect(CatalogSchemas.dynamicBoolean().value['oneOf'], hasLength(3));
      });

      test('a binding is written with @path', () {
        final properties =
            CatalogSchemas.dataBinding(
                  description: 'Where.',
                ).value['properties']!
                as Map;
        expect(properties.keys, ['@path']);
      });

      test('a list is written out, bound or computed', () {
        final schema = CatalogSchemas.dynamicList(items: S.string());
        expect(schema.value['oneOf'], hasLength(3));
      });

      test('children are ids or a template over a data list', () {
        final schema = CatalogSchemas.childList(description: 'The kids.');
        expect(schema.value['anyOf'], hasLength(2));
        expect(schema.value['description'], 'The kids.');
      });
    });
  });
}
