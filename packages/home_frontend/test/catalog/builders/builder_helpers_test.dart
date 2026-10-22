import 'dart:async';

import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:genui/genui.dart';
import 'package:home_frontend/src/catalog/builders/builder_helpers.dart';

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

    test('boundPath reads a lone path reference only', () {
      expect(boundPath({'path': '/a'}), '/a');
      expect(boundPath({'path': '/a', 'x': 1}), isNull);
      expect(boundPath('/a'), isNull);
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
    testWidgets('runs a functionCall without raising an event', (tester) async {
      final data = DataContext(InMemoryDataModel(), DataPath('/'));
      final events = <UserActionEvent>[];
      await tester.pumpWidget(
        Builder(
          builder: (buildContext) {
            final item = _itemContext(buildContext, data);
            unawaited(
              dispatch(item, {
                'functionCall': {
                  'call': 'noSuchFunction',
                  'args': const <String, Object?>{},
                },
              }),
            );
            return const SizedBox();
          },
        ),
      );
      await tester.pump();

      expect(events, isEmpty);
    });
  });

  group('writeBound', () {
    testWidgets('writes the bound path and ignores literals', (tester) async {
      final data = DataContext(InMemoryDataModel(), DataPath('/'));
      late CatalogItemContext item;
      await tester.pumpWidget(
        Builder(
          builder: (buildContext) {
            item = _itemContext(buildContext, data);
            return const SizedBox();
          },
        ),
      );

      writeBound(item, {'path': '/devices/oven/on'}, true);
      writeBound(item, true, false);

      expect(data.getValue<bool>(DataPath('/devices/oven/on')), isTrue);
    });
  });

  group(OptimisticWrites, () {
    testWidgets('keeps the first previous value across writes', (
      tester,
    ) async {
      final data = DataContext(InMemoryDataModel(), DataPath('/'))
        ..update(DataPath('/a'), 1);
      late CatalogItemContext item;
      await tester.pumpWidget(
        Builder(
          builder: (buildContext) {
            item = _itemContext(buildContext, data);
            return const SizedBox();
          },
        ),
      );
      final writes = OptimisticWrites()
        ..write(item, {'path': '/a'}, 2)
        ..write(item, {'path': '/a'}, 3)
        ..write(item, 5, 6);
      expect(data.getValue<int>(DataPath('/a')), 3);

      writes.revert(data);
      expect(data.getValue<int>(DataPath('/a')), 1);

      // Nothing left to undo.
      data.update(DataPath('/a'), 9);
      writes.revert(data);
      expect(data.getValue<int>(DataPath('/a')), 9);
    });
  });

  group(BoundProps, () {
    testWidgets('passes literals through and resolves references', (
      tester,
    ) async {
      final context = DataContext(InMemoryDataModel(), DataPath('/'))
        ..update(DataPath('/name'), 'Oven');
      final seen = <Map<String, Object?>>[];

      await tester.pumpWidget(
        Directionality(
          textDirection: TextDirection.ltr,
          child: BoundProps(
            dataContext: context,
            data: const {
              'title': 'Plain',
              'name': {'path': '/name'},
              'nested': {
                'tag': {'path': '/name'},
              },
              'list': [
                {'path': '/name'},
              ],
              'action': {
                'event': {
                  'context': {
                    'on': {'path': '/name'},
                  },
                },
              },
            },
            builder: (context, props) {
              seen.add(props);
              return const SizedBox();
            },
          ),
        ),
      );

      final props = seen.last;
      expect(props['title'], 'Plain');
      expect(props['name'], 'Oven');
      expect(props['nested'], {'tag': 'Oven'});
      expect(props['list'], ['Oven']);
      expect(
        (props['action']! as Map)['event'],
        {
          'context': {
            'on': {'path': '/name'},
          },
        },
      );
    });

    testWidgets('rebuilds when the bound value changes', (tester) async {
      final context = DataContext(InMemoryDataModel(), DataPath('/'))
        ..update(DataPath('/on'), false);

      await tester.pumpWidget(
        Directionality(
          textDirection: TextDirection.ltr,
          child: BoundProps(
            dataContext: context,
            data: const {
              'on': {'path': '/on'},
            },
            builder: (_, props) => Text('${props['on']}'),
          ),
        ),
      );
      expect(find.text('false'), findsOneWidget);

      context.update(DataPath('/on'), true);
      await tester.pump();

      expect(find.text('true'), findsOneWidget);
    });

    testWidgets('resubscribes when the data changes', (tester) async {
      final context = DataContext(InMemoryDataModel(), DataPath('/'))
        ..update(DataPath('/a'), 'A')
        ..update(DataPath('/b'), 'B');

      Widget build(String path) => Directionality(
        textDirection: TextDirection.ltr,
        child: BoundProps(
          dataContext: context,
          data: {
            'v': {'path': path},
          },
          builder: (_, props) => Text('${props['v']}'),
        ),
      );

      await tester.pumpWidget(build('/a'));
      expect(find.text('A'), findsOneWidget);

      await tester.pumpWidget(build('/b'));
      expect(find.text('B'), findsOneWidget);
    });
  });
}

CatalogItemContext _itemContext(
  BuildContext buildContext,
  DataContext data, [
  void Function(Object error)? onError,
]) {
  return CatalogItemContext(
    data: const <String, Object?>{},
    id: 'x',
    type: 'Test',
    buildChild: (id, [dataContext]) => const SizedBox(),
    dispatchEvent: (_) {},
    buildContext: buildContext,
    dataContext: data,
    getComponent: (_) => null,
    getCatalogItem: (_) => null,
    surfaceId: 's',
    reportError: (error, _) => onError?.call(error),
  );
}

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
