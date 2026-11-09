import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:dart_frog/dart_frog.dart';
import 'package:home_backend/cors/cors_config.dart';
import 'package:home_backend/data/mock_database.dart';
import 'package:home_backend/live/live_hub.dart';
import 'package:home_backend/live/live_session.dart';
import 'package:home_backend/scenario/scenario_world.dart';
import 'package:test/test.dart';

import '../../routes/live.dart' as route;

/// The JSON frames a socket receives, read one at a time in order.
class _Frames {
  _Frames(WebSocket socket) {
    socket.listen((message) {
      _all.add(jsonDecode(message as String) as Map<String, dynamic>);
      if (_wake case final wake? when !wake.isCompleted) wake.complete();
    });
  }

  final _all = <Map<String, dynamic>>[];
  var _read = 0;
  Completer<void>? _wake;

  Future<Map<String, dynamic>> next() async {
    while (_read >= _all.length) {
      _wake = Completer<void>();
      await _wake!.future.timeout(const Duration(seconds: 2));
    }
    return _all[_read++];
  }
}

void main() {
  late MockDatabase database;
  late LiveHub hub;
  late ScenarioWorld world;
  late String url;

  setUp(() async {
    database = await MockDatabase.load();
    hub = LiveHub();
    world = ScenarioWorld(database, live: hub);
    const Handler handler = route.onRequest;
    final server = await serve(
      handler
          .use(provider<ScenarioWorld>((_) => world))
          .use(provider<LiveHub>((_) => hub))
          .use(
            provider<CorsConfig>(
              (_) => const CorsConfig(
                allowedOrigins: {'https://App.example.com'},
              ),
            ),
          ),
      InternetAddress.loopbackIPv4,
      0,
    );
    addTearDown(() => server.close(force: true));
    url = 'ws://localhost:${server.port}/live';
  });

  Future<WebSocket> connect({String? origin}) async {
    final socket = await WebSocket.connect(
      url,
      protocols: [liveProtocol, 'id-token'],
      headers: {'Origin': ?origin},
    );
    addTearDown(socket.close);
    return socket;
  }

  group('GET /live', () {
    test('selects the protocol name, never the token', () async {
      final socket = await connect();

      expect(socket.protocol, liveProtocol);
    });

    test('says where the clock stands when it connects', () async {
      final frames = _Frames(await connect());

      final clock = await frames.next();

      expect(clock, {
        'type': 'clock',
        'now': '2026-10-10T07:30:00',
        'start': '2026-10-10T07:30:00',
        'end': '2026-10-10T23:59:00',
        'timeZone': 'America/Chicago',
      });
    });

    test('moves the clock and answers with the clock', () async {
      final socket = await connect();
      final frames = _Frames(socket);
      await frames.next();

      socket.add(jsonEncode({'type': 'clock', 'to': '2026-10-10T17:37:00'}));

      expect((await frames.next())['now'], '2026-10-10T17:37:00');
      expect(database.clock.nowIso, '2026-10-10T17:37:00');
    });

    test('tells every connection when one of them moves the clock', () async {
      final mover = await connect();
      final watcher = _Frames(await connect());
      await watcher.next();

      mover.add(jsonEncode({'type': 'clock', 'to': '2026-10-10T17:00:00'}));

      expect((await watcher.next())['now'], '2026-10-10T17:00:00');
    });

    test('pushes a notification the moment it is written', () async {
      final frames = _Frames(await connect());
      await frames.next();

      world.planner.moveGuests(shiftMinutes: -60);

      final seen = <String, Map<String, dynamic>>{};
      for (var i = 0; i < 3; i++) {
        final frame = await frames.next();
        seen[frame['type'] as String] = frame;
      }
      // The oven moves with the dinner, and the dashboard on screen is told
      // with the message that moves the values its card is bound to.
      final update =
          (seen['a2ui']!['message'] as Map)['updateDataModel'] as Map;
      expect(update['path'], '/devices/oven');
      expect((update['value'] as Map)['status'], 'Preheats at 5:30 PM');
      expect(seen['inbox'], containsPair('userId', 'marco'));
      expect(seen['inbox'], containsPair('unread', 1));
      expect(
        (seen['inbox']!['item'] as Map)['title'],
        'Dinner moved to 6:00 PM',
      );
      expect(seen['changed'], {
        'type': 'changed',
        'users': ['marco'],
        'reason': 'plan_change',
      });
    });

    group('answers a frame it cannot read with an error and stays open', () {
      final bad = <String, Object>{
        'text that is not JSON': 'nope',
        'JSON that is not an object': '[1]',
        'a frame of another type': jsonEncode({'type': 'boom'}),
        'a clock frame with no time': jsonEncode({'type': 'clock'}),
        'a time that is not a time': jsonEncode({
          'type': 'clock',
          'to': 'soon',
        }),
        'a binary frame': [1, 2, 3],
      };
      // ignore: cascade_invocations, the loop reads better as a statement.
      bad.forEach((name, message) {
        test(name, () async {
          final socket = await connect();
          final frames = _Frames(socket);
          await frames.next();

          socket.add(message);
          final error = await frames.next();

          expect(error['type'], 'error');
          expect(error['message'], isA<String>());
          socket.add(
            jsonEncode({'type': 'clock', 'to': '2026-10-10T16:45:00'}),
          );
          expect((await frames.next())['now'], '2026-10-10T16:45:00');
        });
      });
    });

    test('stops listening when the client goes away', () async {
      final socket = await connect();
      final frames = _Frames(socket);
      await frames.next();
      expect(hub.listenerCount, 1);

      await socket.close();
      for (var i = 0; i < 50 && hub.listenerCount > 0; i++) {
        await Future<void>.delayed(const Duration(milliseconds: 20));
      }

      expect(hub.listenerCount, 0);
    });

    test('accepts an allowed origin whatever its case', () async {
      final socket = await connect(origin: 'https://app.example.com');

      expect(socket.protocol, liveProtocol);
    });

    test('refuses an origin outside the allowlist', () async {
      await expectLater(
        connect(origin: 'https://evil.example.com'),
        throwsA(isA<WebSocketException>()),
      );
    });
  });
}
