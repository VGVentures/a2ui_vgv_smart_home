import 'package:home_catalog/home_catalog.dart';
import 'package:test/test.dart';

void main() {
  group(DeviceCardComponentDefinition, () {
    const definition = DeviceCardComponentDefinition();

    Map<Object?, Object?> properties() =>
        definition.schema.value['properties']! as Map;

    test('uses the canonical A2UI name', () {
      expect(definition.name, 'DeviceCard');
    });

    test('requires deviceId, name, status', () {
      expect(definition.schema.value['required'], [
        'deviceId',
        'name',
        'status',
      ]);
    });

    test('declares every property and drops the old action props', () {
      expect(
        properties().keys,
        unorderedEquals([
          'deviceId',
          'name',
          'room',
          'status',
          'icon',
          'tone',
          'value',
          'unit',
          'delta',
          'tag',
          'isActive',
          'isLoading',
          'control',
        ]),
      );
    });

    test('does not declare the reserved component property', () {
      expect(properties().keys, isNot(contains('component')));
    });

    test('shares the icon and tone enums', () {
      final props = properties();

      expect((props['icon']! as Map)['enum'], CatalogSchemas.iconNames);
      expect((props['tone']! as Map)['enum'], CatalogSchemas.toneNames);
    });

    test('binds the state props', () {
      final props = properties();

      for (final key in ['status', 'value', 'delta', 'isActive', 'tag']) {
        expect(
          (props[key]! as Map)['oneOf']! as List<Object?>,
          isNotEmpty,
          reason: key,
        );
      }
    });

    test('control has a type enum, a button command and no action', () {
      final control = properties()['control']! as Map;
      final controlProps = control['properties']! as Map;

      expect(control['required'], ['type']);
      expect(
        controlProps.keys,
        unorderedEquals(['type', 'label', 'icon', 'command']),
      );
      expect((controlProps['type']! as Map)['enum'], [
        'toggle',
        'stepper',
        'button',
        'none',
      ]);
      expect((controlProps['command']! as Map)['enum'], HomeActions.commands);
      expect((controlProps['label']! as Map)['maxLength'], 22);
    });
  });
}
