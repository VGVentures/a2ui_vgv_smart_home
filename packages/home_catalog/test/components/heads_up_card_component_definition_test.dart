import 'package:home_catalog/home_catalog.dart';
import 'package:test/test.dart';

void main() {
  group(HeadsUpCardComponentDefinition, () {
    const definition = HeadsUpCardComponentDefinition();

    Map<Object?, Object?> properties() =>
        definition.schema.value['properties']! as Map;

    Map<Object?, Object?> actionItem() =>
        (properties()['actions']! as Map)['items']! as Map;

    test('uses the canonical A2UI name', () {
      expect(definition.name, 'HeadsUpCard');
    });

    test('requires only the title', () {
      expect(definition.schema.value['required'], ['title']);
    });

    test('declares every property', () {
      expect(
        properties().keys,
        containsAll([
          'source',
          'variant',
          'title',
          'message',
          'timestamp',
          'actions',
        ]),
      );
    });

    test('drops the old single action', () {
      expect(properties().keys, isNot(contains('actionLabel')));
      expect(properties().keys, isNot(contains('action')));
    });

    test('does not declare the reserved component property', () {
      expect(properties().keys, isNot(contains('component')));
    });

    test('limits the variant to headsUp and urgent', () {
      final variant = properties()['variant']! as Map;

      expect(variant['enum'], ['headsUp', 'urgent']);
    });

    test('drops the quiet note variant', () {
      for (final key in ['severity', 'icon', 'tag', 'tone']) {
        expect(properties().keys, isNot(contains(key)));
      }
    });

    test('allows at most two actions', () {
      expect((properties()['actions']! as Map)['maxItems'], 2);
    });

    test('requires label and action on each action', () {
      expect(actionItem()['required'], containsAll(['label', 'action']));
    });

    test('lets timestamp and action state be data-bound', () {
      final state = (actionItem()['properties']! as Map)['state']! as Map;

      expect(state['oneOf'] ?? state['anyOf'], isNotNull);
      expect(
        (properties()['timestamp']! as Map)['oneOf'] ??
            (properties()['timestamp']! as Map)['anyOf'],
        isNotNull,
      );
    });

    test('takes a typed action spec, not an event', () {
      final action = (actionItem()['properties']! as Map)['action']! as Map;
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
