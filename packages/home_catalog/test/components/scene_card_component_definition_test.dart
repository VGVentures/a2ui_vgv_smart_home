import 'package:home_catalog/home_catalog.dart';
import 'package:test/test.dart';

Map<String, Object?> _properties() =>
    const SceneCardComponentDefinition().schema.value['properties']!
        as Map<String, Object?>;

void main() {
  group(SceneCardComponentDefinition, () {
    const definition = SceneCardComponentDefinition();

    test('uses the canonical A2UI name', () {
      expect(definition.name, 'SceneCard');
    });

    test('requires sceneId, name', () {
      expect(definition.schema.value['required'], ['sceneId', 'name']);
    });

    test('declares every property', () {
      expect(
        _properties().keys,
        unorderedEquals([
          'sceneId',
          'name',
          'description',
          'icon',
          'tone',
          'state',
          'settings',
          'actionLabel',
        ]),
      );
    });

    test('state is bindable and limited to ready and running', () {
      final oneOf = (_properties()['state']! as Map)['oneOf']! as List;
      expect(oneOf, hasLength(3));
      expect((oneOf.first as Map)['enum'], ['ready', 'running']);
    });

    test('tone uses the shared tones', () {
      expect(
        (_properties()['tone']! as Map)['enum'],
        CatalogSchemas.toneNames,
      );
    });

    test('has no action, the client builds it', () {
      expect(_properties().keys, isNot(contains('action')));
    });

    test('does not declare the reserved component property', () {
      expect(_properties().keys, isNot(contains('component')));
    });
  });
}
