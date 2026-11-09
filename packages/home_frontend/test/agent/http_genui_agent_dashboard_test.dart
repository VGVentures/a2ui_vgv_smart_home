import 'dart:async';
import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:home_frontend/home_frontend.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';

import '../helpers/basic_components.dart';

typedef _Json = Map<String, Object?>;

/// The root of a one component dashboard, saying [text].
List<_Json> _components(String text) => [
  {'id': 'root', 'component': 'Text', 'text': text},
];

/// The first turn: one `createSurface` that carries the dashboard and, when
/// given, the data model, as the backend writes it.
_Json _create(String text, {_Json? dataModel}) => {
  'version': '1.0',
  'createSurface': {
    'surfaceId': 'dashboard',
    'catalogId': homeCatalog.id,
    'sendDataModel': true,
    'components': _components(text),
    'dataModel': ?dataModel,
  },
};

/// A later turn: the dashboard replaced on the surface that exists.
_Json _update(String text) => {
  'version': '1.0',
  'updateComponents': {
    'surfaceId': 'dashboard',
    'components': _components(text),
  },
};

_Json _oven(Object? value) => {
  'version': '1.0',
  'updateDataModel': {
    'surfaceId': 'dashboard',
    'path': '/devices/oven',
    'value': value,
  },
};

/// A backend that answers each request when the test says so.
class _Backend {
  final requests = <Completer<_Json>>[];
  final paths = <String>[];
  final bodies = <_Json>[];

  http.Client get client => MockClient.streaming((request, body) async {
    paths.add(request.url.path);
    bodies.add(jsonDecode(utf8.decode(await body.toBytes())) as _Json);
    final reply = Completer<_Json>();
    requests.add(reply);
    final answer = await reply.future;
    return http.StreamedResponse(
      Stream.value(utf8.encode(jsonEncode(answer))),
      200,
      headers: {'content-type': 'application/json'},
    );
  });

  /// Answers request [index] with [messages] and the model's [reply].
  void answer(int index, List<_Json> messages, [String reply = 'raw reply']) =>
      requests[index].complete({'messages': messages, 'reply': reply});
}

Future<HttpGenUIAgent> _agent(_Backend backend) async {
  final agent = HttpGenUIAgent(
    catalog: testCatalog,
    widgetBuilders: testWidgetBuilders,
    client: backend.client,
    tokenProvider: () async => 'token',
  );
  addTearDown(agent.dispose);
  await agent.start();
  return agent;
}

Object? _text(HttpGenUIAgent agent) => agent.surfaces
    .getSurface('dashboard')
    ?.componentsModel
    .get('root')
    ?.properties['text'];

/// Asks for the first dashboard and waits for it to land.
Future<void> _seed(_Backend backend, HttpGenUIAgent agent) async {
  final turn = agent.sendMessage('hello');
  await pumpEventQueue();
  backend.answer(0, [_create('seed')], 'seed reply');
  await turn;
  await pumpEventQueue();
}

