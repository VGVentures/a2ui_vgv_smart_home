import 'dart:async';
import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:home_frontend/home_frontend.dart';
import 'package:home_frontend/src/agent/genui_agent_event.dart';
import 'package:home_frontend/src/queue/stable_surface.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';

import '../helpers/basic_components.dart';

/// A dashboard reply as the model writes it: a new surface id every time.
String _reply(String surfaceId, String text) =>
    '```json\n${jsonEncode({
      'version': 'v0.9',
      'createSurface': {
        'surfaceId': surfaceId,
        'catalogId': homeCatalog.id,
        'sendDataModel': true,
      },
    })}\n```\n'
    '```json\n${jsonEncode({
      'version': 'v0.9',
      'updateComponents': {
        'surfaceId': surfaceId,
        'components': [
          {'id': 'root', 'component': 'Text', 'text': text},
        ],
      },
    })}\n```';

/// A backend that answers each request when the test says so.
class _Backend {
  final requests = <Completer<String>>[];
  final paths = <String>[];

  http.Client get client => MockClient.streaming((request, body) async {
    paths.add(request.url.path);
    final reply = Completer<String>();
    requests.add(reply);
    final text = await reply.future;
    return http.StreamedResponse(
      Stream.value(utf8.encode(jsonEncode({'text': text}))),
      200,
      headers: {'content-type': 'application/json'},
    );
  });

  void answer(int index, String text) => requests[index].complete(text);
}

Future<HttpGenUIAgent> _agent(
  _Backend backend, {
  String? stableSurfaceId = 'dashboard',
}) async {
  final agent = HttpGenUIAgent(
    catalog: testCatalog,
    widgetBuilders: testWidgetBuilders,
    client: backend.client,
    tokenProvider: () async => 'token',
    stableSurfaceId: stableSurfaceId,
  );
  addTearDown(agent.dispose);
  await agent.start();
  return agent;
}

Object? _text(HttpGenUIAgent agent, String surfaceId) => agent
    .controller
    .registry
    .getSurface(surfaceId)
    ?.components['root']
    ?.properties['text'];

void main() {
  group('HttpGenUIAgent with a stable surface', () {
    test('updates one surface in place, whatever id the model picks', () async {
      final backend = _Backend();
      final agent = await _agent(backend);
      final added = <String>[];
      agent.events.listen((event) {
        if (event case ConversationEventReceived(
          event: ConversationSurfaceAdded(:final surfaceId),
        )) {
          added.add(surfaceId);
        }
      });

      final first = agent.sendMessage('hello');
      await pumpEventQueue();
      backend.answer(0, _reply('s_1', 'first'));
      await first;
      await pumpEventQueue();
      expect(_text(agent, 'dashboard'), 'first');

      final refresh = agent.refresh('again');
      await pumpEventQueue();
      backend.answer(1, _reply('s_2', 'second'));
      await refresh;
      await pumpEventQueue();

      expect(_text(agent, 'dashboard'), 'second');
      expect(_text(agent, 's_1'), isNull);
      expect(_text(agent, 's_2'), isNull);
      // The zone saw one surface, so it has one row to rebuild, not two.
      expect(added, ['dashboard']);
    });

    test('a refresh asks from scratch and leaves a clean history', () async {
      final backend = _Backend();
      final agent = await _agent(backend);
      final first = agent.sendMessage('hello');
      await pumpEventQueue();
      backend.answer(0, _reply('s_1', 'first'));
      await first;

      final refresh = agent.refresh('again');
      await pumpEventQueue();
      backend.answer(1, _reply('s_2', 'second'));
      await refresh;

      expect(backend.paths, ['/generate', '/generate']);
      expect(agent.history.map((m) => m.text), [
        'again',
        _reply('s_2', 'second'),
      ]);
    });

    test('a press that comes while a refresh runs wins', () async {
      final backend = _Backend();
      final agent = await _agent(backend);
      final seed = agent.sendMessage('hello');
      await pumpEventQueue();
      backend.answer(0, _reply('s_1', 'seed'));
      await seed;
      await pumpEventQueue();

      final refresh = agent.refresh('again');
      await pumpEventQueue();
      final press = agent.sendMessage('preheat');
      await pumpEventQueue();
      expect(backend.requests, hasLength(3));

      // The refresh was asked first and answers first. It must not land.
      backend.answer(1, _reply('s_2', 'refresh'));
      await refresh;
      await pumpEventQueue();
      expect(_text(agent, 'dashboard'), 'seed');

      backend.answer(2, _reply('s_3', 'press'));
      await press;
      await pumpEventQueue();
      expect(_text(agent, 'dashboard'), 'press');
      expect(agent.history.map((m) => m.text), contains('preheat'));
      expect(agent.history.map((m) => m.text), isNot(contains('again')));
    });

    test('a refresh asked while a press runs sends nothing', () async {
      final backend = _Backend();
      final agent = await _agent(backend);
      final press = agent.sendMessage('preheat');
      await pumpEventQueue();

      await agent.refresh('again');
      expect(backend.requests, hasLength(1));

      backend.answer(0, _reply('s_1', 'press'));
      await press;
      await pumpEventQueue();
      expect(_text(agent, 'dashboard'), 'press');
    });

    test('a refresh the surface rejects changes nothing', () async {
      final backend = _Backend();
      final agent = await _agent(backend);
      final seed = agent.sendMessage('hello');
      await pumpEventQueue();
      backend.answer(0, _reply('s_1', 'seed'));
      await seed;
      await pumpEventQueue();

      final refresh = agent.refresh('again');
      await pumpEventQueue();
      backend.answer(1, 'no messages here');

      await expectLater(refresh, throwsA(isA<RejectedReply>()));
      expect(_text(agent, 'dashboard'), 'seed');
    });

    test(
      'a turn the surface rejects is rolled back like a failed one',
      () async {
        final backend = _Backend();
        final agent = await _agent(backend);
        final events = <GenUIAgentEvent>[];
        agent.events.listen(events.add);

        final turn = agent.sendMessage('hello');
        await pumpEventQueue();
        backend.answer(0, 'no messages here');

        await expectLater(turn, throwsA(isA<RejectedReply>()));
        await pumpEventQueue();
        expect(agent.history, isEmpty);
        expect(events.whereType<UserTurnRolledBack>(), hasLength(1));
      },
    );

    test('an invalid component is not sent back as a model turn', () async {
      final backend = _Backend();
      final agent = await _agent(backend);
      final seed = agent.sendMessage('hello');
      await pumpEventQueue();
      backend.answer(0, _reply('s_1', 'seed'));
      await seed;
      await pumpEventQueue();

      final refresh = agent.refresh('again');
      await pumpEventQueue();
      // A `Text` without its required `text`: the renderer reports it.
      backend.answer(
        1,
        _reply('s_2', 'x').replaceAll(',"text":"x"', ''),
      );
      await refresh;
      await pumpEventQueue();

      // No third request: nothing asked the model to "fix" a dashboard it
      // cannot see, and the history holds only the two real turns.
      expect(backend.requests, hasLength(2));
      expect(agent.history.map((m) => m.text), hasLength(2));
    });

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
    Map<String, Object?> update(String surfaceId, Object? value) => {
      'version': 'v0.9',
      'updateDataModel': {
        'surfaceId': surfaceId,
        'path': '/devices/oven',
        'value': value,
      },
    };

    /// A reply that seeds the oven's values, as the backend's binder does.
    String replyWithSeed(String surfaceId, Object? value) =>
        '${_reply(surfaceId, 'screen')}\n```json\n'
        '${jsonEncode(update(surfaceId, value))}\n```';

    Object? oven(HttpGenUIAgent agent, String surfaceId) => agent.controller
        .contextFor(surfaceId)
        .dataModel
        .getValue<Object?>(DataPath('/devices/oven'));

    Future<HttpGenUIAgent> withSurface(_Backend backend) async {
      final agent = await _agent(backend);
      final turn = agent.sendMessage('hello');
      await pumpEventQueue();
      backend.answer(0, replyWithSeed('s_1', {'status': 'Off'}));
      await turn;
      await pumpEventQueue();
      return agent;
    }

    test('moves a value of the surface in place', () async {
      final agent = await withSurface(_Backend());
      expect(oven(agent, 'dashboard'), {'status': 'Off'});

      // The backend does not know which surface the model named.
      agent.apply(update('whatever', {'status': 'Preheating'}));
      await pumpEventQueue();

      expect(oven(agent, 'dashboard'), {'status': 'Preheating'});
      expect(_text(agent, 'dashboard'), 'screen');
    });

    test('puts the newest value back when a reply lands over it', () async {
      final backend = _Backend();
      final agent = await withSurface(backend);

      final refresh = agent.refresh('again');
      await pumpEventQueue();
      // A device changes while the reply is on its way, and the screen is told.
      agent.apply(update('dashboard', {'status': 'Ready'}));
      await pumpEventQueue();
      // The reply was written before it changed, so it says the old value.
      backend.answer(1, replyWithSeed('s_2', {'status': 'Preheating'}));
      await refresh;
      await pumpEventQueue();

      expect(oven(agent, 'dashboard'), {'status': 'Ready'});
    });

    test('keeps only the latest message for each path', () async {
      final backend = _Backend();
      final agent = await withSurface(backend);
      agent
        ..apply(update('dashboard', {'status': 'One'}))
        ..apply(update('dashboard', {'status': 'Two'}));

      final refresh = agent.refresh('again');
      await pumpEventQueue();
      backend.answer(1, replyWithSeed('s_2', {'status': 'Old'}));
      await refresh;
      await pumpEventQueue();

      expect(oven(agent, 'dashboard'), {'status': 'Two'});
    });

    test('ignores a message the renderer cannot read', () async {
      final agent = await withSurface(_Backend());

      agent
        ..apply({'version': 'v0.9', 'mystery': 1})
        ..apply({'version': 'v0.1', 'deleteSurface': 3});
      await pumpEventQueue();

      expect(oven(agent, 'dashboard'), {'status': 'Off'});
    });

    test('ignores a message before the agent has started', () {
      final agent = HttpGenUIAgent(
        catalog: testCatalog,
        widgetBuilders: testWidgetBuilders,
        tokenProvider: () async => 'token',
        client: _Backend().client,
        stableSurfaceId: 'dashboard',
      );
      addTearDown(agent.dispose);

      expect(() => agent.apply(update('dashboard', 1)), returnsNormally);
    });

    test(
      'hands a message on as it is when there is no stable surface',
      () async {
        final backend = _Backend();
        final agent = await _agent(backend, stableSurfaceId: null);
        final turn = agent.sendMessage('hello');
        await pumpEventQueue();
        backend.answer(0, _reply('s_9', 'screen'));
        await turn;
        await pumpEventQueue();

        agent.apply(update('s_9', {'status': 'Preheating'}));
        await pumpEventQueue();

        expect(oven(agent, 's_9'), {'status': 'Preheating'});
      },
    );
  });

  group('HttpGenUIAgent without a stable surface', () {
    test('still sends a renderer error report to the model', () async {
      final backend = _Backend();
      final agent = await _agent(backend, stableSurfaceId: null);

      final turn = agent.sendMessage('hello');
      await pumpEventQueue();
      backend.answer(0, _reply('s_1', 'x').replaceAll(',"text":"x"', ''));
      await turn;
      await pumpEventQueue();

      expect(backend.requests, hasLength(2));
    });

    test('hands the reply to the renderer as the model wrote it', () async {
      final backend = _Backend();
      final agent = await _agent(backend, stableSurfaceId: null);

      final refresh = agent.refresh('again');
      await pumpEventQueue();
      backend.answer(0, _reply('s_9', 'as written'));
      await refresh;
      await pumpEventQueue();

      expect(_text(agent, 's_9'), 'as written');
      expect(_text(agent, 'dashboard'), isNull);
    });
  });
}
