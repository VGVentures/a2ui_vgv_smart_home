import 'dart:convert';
import 'dart:io';

import 'package:dart_frog/dart_frog.dart';
import 'package:home_backend/data/mock_database.dart';
import 'package:home_backend/devices/device_state_machine.dart';
import 'package:home_backend/live/live_hub.dart';
import 'package:home_backend/live/live_session.dart';
import 'package:home_backend/llm/llm.dart';
import 'package:home_backend/scenario/scenario_world.dart';
import 'package:home_backend/session/demo_session.dart';
import 'package:home_backend/session/session_middleware.dart';
import 'package:home_backend/session/session_store.dart';
import 'package:mocktail/mocktail.dart';
import 'package:test/test.dart';

class _MockRequestContext extends Mock implements RequestContext {}

class _MockRequest extends Mock implements Request {}

/// A context that remembers what the middleware provided to it.
class _Probe {
  final provided = <Type, Object>{};
  late final _MockRequestContext context;
}

_Probe _probe({String? sessionId, String? protocols, String path = '/users'}) {
  final probe = _Probe();
  final context = probe.context = _MockRequestContext();
  final request = _MockRequest();
  when(() => context.request).thenReturn(request);
  when(() => request.uri).thenReturn(Uri.parse('http://localhost:8080$path'));
  when(() => request.headers).thenReturn({
    'x-session-id': ?sessionId,
    'sec-websocket-protocol': ?protocols,
  });
  void capture<T extends Object>() {
    when(() => context.provide<T>(any())).thenAnswer((invocation) {
      final create = invocation.positionalArguments.single as T Function();
      probe.provided[T] = create();
      return context;
    });
  }

  capture<MockDatabase>();
  capture<DeviceStateMachine>();
  capture<ScenarioWorld>();
  capture<LiveHub>();
  capture<Generate>();
  return probe;
}

Future<DemoSession> _build() async {
  final database = await MockDatabase.load();
  final hub = LiveHub();
  final world = ScenarioWorld(database, live: hub);
  return DemoSession(
    database: database,
    machine: DeviceStateMachine(database, onChanged: world.reconcile),
    world: world,
    hub: hub,
    generate: (_, _) async => 'reply',
  );
}

void main() {
  setUpAll(() {
    registerFallbackValue(() => 0);
  });

  group('provideSession', () {
    late SessionStore store;
    late Handler handler;

    setUp(() {
      store = SessionStore(factory: _build, maxSessions: 1);
      handler = provideSession(store)((_) => Response(body: 'ok'));
    });

    test('rejects a request with no session id', () async {
      final response = await handler(_probe().context);

      expect(response.statusCode, HttpStatus.badRequest);
      final body = jsonDecode(await response.body()) as Map<String, dynamic>;
      expect(body['message'], 'Missing session id');
    });

    for (final id in [
      'short',
      'has spaces in it 1234',
      'a' * 65,
      '../etc/passwd',
    ]) {
      test('rejects the malformed id "$id"', () async {
        final response = await handler(_probe(sessionId: id).context);

        expect(response.statusCode, HttpStatus.badRequest);
      });
    }

    test("provides the visitor's own world to the route", () async {
      final probe = _probe(sessionId: 'a' * 16);

      final response = await handler(probe.context);
      final session = await store.obtain('a' * 16);

      expect(response.statusCode, HttpStatus.ok);
      expect(probe.provided[MockDatabase], same(session.database));
      expect(probe.provided[DeviceStateMachine], same(session.machine));
      expect(probe.provided[ScenarioWorld], same(session.world));
      expect(probe.provided[LiveHub], same(session.hub));
      expect(probe.provided[Generate], same(session.generate));
    });

    test('two visitors are given different worlds', () async {
      final storeOfTwo = SessionStore(factory: _build);
      final both = provideSession(storeOfTwo)((_) => Response(body: 'ok'));
      final a = _probe(sessionId: 'a' * 16);
      final b = _probe(sessionId: 'b' * 16);

      await both(a.context);
      await both(b.context);

      expect(a.provided[MockDatabase], isNot(same(b.provided[MockDatabase])));
      expect(a.provided[ScenarioWorld], isNot(same(b.provided[ScenarioWorld])));
    });

    test('reads the id of /live from the subprotocol', () async {
      final probe = _probe(
        path: '/live',
        protocols: '$liveProtocol, ${'a' * 16}',
      );

      final response = await handler(probe.context);

      expect(response.statusCode, HttpStatus.ok);
      expect(probe.provided[LiveHub], isNotNull);
    });

    test('rejects /live without an id beside the protocol', () async {
      final response = await handler(
        _probe(path: '/live', protocols: liveProtocol).context,
      );

      expect(response.statusCode, HttpStatus.badRequest);
    });

    test('answers 503 for a new visitor when the demo is full', () async {
      final first = await store.obtain('a' * 16);
      final stop = first.hub.listen((_) {});

      final response = await handler(_probe(sessionId: 'b' * 16).context);

      expect(response.statusCode, HttpStatus.serviceUnavailable);
      stop();
    });

    for (final path in ['/health', '/transcribe']) {
      test('lets $path through with no world', () async {
        final probe = _probe(path: path);

        final response = await handler(probe.context);

        expect(response.statusCode, HttpStatus.ok);
        expect(probe.provided, isEmpty);
        expect(store.length, 0);
      });
    }
  });
}
