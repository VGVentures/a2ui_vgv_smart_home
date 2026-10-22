import 'package:home_catalog/home_catalog.dart';
import 'package:test/test.dart';

void main() {
  group(ColumnComponentDefinition, () {
    const definition = ColumnComponentDefinition();

    test('uses the canonical A2UI name', () {
      expect(definition.name, 'Column');
    });

    test('requires children but treats justify and align as optional', () {
      final schema = definition.schema.value;
      expect(schema['required'], ['children']);
      final properties = schema['properties']! as Map;
      expect(properties.keys, containsAll(['justify', 'align', 'children']));
    });

    test('children is a componentArrayReference with explicit list or '
        'template options', () {
      final children =
          (definition.schema.value['properties']! as Map)['children']! as Map;
      expect(children['oneOf'], isA<List<Object?>>());
      expect(children['oneOf']! as List<Object?>, hasLength(2));
    });
  });
}
