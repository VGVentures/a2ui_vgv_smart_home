import 'package:flutter_test/flutter_test.dart';
import 'package:home_frontend/src/a2ui/a2ui.dart';
import 'package:home_frontend/src/catalog/builders/builder_helpers.dart';
import 'package:mocktail/mocktail.dart';

class _MockNode extends Mock
    implements ComponentNode<ComponentImplementation> {}

void main() {
  actionFromSpecTests();

  group('readers', () {
    test('string returns strings only', () {
      expect(string({'a': 'x', 'b': 1}, 'a'), 'x');
      expect(string({'b': 1}, 'b'), isNull);
      expect(string({}, 'c'), isNull);
    });

    test('maps keeps the map entries of a list', () {
      final result = maps({
        'items': [
          {'a': 1},
          'skip',
          {'b': 2},
        ],
      }, 'items');

      expect(result, [
        {'a': 1},
        {'b': 2},
      ]);
      expect(maps({'items': 3}, 'items'), isEmpty);
    });
  });

  group('plain', () {
    test('replaces every binding with its value, however deep', () {
      const bound = WritableBinding<Object?>('Oven', _ignore, '/name');
      final props = plainProps({
        'title': 'Plain',
        'name': bound,
        'read': const ResolvedBinding<Object?>(3),
        'nested': {'tag': bound},
        'list': [bound, const ResolvedBinding<Object?>(true)],
      });

      expect(props, {
        'title': 'Plain',
        'name': 'Oven',
        'read': 3,
        'nested': {'tag': 'Oven'},
        'list': ['Oven', true],
      });
    });

    test('leaves literals alone', () {
      expect(plain(null), isNull);
      expect(plain(1), 1);
      expect(plain(const ResolvedBinding<Object?>(null)), isNull);
    });
  });

  group('homeAction', () {
    test('builds the event with the progressLabel first', () {
      expect(homeAction('run_scene', 'Start dinner', {'sceneId': 'dinner'}), {
        'event': {
          'name': 'run_scene',
          'context': {'progressLabel': 'Start dinner', 'sceneId': 'dinner'},
        },
      });
    });

    test('trims the progressLabel to 40 characters', () {
      final action = homeAction('x', '  ${'a' * 39} bbbb ', const {});
      final context = (action['event']! as Map)['context']! as Map;

      expect(context['progressLabel'], 'a' * 39);
    });
  });

  group('dispatch', () {
    test('raises the event on the surface, from the component', () async {
      final surface = SurfaceModel<ComponentImplementation>('s');
      final node = _MockNode();
      when(() => node.componentId).thenReturn('oven');
      final actions = <A2uiRendererAction>[];
      surface.onAction.subscribe(actions.add);

      await dispatch(surface, node, homeAction('run_scene', 'Go', {'a': 1}));

      expect(actions, hasLength(1));
      expect(actions.single.name, 'run_scene');
      expect(actions.single.surfaceId, 's');
      expect(actions.single.sourceComponentId, 'oven');
      expect(actions.single.context, {'progressLabel': 'Go', 'a': 1});
    });
  });

  group(OptimisticWrites, () {
    test('keeps the first previous value across writes', () {
      var stored = 1 as Object?;
      final binding = WritableBinding<Object?>(
        stored,
        (value) => stored = value,
        '/a',
      );
      final writes = OptimisticWrites()
        ..write(binding, 2)
        ..write(binding, 3)
        ..write(null, 6);
      expect(stored, 3);

      writes.revert();
      expect(stored, 1);

      // Nothing left to undo.
      stored = 9;
      writes.revert();
      expect(stored, 9);
    });
  });
}

void _ignore(Object? value) {}

void actionFromSpecTests() {
  group('actionFromSpec', () {
    Map<String, Object?> contextOf(Object? spec) =>
        (actionFromSpec(spec, 'Do it')!['event']!
                as Map<String, Object?>)['context']!
            as Map<String, Object?>;
    String nameOf(Object? spec) =>
        (actionFromSpec(spec, 'Do it')!['event']!
                as Map<String, Object?>)['name']!
            as String;

    test('writes the event for a device command', () {
      const spec = {
        'command': {'deviceId': 'oven', 'command': 'start'},
      };

      expect(nameOf(spec), 'run_device_action');
      expect(contextOf(spec), {
        'progressLabel': 'Do it',
        'deviceId': 'oven',
        'command': 'start',
      });
    });

    test('writes scene, undo and ask events', () {
      expect(nameOf({'scene': 'dinner_party'}), 'run_scene');
      expect(contextOf({'scene': 'dinner_party'})['sceneId'], 'dinner_party');
      expect(nameOf({'undo': true}), 'undo_change');
      expect(nameOf({'ask': ' Tell guests '}), 'ask');
      expect(contextOf({'ask': ' Tell guests '})['text'], 'Tell guests');
    });

    test('returns null for a spec that names nothing', () {
      for (final spec in <Object?>[
        null,
        'x',
        <String, Object?>{},
        {
          'command': {'deviceId': 'oven'},
        },
        {'scene': ''},
        {'undo': false},
        {'ask': '  '},
      ]) {
        expect(actionFromSpec(spec, 'Do it'), isNull, reason: '$spec');
      }
    });
  });
}
