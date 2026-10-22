import 'package:home_catalog/home_catalog.dart';
import 'package:test/test.dart';

void main() {
  group(ChangeSummaryComponentDefinition, () {
    const definition = ChangeSummaryComponentDefinition();

    Map<Object?, Object?> properties() =>
        definition.schema.value['properties']! as Map;

    Map<Object?, Object?> changes() => properties()['changes']! as Map;

    test('uses the canonical A2UI name', () {
      expect(definition.name, 'ChangeSummary');
    });

    test('requires title and changes', () {
      expect(definition.schema.value['required'], ['title', 'changes']);
    });

    test('declares every property', () {
      expect(properties().keys, containsAll(['eyebrow', 'title', 'changes']));
    });

    test('drops the old note', () {
      expect(properties().keys, isNot(contains('note')));
    });

    test('does not declare the reserved component property', () {
      expect(properties().keys, isNot(contains('component')));
    });

    test('allows one to four change tiles', () {
      expect(changes()['minItems'], 1);
      expect(changes()['maxItems'], 4);
    });

    test('describes each tile', () {
      final item = changes()['items']! as Map;
      final itemProperties = item['properties']! as Map;

      expect(item['required'], ['label', 'value']);
      expect(
        itemProperties.keys,
        containsAll(['icon', 'label', 'value', 'previous', 'note']),
      );
      expect(
        (itemProperties['icon']! as Map)['enum'],
        CatalogSchemas.iconNames,
      );
    });
  });
}
