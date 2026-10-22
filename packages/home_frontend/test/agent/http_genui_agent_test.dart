import 'dart:async';
import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:genui/genui.dart';
import 'package:home_frontend/home_frontend.dart';
// ConversationEventReceived is internal to the kit, so the barrel omits it.
import 'package:home_frontend/src/agent/genui_agent_event.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';

import '../helpers/basic_components.dart';

HttpGenUIAgent _newAgent({
  http.Client? client,
  GenUITokenProvider? tokenProvider,
  String? sessionId,
}) => HttpGenUIAgent(
  catalog: testCatalog,
  widgetBuilders: testWidgetBuilders,
  client: client,
  tokenProvider: tokenProvider ?? () async => 'test-token',
  sessionId: sessionId,
);

http.StreamedResponse _jsonResponse(Object body, {int status = 200}) {
  final encoded = body is String ? body : jsonEncode(body);
  return http.StreamedResponse(
    Stream.value(utf8.encode(encoded)),
    status,
    headers: {'content-type': 'application/json; charset=utf-8'},
  );
}

/// A [MockClient] that decodes each request body into [bodies] and replies with
/// a minimal success. Lets a test assert what reached the wire without
/// repeating the decode plumbing on every case.
http.Client _recordingClient(List<Map<String, dynamic>> bodies) {
  return MockClient.streaming((request, body) async {
    final raw = await body.toBytes();
    bodies.add(jsonDecode(utf8.decode(raw)) as Map<String, dynamic>);
    return _jsonResponse({'text': 'ack'});
  });
}

/// Registers a surface holding a single button labelled [label], as a model
/// turn would, so a press on `button-1` can resolve it from the registry.
void _seedButtonSurface(
  HttpGenUIAgent agent, {
  String label = 'Testing',
  String surfaceId = 'surface-1',
}) {
  agent.controller
    ..handleMessage(
      CreateSurface(surfaceId: surfaceId, catalogId: homeCatalog.id),
    )
    ..handleMessage(
      UpdateComponents(
        surfaceId: surfaceId,
        components: [
          const Component(
            id: 'button-1',
            type: 'Button',
            properties: {
              'child': 'label-1',
              'action': {
                'event': {'name': 'selectTopic'},
              },
            },
          ),
          Component(
            id: 'label-1',
            type: 'Text',
            properties: {'text': label},
          ),
        ],
      ),
    );
}

/// Dispatches a button press from `button-1` the way genui's `Surface` does,
/// then drains the queue so the resulting turn completes.
Future<void> _pressButton(
  HttpGenUIAgent agent, {
  String name = 'selectTopic',
  String? surfaceId = 'surface-1',
}) async {
  agent.controller.handleUiEvent(
    UserActionEvent(
      surfaceId: surfaceId,
      name: name,
      sourceComponentId: 'button-1',
    ),
  );
  await pumpEventQueue();
}

