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
      expect(definition.schema.value['required'], [
        'component',
        'sceneId',
        'name',
      ]);
    });

    test('declares every property', () {
      expect(
        _properties().keys,
        unorderedEquals([
          'component',
          'sceneId',
          'name',
          'description',
          'icon',
          'tone',
          'state',
          'settings',
          'actionLabel',
          'weight',
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

    test('declares its own component discriminator', () {
      expect(
        (_properties()['component']! as Map)['const'],
        definition.name,
      );
    });
  });
}
