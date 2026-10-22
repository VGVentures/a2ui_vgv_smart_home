import 'dart:async';

import 'package:home_backend/data/mock_database.dart';
import 'package:home_backend/devices/device_state_machine.dart';
import 'package:home_backend/live/live_hub.dart';
import 'package:home_backend/scenario/scenario_world.dart';
import 'package:home_backend/session/demo_session.dart';
import 'package:home_backend/session/session_store.dart';
import 'package:test/test.dart';

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
  late DateTime now;
  late int built;

  setUp(() {
    now = DateTime(2026);
    built = 0;
  });

  SessionStore store({
    int maxSessions = 200,
    Duration idleTimeout = const Duration(minutes: 30),
    SessionFactory? factory,
  }) => SessionStore(
    factory:
        factory ??
        () {
          built++;
          return _build();
        },
    maxSessions: maxSessions,
    idleTimeout: idleTimeout,
    now: () => now,
  );

  group('SessionStore', () {
    test('gives the same visitor the same world', () async {
      final sessions = store();

      final first = await sessions.obtain('a' * 16);
      final second = await sessions.obtain('a' * 16);

      expect(second, same(first));
      expect(built, 1);
    });

    test('gives each visitor a world of their own', () async {
      final sessions = store();

      final a = await sessions.obtain('a' * 16);
      final b = await sessions.obtain('b' * 16);

      expect(b, isNot(same(a)));
      expect(b.database, isNot(same(a.database)));
      expect(b.world, isNot(same(a.world)));
      expect(b.hub, isNot(same(a.hub)));
      expect(sessions.length, 2);
    });

    test("one visitor's clock does not move another's", () async {
      final sessions = store();
      final a = await sessions.obtain('a' * 16);
      final b = await sessions.obtain('b' * 16);
      final start = b.database.clock.now;

      a.world.moveTo(start.add(const Duration(hours: 3)));

      expect(a.database.clock.now, isNot(start));
      expect(b.database.clock.now, start);
    });

    test('builds a world once for simultaneous first requests', () async {
      final sessions = store();

      final both = await Future.wait([
        sessions.obtain('a' * 16),
        sessions.obtain('a' * 16),
      ]);

      expect(both.first, same(both.last));
      expect(built, 1);
    });

    test('drops a world idle for too long and starts over', () async {
      final sessions = store();
      final first = await sessions.obtain('a' * 16);

      now = now.add(const Duration(minutes: 31));
      await sessions.obtain('b' * 16);

      expect(sessions.length, 1);
      expect(await sessions.obtain('a' * 16), isNot(same(first)));
    });

    test('a request keeps its world from going idle', () async {
      final sessions = store();
      final first = await sessions.obtain('a' * 16);

      now = now.add(const Duration(minutes: 20));
      await sessions.obtain('a' * 16);
      now = now.add(const Duration(minutes: 20));
      await sessions.obtain('b' * 16);

      expect(await sessions.obtain('a' * 16), same(first));
    });

    test('keeps a world whose socket is open however idle', () async {
      final sessions = store();
      final first = await sessions.obtain('a' * 16);
      final stop = first.hub.listen((_) {});

      now = now.add(const Duration(hours: 5));
      await sessions.obtain('b' * 16);

      expect(await sessions.obtain('a' * 16), same(first));
      stop();
    });

    test('at the limit, drops the longest idle world', () async {
      final sessions = store(maxSessions: 2);
      final oldest = await sessions.obtain('a' * 16);
      now = now.add(const Duration(minutes: 1));
      await sessions.obtain('b' * 16);
      now = now.add(const Duration(minutes: 1));

      await sessions.obtain('c' * 16);

      expect(sessions.length, 2);
      expect(await sessions.obtain('a' * 16), isNot(same(oldest)));
    });

    test(
      'at the limit with every visitor connected, refuses a new one',
      () async {
        final sessions = store(maxSessions: 1);
        final a = await sessions.obtain('a' * 16);
        final stop = a.hub.listen((_) {});

        expect(
          () => sessions.obtain('b' * 16),
          throwsA(isA<SessionLimitReached>()),
        );
        expect(const SessionLimitReached().toString(), 'SessionLimitReached');
        stop();
      },
    );

    test('does not keep a world that failed to build', () async {
      var attempts = 0;
      final sessions = store(
        factory: () {
          attempts++;
          return attempts == 1
              ? Future<DemoSession>.error(StateError('no data'))
              : _build();
        },
      );

      await expectLater(
        sessions.obtain('a' * 16),
        throwsA(isA<StateError>()),
      );
      await pumpEventQueue();

      expect(sessions.length, 0);
      expect(await sessions.obtain('a' * 16), isA<DemoSession>());
    });
  });
}
