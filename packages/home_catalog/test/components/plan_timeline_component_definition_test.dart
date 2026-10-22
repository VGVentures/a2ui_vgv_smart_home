import 'package:home_catalog/home_catalog.dart';
import 'package:test/test.dart';

void main() {
  group(PlanTimelineComponentDefinition, () {
    const definition = PlanTimelineComponentDefinition();
    final properties = definition.schema.value['properties']! as Map;

    Map<String, Object?> entryProperties() {
      final entries = properties['entries']! as Map;
      final list = (entries['oneOf']! as List).first as Map;
      final item = list['items']! as Map;
      return (item['properties']! as Map).cast<String, Object?>();
    }

    test('uses the canonical A2UI name', () {
      expect(definition.name, 'PlanTimeline');
    });

    test('requires entries', () {
      expect(definition.schema.value['required'], ['entries']);
    });

    test('declares every property', () {
      expect(
        properties.keys,
        containsAll(['title', 'subtitle', 'density', 'tag', 'entries']),
      );
    });

    test('does not declare the reserved component property', () {
      expect(properties.keys, isNot(contains('component')));
    });

    test('limits density to detailed and compact', () {
      final density = properties['density']! as Map;
      expect(density['enum'], ['detailed', 'compact']);
    });

    test('lets the tag and the entries be data-bound', () {
      final tag = properties['tag']! as Map;
      final entries = properties['entries']! as Map;
      expect(tag['oneOf']! as List, hasLength(2));
      expect(entries['oneOf']! as List, hasLength(2));
    });

    test('limits entries to between one and five', () {
      final entries = properties['entries']! as Map;
      final list = (entries['oneOf']! as List).first as Map;
      expect(list['minItems'], 1);
      expect(list['maxItems'], 5);
    });

    test('declares the new entry fields and drops state', () {
      final fields = entryProperties();
      expect(
        fields.keys,
        containsAll(['icon', 'previousTime', 'changedBy', 'status']),
      );
      expect(fields.keys, isNot(contains('state')));
      expect((fields['status']! as Map)['enum'], [
        'unchanged',
        'moved',
        'new',
      ]);
      expect((fields['icon']! as Map)['enum'], CatalogSchemas.iconNames);
    });
  });
}