void main() {
  group('HttpGenUIAgent applying the whole dashboard', () {
    test('applies the messages of a reply in one step', () async {
      final backend = _Backend();
      final agent = await _agent(backend);
      final added = <String>[];
      agent.events.listen((event) {
        if (event case SurfaceAdded(:final surface)) added.add(surface.id);
      });

      await _seed(backend, agent);
      expect(_text(agent), 'seed');

      final refresh = agent.refresh('again');
      await pumpEventQueue();
      backend.answer(1, [_update('second')]);
      await refresh;
      await pumpEventQueue();

      expect(_text(agent), 'second');
      // The zone saw one surface, so it has one row to rebuild, not two.
      expect(added, ['dashboard']);
    });

    test('keeps the reply of the model as the history', () async {
      final backend = _Backend();
      final agent = await _agent(backend);

      await _seed(backend, agent);

      expect(agent.history.map((m) => m.content), ['hello', 'seed reply']);
    });

    test(
      'sends the renderer capabilities, and the surfaces it shows',
      () async {
        final backend = _Backend();
        final agent = await _agent(backend);
        await _seed(backend, agent);

        final refresh = agent.refresh('again');
        await pumpEventQueue();
        backend.answer(1, [_update('second')]);
        await refresh;

        final first = backend.bodies.first['metadata']! as _Json;
        final capabilities = first['a2uiRendererCapabilities']! as _Json;
        expect(
          (capabilities['1.0']! as _Json)['supportedCatalogIds'],
          contains(testCatalog.id),
        );
        // Nothing is on screen yet: the backend is told to create the surface.
        expect(first, isNot(contains('a2uiRendererDataModel')));
        final second = backend.bodies.last['metadata']! as _Json;
        final dataModel = second['a2uiRendererDataModel']! as _Json;
        expect((dataModel['surfaces']! as _Json).keys, ['dashboard']);
      },
    );

    test('a refresh asks from scratch and leaves a clean history', () async {
      final backend = _Backend();
      final agent = await _agent(backend);
      await _seed(backend, agent);

      final refresh = agent.refresh('again');
      await pumpEventQueue();
      backend.answer(1, [_update('second')], 'second reply');
      await refresh;

      expect(backend.paths, ['/generate', '/generate']);
      expect(agent.history.map((m) => m.content), ['again', 'second reply']);
    });

    test('a press that comes while a refresh runs wins', () async {
      final backend = _Backend();
      final agent = await _agent(backend);
      await _seed(backend, agent);

      final refresh = agent.refresh('again');
      await pumpEventQueue();
      final press = agent.sendMessage('preheat');
      await pumpEventQueue();
      expect(backend.requests, hasLength(3));

      // The refresh was asked first and answers first. It must not land.
      backend.answer(1, [_update('refresh')]);
      await refresh;
      await pumpEventQueue();
      expect(_text(agent), 'seed');

      backend.answer(2, [_update('press')]);
      await press;
      await pumpEventQueue();
      expect(_text(agent), 'press');
      expect(agent.history.map((m) => m.content), contains('preheat'));
      expect(agent.history.map((m) => m.content), isNot(contains('again')));
    });

    test('a refresh asked while a press runs sends nothing', () async {
      final backend = _Backend();
      final agent = await _agent(backend);
      final press = agent.sendMessage('preheat');
      await pumpEventQueue();

      await agent.refresh('again');
      expect(backend.requests, hasLength(1));

      backend.answer(0, [_create('press')]);
      await press;
      await pumpEventQueue();
      expect(_text(agent), 'press');
    });

    test('an invalid component is refused, and nothing of it lands', () async {
      final backend = _Backend();
      final agent = await _agent(backend);
      await _seed(backend, agent);

      final refresh = agent.refresh('again');
      await pumpEventQueue();
      // A `Text` without its required `text`: the renderer refuses the reply.
      backend.answer(1, [
        {
          'version': '1.0',
          'updateComponents': {
            'surfaceId': 'dashboard',
            'components': [
              {'id': 'root', 'component': 'Text'},
            ],
          },
        },
      ]);
      await expectLater(refresh, throwsA(isA<A2uiError>()));
      await pumpEventQueue();

      // No third request: nothing asked the model to "fix" a dashboard it
      // cannot see, the surface still shows what it did, and the history
      // holds only the two real turns.
      expect(backend.requests, hasLength(2));
      expect(_text(agent), 'seed');
      expect(agent.history.map((m) => m.content), hasLength(2));
    });

    test(
      'a turn the renderer refuses is rolled back like a failed one',
      () async {
        final backend = _Backend();
        final agent = await _agent(backend);
        final events = <GenUIAgentEvent>[];
        agent.events.listen(events.add);

        final turn = agent.sendMessage('hello');
        await pumpEventQueue();
        backend.answer(0, [_update('no surface to update')]);

        await expectLater(turn, throwsA(isA<A2uiError>()));
        await pumpEventQueue();
        expect(agent.history, isEmpty);
        expect(events.whereType<UserTurnRolledBack>(), hasLength(1));
      },
    );

    test('refresh before start is refused', () {
      final agent = HttpGenUIAgent(
        catalog: testCatalog,
        widgetBuilders: testWidgetBuilders,
        tokenProvider: () async => 'token',
        client: _Backend().client,
      );
      addTearDown(agent.dispose);

      expect(() => agent.refresh('x'), throwsStateError);
    });
  });

  group('HttpGenUIAgent applying a message that came outside a reply', () {
    Object? oven(HttpGenUIAgent agent) =>
        agent.surfaces.getSurface('dashboard')?.dataModel.get('/devices/oven');

    /// A dashboard whose first turn seeds the oven, as the backend does.
    Future<HttpGenUIAgent> withSurface(_Backend backend) async {
      final agent = await _agent(backend);
      final turn = agent.sendMessage('hello');
      await pumpEventQueue();
      backend.answer(0, [
        _create(
          'screen',
          dataModel: {
            'devices': {
              'oven': {'status': 'Off'},
            },
          },
        ),
      ]);
      await turn;
      await pumpEventQueue();
      return agent;
    }

    test('moves a value of the surface in place', () async {
      final agent = await withSurface(_Backend());
      expect(oven(agent), {'status': 'Off'});

      agent.apply(_oven({'status': 'Preheating'}));
      await pumpEventQueue();

      expect(oven(agent), {'status': 'Preheating'});
      expect(_text(agent), 'screen');
    });

    test('puts the newest value back when a reply lands over it', () async {
      final backend = _Backend();
      final agent = await withSurface(backend);

      final refresh = agent.refresh('again');
      await pumpEventQueue();
      // A device changes while the reply is on its way, and the screen is told.
      agent.apply(_oven({'status': 'Ready'}));
      await pumpEventQueue();
      // The reply was written before it changed, so it says the old value.
      backend.answer(1, [
        _oven({'status': 'Preheating'}),
        _update('screen'),
      ]);
      await refresh;
      await pumpEventQueue();

      expect(oven(agent), {'status': 'Ready'});
    });

    test('keeps only the latest message for each path', () async {
      final backend = _Backend();
      final agent = await withSurface(backend);
      agent
        ..apply(_oven({'status': 'One'}))
        ..apply(_oven({'status': 'Two'}));

      final refresh = agent.refresh('again');
      await pumpEventQueue();
      backend.answer(1, [
        _oven({'status': 'Old'}),
        _update('screen'),
      ]);
      await refresh;
      await pumpEventQueue();

      expect(oven(agent), {'status': 'Two'});
    });

    test('ignores a message the renderer cannot read', () async {
      final agent = await withSurface(_Backend());

      agent
        ..apply({'version': '1.0', 'mystery': 1})
        ..apply({'version': 'v0.1', 'deleteSurface': 3});
      await pumpEventQueue();

      expect(oven(agent), {'status': 'Off'});
    });

    test('ignores a message before the agent has started', () {
      final agent = HttpGenUIAgent(
        catalog: testCatalog,
        widgetBuilders: testWidgetBuilders,
        tokenProvider: () async => 'token',
        client: _Backend().client,
      );
      addTearDown(agent.dispose);

      expect(() => agent.apply(_oven(1)), returnsNormally);
    });
  });
}
