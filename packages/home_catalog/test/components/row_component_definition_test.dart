import 'package:home_catalog/home_catalog.dart';
import 'package:test/test.dart';

void main() {
  group(RowComponentDefinition, () {
    const definition = RowComponentDefinition();

    test('uses the canonical A2UI name', () {
      expect(definition.name, 'Row');
    });

    test('requires children and exposes justify and align', () {
      final schema = definition.schema.value;
      expect(schema['required'], ['children']);
      final properties = schema['properties']! as Map;
      expect(properties.keys, containsAll(['justify', 'align', 'children']));
    });
  });
}