void main() {
  group(HttpGenUIAgent, () {
    test('dispose before start does not touch uninitialized resources', () {
      // start() is what allocates SurfaceController, Conversation, and the
      // transport. Calling dispose() on an agent that has not started must
      // short-circuit before any of the late-final fields are read.
      _newAgent().dispose();
    });

    test('exposes a broadcast events stream before start is called', () {
      // Consumers (e.g. GenUIZoneController) subscribe to events before
      // invoking start(), so the stream must be available at construction
      // and support multiple listeners attaching over the agent's lifetime.
      final agent = _newAgent();
      addTearDown(agent.dispose);

      expect(agent.events.isBroadcast, isTrue);
    });

    test('sendMessage before start throws StateError', () async {
      final agent = _newAgent();
      addTearDown(agent.dispose);

      await expectLater(agent.sendMessage('hi'), throwsA(isA<StateError>()));
    });

    test('start can only be called once', () async {
      // Second start would re-assign the late-final fields. The guard must
      // surface as a StateError rather than a LateInitializationError so a
      // refactor that swaps the guard surfaces clearly.
      final agent = _newAgent();
      addTearDown(agent.dispose);

      await agent.start();
      await expectLater(agent.start(), throwsA(isA<StateError>()));
    });

    test('history is empty before any message is sent', () {
      // Callers may inspect history before start() to render an empty
      // conversation log; the agent must expose a usable empty view.
      final agent = _newAgent();
      addTearDown(agent.dispose);

      expect(agent.history, isEmpty);
    });

    test('history is read-only', () {
      // The agent owns the conversation log and replays it to the LLM on
      // every turn; callers must not be able to mutate it from outside.
      final agent = _newAgent();
      addTearDown(agent.dispose);

      expect(
        () => agent.history.add(ChatMessage.user('hi')),
        throwsUnsupportedError,
      );
    });

    test('throws when the server returns a 5xx response', () async {
      final client = MockClient.streaming((request, _) async {
        return _jsonResponse({'message': 'boom'}, status: 500);
      });
      final agent = _newAgent(client: client);
      addTearDown(agent.dispose);

      await agent.start();
      await expectLater(agent.sendMessage('hi'), throwsA(isA<HttpException>()));
    });

    test('surfaces a 422 validation failure with its message', () async {
      final client = MockClient.streaming((request, _) async {
        return _jsonResponse({'message': 'bad widget'}, status: 422);
      });
      final agent = _newAgent(client: client);
      addTearDown(agent.dispose);

      await agent.start();
      await expectLater(
        agent.sendMessage('hi'),
        throwsA(
          isA<HttpException>().having(
            (e) => e.message,
            'message',
            contains('bad widget'),
          ),
        ),
      );
    });

    test('surfaces a 502 provider failure with its message', () async {
      final client = MockClient.streaming((request, _) async {
        return _jsonResponse({'message': 'provider down'}, status: 502);
      });
      final agent = _newAgent(client: client);
      addTearDown(agent.dispose);

      await agent.start();
      await expectLater(
        agent.sendMessage('hi'),
        throwsA(
          isA<HttpException>().having(
            (e) => e.message,
            'message',
            contains('provider down'),
          ),
        ),
      );
    });

    test('throws HttpException when a 2xx body is not JSON', () async {
      // A proxy or misbehaving server can return a 2xx with an HTML error page.
      // It must surface as an HttpException like the non-2xx path, not escape
      // as a raw FormatException.
      final client = MockClient.streaming((request, _) async {
        return _jsonResponse('<html>oops</html>');
      });
      final agent = _newAgent(client: client);
      addTearDown(agent.dispose);

      await agent.start();
      await expectLater(
        agent.sendMessage('hi'),
        throwsA(isA<HttpException>()),
      );
      // A failed turn leaves history valid for the next request.
      expect(agent.history, isEmpty);
    });

    test('throws HttpException when a 2xx body is a JSON array', () async {
      final client = MockClient.streaming((request, _) async {
        return _jsonResponse([1, 2, 3]);
      });
      final agent = _newAgent(client: client);
      addTearDown(agent.dispose);

      await agent.start();
      await expectLater(
        agent.sendMessage('hi'),
        throwsA(isA<HttpException>()),
      );
      expect(agent.history, isEmpty);
    });

    test('throws HttpException when the text field is not a string', () async {
      final client = MockClient.streaming((request, _) async {
        return _jsonResponse({'text': 42});
      });
      final agent = _newAgent(client: client);
      addTearDown(agent.dispose);

      await agent.start();
      await expectLater(
        agent.sendMessage('hi'),
        throwsA(isA<HttpException>()),
      );
      expect(agent.history, isEmpty);
    });

    test('replays prior history to the backend on subsequent turns', () async {
      // The server treats the last message as the prompt and earlier
      // messages as conversation context, so each turn must include the
      // accumulated transcript.
      final bodies = <Map<String, dynamic>>[];
      final client = MockClient.streaming((request, body) async {
        final raw = await body.toBytes();
        bodies.add(jsonDecode(utf8.decode(raw)) as Map<String, dynamic>);
        return _jsonResponse({'text': 'hi back'});
      });
      final agent = _newAgent(client: client);
      addTearDown(agent.dispose);

      await agent.start();
      await agent.sendMessage('first');
      await agent.sendMessage('second');

      expect(bodies, hasLength(2));
      expect(bodies.first['messages'], [
        {'role': 'user', 'content': 'first'},
      ]);
      expect(bodies.last['messages'], [
        {'role': 'user', 'content': 'first'},
        {'role': 'assistant', 'content': 'hi back'},
        {'role': 'user', 'content': 'second'},
      ]);
      expect(agent.history.map((m) => m.text).toList(), [
        'first',
        'hi back',
        'second',
        'hi back',
      ]);
    });

    test(
      'transmits a server-action button press as non-empty content',
      () async {
        // A button with a server `action` dispatches a UserActionEvent, which
        // the controller turns into a ChatMessage carrying a UiInteractionPart
        // and no text. Serializing from ChatMessage.text alone would send
        // empty content that the server rejects with 422, so the interaction
        // payload must reach the wire instead.
        final bodies = <Map<String, dynamic>>[];
        final agent = _newAgent(client: _recordingClient(bodies));
        addTearDown(agent.dispose);

        await agent.start();
        agent.controller.handleUiEvent(
          UserActionEvent(
            surfaceId: 'surface-1',
            name: 'submitOrder',
            sourceComponentId: 'button-1',
          ),
        );
        // Controller-dispatched turns run through Conversation.sendRequest
        // asynchronously; drain the queue so the request is sent and its state
        // update settles before teardown disposes the conversation.
        await pumpEventQueue();

        expect(bodies, hasLength(1));
        final last =
            (bodies.single['messages'] as List).last as Map<String, dynamic>;
        expect(last['role'], 'user');
        final content = last['content'] as String;
        expect(content, isNotEmpty);
        expect(content, contains('"action"'));
        expect(content, contains('submitOrder'));
      },
    );

    test(
      'transmits a validation report as non-empty content',
      () async {
        // reportError travels the same UiInteractionPart path as button
        // presses, so its error payload must also reach the wire rather than
        // serialize to empty content.
        final bodies = <Map<String, dynamic>>[];
        final agent = _newAgent(client: _recordingClient(bodies));
        addTearDown(agent.dispose);

        await agent.start();
        agent.controller.reportError(Exception('bad surface'), null);
        await pumpEventQueue();

        expect(bodies, hasLength(1));
        final content =
            ((bodies.single['messages'] as List).last
                    as Map<String, dynamic>)['content']
                as String;
        expect(content, isNotEmpty);
        expect(content, contains('RUNTIME_ERROR'));
        expect(content, contains('bad surface'));
      },
    );

    test(
      'replays a prior interaction turn with non-empty content',
      () async {
        // An interaction turn kept in history must also serialize its payload
        // when replayed on the next turn; otherwise the follow-up request
        // carries an empty history entry the server rejects.
        final bodies = <Map<String, dynamic>>[];
        final agent = _newAgent(client: _recordingClient(bodies));
        addTearDown(agent.dispose);

        await agent.start();
        agent.controller.handleUiEvent(
          UserActionEvent(
            surfaceId: 'surface-1',
            name: 'submitOrder',
            sourceComponentId: 'button-1',
          ),
        );
        // Let the interaction turn complete so its model reply is appended to
        // history before the next turn replays it.
        await pumpEventQueue();
        await agent.sendMessage('follow up');

        expect(bodies, hasLength(2));
        final replayed =
            (bodies.last['messages'] as List).first as Map<String, dynamic>;
        expect(replayed['role'], 'user');
        expect(replayed['content'] as String, isNotEmpty);
        expect(replayed['content'] as String, contains('submitOrder'));
      },
    );

    test('drops the user message from history when a turn fails', () async {
      // The server rejects two consecutive user messages, so a failed turn
      // must leave history in a state where the next sendMessage is valid.
      final client = MockClient.streaming((request, _) async {
        return _jsonResponse({'message': 'boom'}, status: 500);
      });
      final agent = _newAgent(client: client);
      addTearDown(agent.dispose);

      await agent.start();
      await expectLater(agent.sendMessage('hi'), throwsA(isA<HttpException>()));

      expect(agent.history, isEmpty);
    });

    test('reports the rollback so the zone can drop its item too', () async {
      // The zone renders its own transcript; without this event it keeps a
      // bubble for a turn the model never saw.
      final client = MockClient.streaming((request, _) async {
        return _jsonResponse({'message': 'boom'}, status: 500);
      });
      final agent = _newAgent(client: client);
      addTearDown(agent.dispose);

      await agent.start();
      final events = <GenUIAgentEvent>[];
      agent.events.listen(events.add);

      await expectLater(agent.sendMessage('hi'), throwsA(isA<HttpException>()));
      await pumpEventQueue();

      expect(events.whereType<UserTurnRolledBack>(), hasLength(1));
    });

    test('reports a rollback when the reply is empty', () async {
      final client = MockClient.streaming((request, _) async {
        return _jsonResponse({'text': ''});
      });
      final agent = _newAgent(client: client);
      addTearDown(agent.dispose);

      await agent.start();
      final events = <GenUIAgentEvent>[];
      agent.events.listen(events.add);

      await expectLater(
        agent.sendMessage('hi'),
        throwsA(isA<EmptyResponseException>()),
      );
      await pumpEventQueue();

      expect(events.whereType<UserTurnRolledBack>(), hasLength(1));
    });

    test(
      'surfaces an empty reply as a failure rather than a silent turn',
      () async {
        // The turn produced nothing, so it reaches the zone through the same
        // path as any other failure instead of looking like an unanswered
        // message.
        final client = MockClient.streaming((request, _) async {
          return _jsonResponse({'text': ''});
        });
        final agent = _newAgent(client: client);
        addTearDown(agent.dispose);

        await agent.start();

        await expectLater(
          agent.sendMessage('hi'),
          throwsA(
            isA<EmptyResponseException>().having(
              (e) => e.message,
              'message',
              contains('empty reply'),
            ),
          ),
        );
      },
    );

    test('does not report an empty reply as a transport failure', () async {
      // The request succeeded and the body was on-contract, so a host
      // catching `on HttpException` to retry the transport must not see it.
      final client = MockClient.streaming((request, _) async {
        return _jsonResponse({'text': ''});
      });
      final agent = _newAgent(client: client);
      addTearDown(agent.dispose);

      await agent.start();

      await expectLater(
        agent.sendMessage('hi'),
        throwsA(isNot(isA<HttpException>())),
      );
    });

    test('reports no rollback when the turn is kept', () async {
      final client = MockClient.streaming((request, _) async {
        return _jsonResponse({'text': 'hello'});
      });
      final agent = _newAgent(client: client);
      addTearDown(agent.dispose);

      await agent.start();
      final events = <GenUIAgentEvent>[];
      agent.events.listen(events.add);

      await agent.sendMessage('hi');
      await pumpEventQueue();

      expect(events.whereType<UserTurnRolledBack>(), isEmpty);
    });

    test(
      "sends the session id so the backend uses this visitor's world",
      () async {
        String? sent;
        final client = MockClient.streaming((request, _) async {
          sent = request.headers['X-Session-Id'];
          return _jsonResponse({'text': 'ok'});
        });
        final agent = _newAgent(client: client, sessionId: 'visitor-1');
        addTearDown(agent.dispose);

        await agent.start();
        await agent.sendMessage('hi');

        expect(sent, 'visitor-1');
      },
    );

    test('sends no session header when it has no session id', () async {
      Map<String, String>? sent;
      final client = MockClient.streaming((request, _) async {
        sent = request.headers;
        return _jsonResponse({'text': 'ok'});
      });
      final agent = _newAgent(client: client);
      addTearDown(agent.dispose);

      await agent.start();
      await agent.sendMessage('hi');

      expect(sent, isNot(contains('X-Session-Id')));
    });

    test('attaches a Bearer token from the provider', () async {
      String? sentAuth;
      final client = MockClient.streaming((request, _) async {
        sentAuth = request.headers['Authorization'];
        return _jsonResponse({'text': 'ok'});
      });
      final agent = _newAgent(
        client: client,
        tokenProvider: () async => 'my-token',
      );
      addTearDown(agent.dispose);

      await agent.start();
      await agent.sendMessage('hi');

      expect(sentAuth, 'Bearer my-token');
    });

    test(
      'throws AuthError and skips the request when the provider returns null',
      () async {
        var requested = false;
        final client = MockClient.streaming((request, _) async {
          requested = true;
          return _jsonResponse({'text': 'ok'});
        });
        final agent = _newAgent(
          client: client,
          tokenProvider: () async => null,
        );
        addTearDown(agent.dispose);

        await agent.start();
        await expectLater(
          agent.sendMessage('hi'),
          throwsA(isA<AuthError>()),
        );
        expect(requested, isFalse);
        expect(agent.history, isEmpty);
      },
    );

    test(
      'throws AuthError and skips the request when the provider returns empty',
      () async {
        var requested = false;
        final client = MockClient.streaming((request, _) async {
          requested = true;
          return _jsonResponse({'text': 'ok'});
        });
        final agent = _newAgent(
          client: client,
          tokenProvider: () async => '',
        );
        addTearDown(agent.dispose);

        await agent.start();
        await expectLater(
          agent.sendMessage('hi'),
          throwsA(isA<AuthError>()),
        );
        expect(requested, isFalse);
        expect(agent.history, isEmpty);
      },
    );

    test(
      'throws AuthError and skips the request when the provider fails',
      () async {
        var requested = false;
        final client = MockClient.streaming((request, _) async {
          requested = true;
          return _jsonResponse({'text': 'ok'});
        });
        final agent = _newAgent(
          client: client,
          tokenProvider: () => Future.error(StateError('signed out')),
        );
        addTearDown(agent.dispose);

        await agent.start();
        await expectLater(
          agent.sendMessage('hi'),
          throwsA(isA<AuthError>()),
        );
        expect(requested, isFalse);
        expect(agent.history, isEmpty);
      },
    );

    test('throws AuthError on a 401 response', () async {
      final client = MockClient.streaming((request, _) async {
        return _jsonResponse({'message': 'Unauthorized'}, status: 401);
      });
      final agent = _newAgent(
        client: client,
        tokenProvider: () async => 'bad-token',
      );
      addTearDown(agent.dispose);

      await agent.start();
      await expectLater(
        agent.sendMessage('hi'),
        throwsA(isA<AuthError>()),
      );
      expect(agent.history, isEmpty);
    });

    test('AuthError is catchable as HttpException', () async {
      // The subtype relationship lets existing `catch on HttpException`
      // continue to handle auth failures, while UI code that needs the
      // distinction catches AuthError directly.
      final client = MockClient.streaming((request, _) async {
        return _jsonResponse({'message': 'Unauthorized'}, status: 401);
      });
      final agent = _newAgent(
        client: client,
        tokenProvider: () async => 'bad-token',
      );
      addTearDown(agent.dispose);

      await agent.start();
      await expectLater(
        agent.sendMessage('hi'),
        throwsA(isA<HttpException>()),
      );
    });

    test('emits UserMessageAdded before the transport runs', () async {
      // The bubble must appear immediately, before the response body drains.
      // Hold the response open so the event must fire before sendMessage
      // resolves — otherwise this test could pass even if the event were
      // emitted at the end of sendMessage.
      final responseCompleter = Completer<void>();
      final client = MockClient.streaming((request, _) async {
        return http.StreamedResponse(
          Stream.fromFuture(
            responseCompleter.future.then(
              (_) => utf8.encode(jsonEncode({'text': 'ok'})),
            ),
          ),
          200,
          headers: {'content-type': 'application/json; charset=utf-8'},
        );
      });
      final agent = _newAgent(client: client);
      addTearDown(agent.dispose);

      await agent.start();

      final events = <GenUIAgentEvent>[];
      agent.events.listen(events.add);

      final sendFuture = agent.sendMessage('hello');
      await Future<void>.delayed(Duration.zero);

      expect(events.whereType<UserMessageAdded>().toList(), hasLength(1));
      expect(events.whereType<UserMessageAdded>().first.text, 'hello');

      responseCompleter.complete();
      await sendFuture;
    });

    group('UI interaction lifecycle', () {
      test(
        'emits UiInteractionAdded labelled with the pressed button text',
        () async {
          // The record uses the button's visible label, not the model-authored
          // action name, so the learner recognises their own choice.
          final agent = _newAgent(client: _recordingClient([]));
          addTearDown(agent.dispose);

          await agent.start();
          final events = <GenUIAgentEvent>[];
          agent.events.listen(events.add);

          _seedButtonSurface(agent);
          await _pressButton(agent);

          expect(
            events.whereType<UiInteractionAdded>().map((e) => e.label),
            ['Testing'],
          );
        },
      );

      test('resolves a label nested below the pressed button', () async {
        // A model is free to wrap the label in a Column, so the walk goes down
        // from the pressed component rather than reading one property.
        final agent = _newAgent(client: _recordingClient([]));
        addTearDown(agent.dispose);

        await agent.start();
        final events = <GenUIAgentEvent>[];
        agent.events.listen(events.add);

        agent.controller
          ..handleMessage(
            CreateSurface(
              surfaceId: 'surface-1',
              catalogId: homeCatalog.id,
            ),
          )
          ..handleMessage(
            const UpdateComponents(
              surfaceId: 'surface-1',
              components: [
                Component(
                  id: 'button-1',
                  type: 'Button',
                  properties: {'child': 'col-1'},
                ),
                Component(
                  id: 'col-1',
                  type: 'Column',
                  properties: {
                    'children': ['label-1'],
                  },
                ),
                Component(
                  id: 'label-1',
                  type: 'Text',
                  properties: {'text': 'CI/CD'},
                ),
              ],
            ),
          );
        await _pressButton(agent);

        expect(
          events.whereType<UiInteractionAdded>().map((e) => e.label),
          ['CI/CD'],
        );
      });

      test('takes the first label when a button holds several', () async {
        // Pins which text wins, since traversal order is what decides the
        // scrollback entry: children are read in declaration order.
        final agent = _newAgent(client: _recordingClient([]));
        addTearDown(agent.dispose);

        await agent.start();
        final events = <GenUIAgentEvent>[];
        agent.events.listen(events.add);

        agent.controller
          ..handleMessage(
            CreateSurface(
              surfaceId: 'surface-1',
              catalogId: homeCatalog.id,
            ),
          )
          ..handleMessage(
            const UpdateComponents(
              surfaceId: 'surface-1',
              components: [
                Component(
                  id: 'button-1',
                  type: 'Button',
                  properties: {'child': 'row-1'},
                ),
                Component(
                  id: 'row-1',
                  type: 'Row',
                  properties: {
                    'children': ['label-1', 'label-2'],
                  },
                ),
                Component(
                  id: 'label-1',
                  type: 'Text',
                  properties: {'text': 'Testing'},
                ),
                Component(
                  id: 'label-2',
                  type: 'Text',
                  properties: {'text': '12 lessons'},
                ),
              ],
            ),
          );
        await _pressButton(agent);

        expect(
          events.whereType<UiInteractionAdded>().map((e) => e.label),
          ['Testing'],
        );
      });

      test('falls back to the action name for a templated label', () async {
        // A template-array Column binds each row's text to a data path, so
        // there is no literal label down there to resolve.
        final agent = _newAgent(client: _recordingClient([]));
        addTearDown(agent.dispose);

        await agent.start();
        final events = <GenUIAgentEvent>[];
        agent.events.listen(events.add);

        agent.controller
          ..handleMessage(
            CreateSurface(
              surfaceId: 'surface-1',
              catalogId: homeCatalog.id,
            ),
          )
          ..handleMessage(
            const UpdateComponents(
              surfaceId: 'surface-1',
              components: [
                Component(
                  id: 'button-1',
                  type: 'Button',
                  properties: {'child': 'col-1'},
                ),
                Component(
                  id: 'col-1',
                  type: 'Column',
                  properties: {
                    'children': {'componentId': 'label-1', 'path': '/topics'},
                  },
                ),
                Component(
                  id: 'label-1',
                  type: 'Text',
                  properties: {
                    'text': {'path': 'title'},
                  },
                ),
              ],
            ),
          );
        await _pressButton(agent);

        expect(
          events.whereType<UiInteractionAdded>().map((e) => e.label),
          ['selectTopic'],
        );
      });

      test('falls back to the action name when no label resolves', () async {
        // Nothing registered the surface, so there is no component tree to read
        // a label from. The interaction must still be recorded.
        final agent = _newAgent(client: _recordingClient([]));
        addTearDown(agent.dispose);

        await agent.start();
        final events = <GenUIAgentEvent>[];
        agent.events.listen(events.add);

        await _pressButton(agent, name: 'nextLesson');

        expect(
          events.whereType<UiInteractionAdded>().map((e) => e.label),
          ['nextLesson'],
        );
      });

      test(
        'falls back to the action name when the event carries no surface',
        () async {
          // `Surface` stamps the surfaceId on, but an action dispatched without
          // one must not lose its scrollback record.
          final agent = _newAgent(client: _recordingClient([]));
          addTearDown(agent.dispose);

          await agent.start();
          final events = <GenUIAgentEvent>[];
          agent.events.listen(events.add);

          _seedButtonSurface(agent);
          await _pressButton(agent, name: 'nextLesson', surfaceId: null);

          expect(
            events.whereType<UiInteractionAdded>().map((e) => e.label),
            ['nextLesson'],
          );
        },
      );

      test('emits UiInteractionAdded before the request leaves', () async {
        // The record and the in-flight state have to be visible while the turn
        // is still running, not once it resolves.
        final responseCompleter = Completer<void>();
        final client = MockClient.streaming((request, _) async {
          return http.StreamedResponse(
            Stream.fromFuture(
              responseCompleter.future.then(
                (_) => utf8.encode(jsonEncode({'text': 'ok'})),
              ),
            ),
            200,
            headers: {'content-type': 'application/json; charset=utf-8'},
          );
        });
        final agent = _newAgent(client: client);
        addTearDown(agent.dispose);

        await agent.start();
        final events = <GenUIAgentEvent>[];
        agent.events.listen(events.add);

        _seedButtonSurface(agent);
        agent.controller.handleUiEvent(
          UserActionEvent(
            surfaceId: 'surface-1',
            name: 'selectTopic',
            sourceComponentId: 'button-1',
          ),
        );
        await pumpEventQueue();

        expect(events.whereType<UiInteractionAdded>(), hasLength(1));
        expect(events.whereType<UiInteractionCompleted>(), isEmpty);

        responseCompleter.complete();
        await pumpEventQueue();

        expect(events.whereType<UiInteractionCompleted>(), hasLength(1));
      });

      test('emits UiInteractionCompleted when the turn fails', () async {
        // Without this the host stays in its in-flight state forever, so the
        // composer never re-enables after a failed tap.
        final client = MockClient.streaming((request, _) async {
          return _jsonResponse({'message': 'provider down'}, status: 502);
        });
        final agent = _newAgent(client: client);
        addTearDown(agent.dispose);

        await agent.start();
        final events = <GenUIAgentEvent>[];
        agent.events.listen(events.add);

        _seedButtonSurface(agent);
        await _pressButton(agent);

        expect(events.whereType<UiInteractionAdded>(), hasLength(1));
        expect(events.whereType<UiInteractionCompleted>(), hasLength(1));
      });

      test('emits UiInteractionCompleted when the reply is empty', () async {
        // An empty reply produces no surface, and the Conversation absorbs the
        // throw into an event, so the finally clause is what closes the turn.
        final client = MockClient.streaming((request, _) async {
          return _jsonResponse({'text': ''});
        });
        final agent = _newAgent(client: client);
        addTearDown(agent.dispose);

        await agent.start();
        final events = <GenUIAgentEvent>[];
        agent.events.listen(events.add);

        _seedButtonSurface(agent);
        await _pressButton(agent);

        expect(events.whereType<UiInteractionCompleted>(), hasLength(1));
      });

      test('reports a failed interaction as a ConversationError', () async {
        // The SDK's Conversation absorbs the throw into an event, which is the
        // only channel the host has for the failure.
        final client = MockClient.streaming((request, _) async {
          return _jsonResponse({'message': 'provider down'}, status: 502);
        });
        final agent = _newAgent(client: client);
        addTearDown(agent.dispose);

        await agent.start();
        final events = <GenUIAgentEvent>[];
        agent.events.listen(events.add);

        _seedButtonSurface(agent);
        await _pressButton(agent);

        final errors = events
            .whereType<ConversationEventReceived>()
            .map((e) => e.event)
            .whereType<ConversationError>()
            .toList();
        expect(errors, hasLength(1));
        expect(errors.single.error.toString(), contains('provider down'));
      });

      test('emits no interaction events for a typed message', () async {
        // A typed message already reports itself through UserMessageAdded, and
        // the host drives its own in-flight state around sendMessage.
        final agent = _newAgent(client: _recordingClient([]));
        addTearDown(agent.dispose);

        await agent.start();
        final events = <GenUIAgentEvent>[];
        agent.events.listen(events.add);

        await agent.sendMessage('hi');
        await pumpEventQueue();

        expect(events.whereType<UiInteractionAdded>(), isEmpty);
        expect(events.whereType<UiInteractionCompleted>(), isEmpty);
      });

      test('emits no interaction events for a validation report', () async {
        // reportError shares the UiInteractionPart path but is client recovery
        // chatter, not something the user did.
        final agent = _newAgent(client: _recordingClient([]));
        addTearDown(agent.dispose);

        await agent.start();
        final events = <GenUIAgentEvent>[];
        agent.events.listen(events.add);

        agent.controller.reportError(Exception('bad surface'), null);
        await pumpEventQueue();

        expect(events.whereType<UiInteractionAdded>(), isEmpty);
        expect(events.whereType<UiInteractionCompleted>(), isEmpty);
      });
    });

    test('drops the turn when the server returns empty text', () async {
      // The server rejects history entries with empty content, so persisting
      // a `model('')` reply would 400 the next request. An empty reply is
      // treated as a failed turn: both the user message and the empty model
      // message are rolled back.
      final client = MockClient.streaming((request, _) async {
        return _jsonResponse({'text': ''});
      });
      final agent = _newAgent(client: client);
      addTearDown(agent.dispose);

      await agent.start();
      await expectLater(
        agent.sendMessage('hi'),
        throwsA(isA<EmptyResponseException>()),
      );

      expect(agent.history, isEmpty);
    });

    group('POST /action', () {
      /// Records the path and body of every request.
      http.Client recorder(
        List<({String path, Map<String, dynamic> body})> calls, {
        http.StreamedResponse Function()? reply,
      }) {
        return MockClient.streaming((request, body) async {
          final raw = await body.toBytes();
          calls.add((
            path: request.url.path,
            body: jsonDecode(utf8.decode(raw)) as Map<String, dynamic>,
          ));
          return (reply ?? () => _jsonResponse({'text': 'ack'}))();
        });
      }

      Future<List<GenUIAgentEvent>> press(
        HttpGenUIAgent agent, {
        Map<String, Object?>? context,
        String? surfaceId = 'surface-1',
        String name = 'toggle_device',
      }) async {
        await agent.start();
        final events = <GenUIAgentEvent>[];
        agent.events.listen(events.add);
        _seedButtonSurface(agent);
        agent.controller.handleUiEvent(
          UserActionEvent(
            surfaceId: surfaceId,
            name: name,
            sourceComponentId: 'button-1',
            context: context,
          ),
        );
        await pumpEventQueue();
        return events;
      }

      UiInteractionCompleted completed(List<GenUIAgentEvent> events) =>
          events.whereType<UiInteractionCompleted>().single;

      test('sends a surface press to /action with name and context', () async {
        final calls = <({String path, Map<String, dynamic> body})>[];
        final agent = _newAgent(client: recorder(calls));
        addTearDown(agent.dispose);

        final events = await press(
          agent,
          context: {'deviceId': 'oven', 'progressLabel': 'Turn off oven'},
        );

        expect(calls.single.path, '/action');
        expect(calls.single.body['action'], {
          'name': 'toggle_device',
          'context': {'deviceId': 'oven', 'progressLabel': 'Turn off oven'},
        });
        final messages = calls.single.body['messages'] as List;
        final last = messages.last as Map<String, dynamic>;
        expect(last['role'], 'user');
        expect(last['content'], contains('toggle_device'));
        expect(completed(events).succeeded, isTrue);
        expect(completed(events).reason, isNull);
      });

      test('keeps the same auth header as /generate', () async {
        String? auth;
        final client = MockClient.streaming((request, body) async {
          auth = request.headers['Authorization'];
          await body.drain<void>();
          return _jsonResponse({'text': 'ack'});
        });
        final agent = _newAgent(client: client);
        addTearDown(agent.dispose);

        await press(agent);

        expect(auth, 'Bearer test-token');
      });

      test('an empty context is sent as an empty map', () async {
        final calls = <({String path, Map<String, dynamic> body})>[];
        final agent = _newAgent(client: recorder(calls));
        addTearDown(agent.dispose);

        await press(agent);

        expect(calls.single.body['action'], {
          'name': 'toggle_device',
          'context': <String, Object?>{},
        });
      });

      test('an ask press goes to /generate as its plain text', () async {
        final calls = <({String path, Map<String, dynamic> body})>[];
        final agent = _newAgent(client: recorder(calls));
        addTearDown(agent.dispose);

        final events = await press(
          agent,
          name: 'ask',
          context: {
            'text': 'Tell guests dinner is at 8:00',
            'progressLabel': 'Tell guests',
          },
        );

        expect(calls.single.path, '/generate');
        expect(calls.single.body, isNot(contains('action')));
        final messages = calls.single.body['messages'] as List;
        expect(
          (messages.last as Map)['content'],
          'Tell guests dinner is at 8:00',
        );
        expect(
          events.whereType<UiInteractionAdded>().single.label,
          'Tell guests',
        );
        expect(completed(events).succeeded, isTrue);

        // Later in history it is still the plain text.
        await agent.sendMessage('thanks');
        final next = calls.last.body['messages'] as List;
        expect(
          (next.first as Map)['content'],
          'Tell guests dinner is at 8:00',
        );
      });

      test(
        'a failed ask press carries the backend message as reason',
        () async {
          final agent = _newAgent(
            client: recorder(
              [],
              reply: () => _jsonResponse({'message': 'Not now.'}, status: 422),
            ),
          );
          addTearDown(agent.dispose);

          final events = await press(
            agent,
            name: 'ask',
            context: {'text': 'x', 'progressLabel': 'Do x'},
          );

          expect(completed(events).succeeded, isFalse);
          expect(completed(events).reason, 'Not now.');
        },
      );

      test('an ask press without text is sent as its interaction', () async {
        final calls = <({String path, Map<String, dynamic> body})>[];
        final agent = _newAgent(client: recorder(calls));
        addTearDown(agent.dispose);

        await press(agent, name: 'ask', context: {'progressLabel': 'Do x'});

        final messages = calls.single.body['messages'] as List;
        expect((messages.last as Map)['content'], contains('"ask"'));
      });

      test('typed messages still go to /generate without an action', () async {
        final calls = <({String path, Map<String, dynamic> body})>[];
        final agent = _newAgent(client: recorder(calls));
        addTearDown(agent.dispose);
        await agent.start();

        await agent.sendMessage('hi');

        expect(calls.single.path, '/generate');
        expect(calls.single.body, isNot(contains('action')));
      });

      test('an event without a surface goes to /generate', () async {
        final calls = <({String path, Map<String, dynamic> body})>[];
        final agent = _newAgent(client: recorder(calls));
        addTearDown(agent.dispose);

        await press(agent, surfaceId: null);

        expect(calls.single.path, '/generate');
        expect(calls.single.body, isNot(contains('action')));
      });

      test('a validation report goes to /generate', () async {
        final calls = <({String path, Map<String, dynamic> body})>[];
        final agent = _newAgent(client: recorder(calls));
        addTearDown(agent.dispose);
        await agent.start();

        agent.controller.reportError(Exception('bad surface'), null);
        await pumpEventQueue();

        expect(calls.single.path, '/generate');
        expect(calls.single.body, isNot(contains('action')));
      });

      test('labels the turn with context.progressLabel first', () async {
        final agent = _newAgent(client: _recordingClient([]));
        addTearDown(agent.dispose);

        final events = await press(
          agent,
          context: {'progressLabel': '  Turn off oven  '},
        );

        expect(
          events.whereType<UiInteractionAdded>().single.label,
          'Turn off oven',
        );
      });

      test('a blank or non-string progressLabel falls back', () async {
        for (final label in <Object?>['  ', 3]) {
          final agent = _newAgent(client: _recordingClient([]));
          addTearDown(agent.dispose);

          final events = await press(agent, context: {'progressLabel': label});

          expect(
            events.whereType<UiInteractionAdded>().single.label,
            'Testing',
          );
        }
      });

      test('a 4xx carries the backend message as the reason', () async {
        final agent = _newAgent(
          client: recorder(
            [],
            reply: () => _jsonResponse(
              {'message': "Couldn't reach the oven"},
              status: 422,
            ),
          ),
        );
        addTearDown(agent.dispose);

        final events = await press(agent);

        expect(completed(events).succeeded, isFalse);
        expect(completed(events).reason, "Couldn't reach the oven");
        final error = events
            .whereType<ConversationEventReceived>()
            .map((e) => e.event)
            .whereType<ConversationError>()
            .single;
        expect(
          error.error.toString(),
          contains('POST /action failed with status 422'),
        );
      });

      test('a 5xx without a parseable message has no reason', () async {
        for (final body in <String>[
          'oops',
          '{"message": 3}',
          '{"message": " "}',
        ]) {
          final agent = _newAgent(
            client: recorder([], reply: () => _jsonResponse(body, status: 502)),
          );
          addTearDown(agent.dispose);

          final events = await press(agent);

          expect(completed(events).succeeded, isFalse);
          expect(completed(events).reason, isNull);
        }
      });

      test('a 401 has no reason', () async {
        final agent = _newAgent(
          client: recorder(
            [],
            reply: () => _jsonResponse({'message': 'bad token'}, status: 401),
          ),
        );
        addTearDown(agent.dispose);

        final events = await press(agent);

        expect(completed(events).succeeded, isFalse);
        expect(completed(events).reason, isNull);
      });

      test('a token provider failure has no reason', () async {
        final agent = _newAgent(
          client: recorder([]),
          tokenProvider: () async => null,
        );
        addTearDown(agent.dispose);

        final events = await press(agent);

        expect(completed(events).succeeded, isFalse);
        expect(completed(events).reason, isNull);
      });

      test('a network error has no reason', () async {
        final client = MockClient.streaming((request, body) async {
          await body.drain<void>();
          throw http.ClientException('offline');
        });
        final agent = _newAgent(client: client);
        addTearDown(agent.dispose);

        final events = await press(agent);

        expect(completed(events).succeeded, isFalse);
        expect(completed(events).reason, isNull);
      });

      test('an empty reply fails without a reason', () async {
        final agent = _newAgent(
          client: recorder([], reply: () => _jsonResponse({'text': ''})),
        );
        addTearDown(agent.dispose);

        final events = await press(agent);

        expect(completed(events).succeeded, isFalse);
        expect(completed(events).reason, isNull);
      });

      test('a malformed success body fails without a reason', () async {
        final agent = _newAgent(
          client: recorder([], reply: () => _jsonResponse('[]')),
        );
        addTearDown(agent.dispose);

        final events = await press(agent);

        expect(completed(events).succeeded, isFalse);
        expect(completed(events).reason, isNull);
        final error = events
            .whereType<ConversationEventReceived>()
            .map((e) => e.event)
            .whereType<ConversationError>()
            .single;
        expect(error.error.toString(), contains('POST /action returned'));
      });
    });
  });
}
