import 'package:home_catalog/home_catalog.dart';
import 'package:test/test.dart';

Map<String, Object?> _properties() =>
    const TripCardComponentDefinition().schema.value['properties']!
        as Map<String, Object?>;

void main() {
  group(TripCardComponentDefinition, () {
    const definition = TripCardComponentDefinition();

    test('uses the canonical A2UI name', () {
      expect(definition.name, 'TripCard');
    });

    test('requires only leaveBy', () {
      expect(definition.schema.value['required'], ['leaveBy']);
    });

    test('declares the new props and drops title and eta', () {
      final properties = _properties();
      expect(
        properties.keys,
        unorderedEquals([
          'label',
          'leaveBy',
          'previousLeaveBy',
          'footer',
          'progress',
          'tag',
          'stops',
        ]),
      );
    });

    test('binds leaveBy, previousLeaveBy and stops', () {
      final properties = _properties();
      for (final key in ['leaveBy', 'previousLeaveBy', 'stops']) {
        final oneOf = (properties[key]! as Map)['oneOf']! as List;
        expect(oneOf, hasLength(3), reason: key);
      }
    });

    test('progress needs a percent and takes an icon', () {
      final progress = _properties()['progress']! as Map;
      expect(progress['required'], ['percent']);
      final icon = (progress['properties']! as Map)['icon']! as Map;
      expect(icon['enum'], contains('delivery'));
    });

    test('footer needs text and limits tone', () {
      final footer = _properties()['footer']! as Map;
      expect(footer['required'], ['text']);
      final tone = (footer['properties']! as Map)['tone']! as Map;
      expect(tone['enum'], ['normal', 'warning']);
    });

    test('stop shape', () {
      final stops = (_properties()['stops']! as Map)['oneOf']! as List;
      final item = (stops.first as Map)['items']! as Map;
      expect(item['required'], ['title', 'time']);
      final props = item['properties']! as Map;
      expect(
        props.keys,
        containsAll(['icon', 'title', 'subtitle', 'time', 'emphasis']),
      );
      expect((props['emphasis']! as Map)['enum'], ['none', 'good']);
      expect((props['icon']! as Map)['enum'], CatalogSchemas.iconNames);
    });

    test('tag is a status tag', () {
      final tag = _properties()['tag']! as Map;
      expect(tag['required'], ['label']);
    });

    test('does not declare the reserved component property', () {
      expect(_properties().keys, isNot(contains('component')));
    });
  });
}
