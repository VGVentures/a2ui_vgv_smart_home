import 'package:home_catalog/home_catalog.dart';
import 'package:test/test.dart';

void main() {
  group(CountdownCardComponentDefinition, () {
    const definition = CountdownCardComponentDefinition();
    final properties = definition.schema.value['properties']! as Map;

    test('uses the canonical A2UI name', () {
      expect(definition.name, 'CountdownCard');
    });

    test('requires only startsAt', () {
      expect(definition.schema.value['required'], ['startsAt']);
    });

    test('declares every property', () {
      expect(
        properties.keys,
        containsAll(['startsAt', 'tag', 'eyebrow', 'subtitle', 'tone']),
      );
    });

    test('does not declare the reserved component property', () {
      expect(properties.keys, isNot(contains('component')));
    });

    test('lets startsAt be a literal or a data binding', () {
      final startsAt = properties['startsAt']! as Map;
      final kinds = [
        for (final option in startsAt['oneOf']! as List)
          (option as Map)['type'],
      ];
      expect(kinds, containsAll(['string', 'object']));
    });

    test('limits tone to the shared tones', () {
      final tone = properties['tone']! as Map;
      expect(tone['enum'], CatalogSchemas.toneNames);
    });

    test('accepts a tag or a binding to one', () {
      final tag = properties['tag']! as Map;
      expect(tag['oneOf'], hasLength(2));
    });
  });
}
