import 'package:home_catalog/home_catalog.dart';
import 'package:test/test.dart';

Map<String, Object?> _properties() =>
    const ChargeCardComponentDefinition().schema.value['properties']!
        as Map<String, Object?>;

void main() {
  group(ChargeCardComponentDefinition, () {
    const definition = ChargeCardComponentDefinition();

    test('uses the canonical A2UI name', () {
      expect(definition.name, 'ChargeCard');
    });

    test('requires percent', () {
      expect(definition.schema.value['required'], ['component', 'percent']);
    });

    test('declares every property', () {
      expect(
        _properties().keys,
        unorderedEquals([
          'component',
          'title',
          'status',
          'percent',
          'range',
          'summary',
          'window',
          'windowIcon',
          'tag',
          'weight',
        ]),
      );
    });

    test('binds the state props', () {
      for (final key in ['percent', 'range', 'summary', 'window']) {
        expect(
          (_properties()[key]! as Map)['oneOf'],
          hasLength(3),
          reason: key,
        );
      }
    });

    test('limits windowIcon to clock and savings', () {
      final icon = _properties()['windowIcon']! as Map;
      expect(icon['enum'], ['clock', 'savings']);
    });

    test('tag is a status tag', () {
      expect((_properties()['tag']! as Map)['required'], ['label']);
    });

    test('declares its own component discriminator', () {
      expect(
        (_properties()['component']! as Map)['const'],
        definition.name,
      );
    });
  });
}
