import 'package:home_catalog/home_catalog.dart';
import 'package:test/test.dart';

Map<String, Object?> _properties() =>
    const ShoppingListComponentDefinition().schema.value['properties']!
        as Map<String, Object?>;

void main() {
  group(ShoppingListComponentDefinition, () {
    const definition = ShoppingListComponentDefinition();

    test('uses the canonical A2UI name', () {
      expect(definition.name, 'ShoppingList');
    });

    test('requires listId, title, items', () {
      expect(definition.schema.value['required'], [
        'listId',
        'title',
        'items',
      ]);
    });

    test('declares every property', () {
      expect(
        _properties().keys,
        unorderedEquals([
          'listId',
          'title',
          'subtitle',
          'icon',
          'items',
          'footerAction',
        ]),
      );
    });

    test('items hold two to five rows with a bindable checked', () {
      final items = _properties()['items']! as Map;
      expect(items['minItems'], 2);
      expect(items['maxItems'], 5);
      final item = items['items']! as Map;
      expect(item['required'], ['id', 'label']);
      final checked = (item['properties']! as Map)['checked']! as Map;
      expect(checked['oneOf'], hasLength(3));
    });

    test('footerAction is a label and an icon with no action', () {
      final footer = _properties()['footerAction']! as Map;
      expect(footer['required'], ['label']);
      expect((footer['properties']! as Map).keys, ['label', 'icon']);
    });

    test('does not declare the reserved component property', () {
      expect(_properties().keys, isNot(contains('component')));
    });
  });
}
