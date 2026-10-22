import 'package:home_catalog/home_catalog.dart';
import 'package:test/test.dart';

void main() {
  group(ActionChipsComponentDefinition, () {
    const definition = ActionChipsComponentDefinition();

    Map<Object?, Object?> properties() =>
        definition.schema.value['properties']! as Map;

    Map<Object?, Object?> chipItem() =>
        (properties()['chips']! as Map)['items']! as Map;

    test('uses the canonical A2UI name', () {
      expect(definition.name, 'ActionChips');
    });

    test('requires chips', () {
      expect(definition.schema.value['required'], ['chips']);
    });

    test('declares every property', () {
      expect(properties().keys, containsAll(['label', 'chips']));
    });

    test('does not declare the reserved component property', () {
      expect(properties().keys, isNot(contains('component')));
    });

    test('allows one to three chips', () {
      final chips = properties()['chips']! as Map;

      expect(chips['minItems'], 1);
      expect(chips['maxItems'], 3);
    });

    test('requires label and action on each chip', () {
      expect(chipItem()['required'], containsAll(['label', 'action']));
    });

    test('caps the chip label and offers isPrimary', () {
      final itemProperties = chipItem()['properties']! as Map;

      expect((itemProperties['label']! as Map)['maxLength'], 22);
      expect(itemProperties.keys, contains('isPrimary'));
    });

    test('uses the shared icon enum', () {
      final icon = (chipItem()['properties']! as Map)['icon']! as Map;

      expect(icon['enum'], CatalogSchemas.iconNames);
    });

    test('takes a typed action spec, not an event', () {
      final action = (chipItem()['properties']! as Map)['action']! as Map;
      final options = action['oneOf']! as List;
      final keys = [
        for (final option in options)
          ((option as Map)['required']! as List).single,
      ];

      expect(keys, ['command', 'scene', 'undo', 'ask']);
      expect(action.containsKey('properties'), isFalse);
      expect(action['description'], contains('Never write'));
    });
  });
}
