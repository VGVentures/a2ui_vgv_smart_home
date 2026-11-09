import 'dart:convert';

import 'package:home_api_client/home_api_client.dart';
import 'package:home_repository/src/live_repository.dart';
import 'package:home_repository/src/scenario_repository.dart';
import 'package:test/test.dart';
import 'package:web_socket/testing.dart';
import 'package:web_socket/web_socket.dart';
import 'package:web_socket_channel/adapter_web_socket_channel.dart';

void main() {
  group('defaultRetryDelay', () {
    test('doubles from a second up to ten', () {
      expect(
        [for (var i = 0; i < 7; i++) defaultRetryDelay(i).inSeconds],
        [1, 2, 4, 8, 10, 10, 10],
      );
    });
  });

  group('LiveEvent', () {
    test('compare by value', () {
      final reading = ScenarioReading(
        now: DateTime.utc(2026),
        start: DateTime.utc(2026),
        end: DateTime.utc(2027),
      );
      expect(ClockUpdated(reading), ClockUpdated(reading));
      expect(
        const InboxReceived(userId: 'a', unread: 1, title: 't', body: 'b'),
        const InboxReceived(userId: 'a', unread: 1, title: 't', body: 'b'),
      );
      expect(
        const DataChanged(users: ['a'], reason: 'r'),
        const DataChanged(users: ['a'], reason: 'r'),
      );
    });
  });

  group(WebSocketLiveRepository, () {
    late WebSocket server;
    late List<WebSocketEvent> received;
    late List<LiveEvent> events;
    late int connections;
    Uri? connectedTo;
    Iterable<String>? offered;
    WebSocketLiveRepository? repository;

    setUp(() {
      connections = 0;
      connectedTo = null;
      offered = null;
      events = [];
      received = [];
    });

    tearDown(() => repository?.close());

    WebSocketLiveRepository build({
      String baseUrl = 'http://localhost:8080',
      Duration Function(int)? retryDelay,
    }) {
      return repository = WebSocketLiveRepository(
        retryDelay: retryDelay ?? (_) => const Duration(milliseconds: 10),
        client: HomeApiClient(
          sessionId: 'visitor-0123456789abcdef',
          baseUri: Uri.parse(baseUrl),
          connect: (uri, protocols) {
            connections++;
            connectedTo = uri;
            offered = protocols;
            final (client, peer) = fakes(protocol: liveProtocol);
            server = peer;
            peer.events.listen(received.add);
            return AdapterWebSocketChannel(client);
          },
        ),
      )..events.listen(events.add);
    }

    test('opens the socket the client offers', () async {
      await build().connect();

      expect(connectedTo, Uri.parse('ws://localhost:8080/live'));
      expect(offered, [liveProtocol, 'visitor-0123456789abcdef']);
      expect(repository!.isConnected, isTrue);
    });

    test('connecting twice opens one connection', () async {
      final live = build();
      await live.connect();
      await live.connect();

      expect(connections, 1);
    });

    test('moveTo sends a clock frame in wall time', () async {
      final live = build();
      await live.connect();

      final sent = live.moveTo(DateTime.utc(2026, 10, 10, 16, 45));
      await pumpEventQueue();

      expect(sent, isTrue);
      expect(received, [
        TextDataReceived(
          jsonEncode({'type': 'clock', 'to': '2026-10-10T16:45:00'}),
        ),
      ]);
    });

    test('moveTo answers false without a connection', () {
      expect(build().moveTo(DateTime.utc(2026)), isFalse);
    });

    test('turns every kind of frame into an event', () async {
      await build().connect();

      server
        ..sendText(
          jsonEncode({
            'type': 'clock',
            'now': '2026-10-10T16:45:00',
            'start': '2026-10-10T16:30:00',
            'end': '2026-10-10T23:59:00',
          }),
        )
        ..sendText(
          jsonEncode({
            'type': 'inbox',
            'userId': 'marco',
            'unread': 2,
            'item': {'id': 'n1', 'title': 'Plans changed', 'body': 'Earlier'},
          }),
        )
        ..sendText(
          jsonEncode({'type': 'inbox', 'userId': 'ana', 'unread': 0}),
        )
        ..sendText(
          jsonEncode({
            'type': 'changed',
            'users': ['marco'],
            'reason': 'guests_rescheduled',
          }),
        )
        ..sendText(
          jsonEncode({
            'type': 'a2ui',
            'message': {
              'version': 'v0.9',
              'updateDataModel': {
                'surfaceId': 'dashboard',
                'path': '/devices/oven',
                'value': {'status': 'Preheating'},
              },
            },
          }),
        );
      await pumpEventQueue();

      expect(events, [
        ClockUpdated(
          ScenarioReading(
            now: DateTime.utc(2026, 10, 10, 16, 45),
            start: DateTime.utc(2026, 10, 10, 16, 30),
            end: DateTime.utc(2026, 10, 10, 23, 59),
          ),
        ),
        const InboxReceived(
          userId: 'marco',
          unread: 2,
          title: 'Plans changed',
          body: 'Earlier',
        ),
        const InboxReceived(userId: 'ana', unread: 0),
        const DataChanged(users: ['marco'], reason: 'guests_rescheduled'),
        const SurfaceMessageReceived({
          'version': 'v0.9',
          'updateDataModel': {
            'surfaceId': 'dashboard',
            'path': '/devices/oven',
            'value': {'status': 'Preheating'},
          },
        }),
      ]);
    });

    test('skips frames it does not understand', () async {
      await build().connect();

      server
        ..sendBytes(utf8.encode('{}'))
        ..sendText('not json')
        ..sendText('[]')
        ..sendText(jsonEncode({'type': 'mystery'}))
        ..sendText(jsonEncode({'type': 'clock', 'now': 5}))
        ..sendText(jsonEncode({'type': 'changed'}))
        ..sendText(jsonEncode({'type': 'a2ui'}));
      await pumpEventQueue();

      expect(events, isEmpty);
    });

    test('reconnects when the connection drops', () async {
      final live = build();
      await live.connect();
      await server.close(3001);
      await pumpEventQueue();
      expect(live.isConnected, isFalse);

      await Future<void>.delayed(const Duration(milliseconds: 50));

      expect(connections, 2);
      expect(live.isConnected, isTrue);
    });

    test('backs off and starts over once a frame arrives', () async {
      final delays = <int>[];
      final live = build(
        retryDelay: (attempt) {
          delays.add(attempt);
          return const Duration(milliseconds: 5);
        },
      );
      await live.connect();
      await server.close(3001);
      await Future<void>.delayed(const Duration(milliseconds: 30));
      await server.close(3001);
      await Future<void>.delayed(const Duration(milliseconds: 30));
      server.sendText(jsonEncode({'type': 'mystery'}));
      await pumpEventQueue();
      await server.close(3001);
      await Future<void>.delayed(const Duration(milliseconds: 30));

      expect(delays, [0, 1, 0]);
    });

    test('a connection that fails retries too', () async {
      var attempts = 0;
      final live = repository = WebSocketLiveRepository(
        retryDelay: (_) => const Duration(milliseconds: 5),
        client: HomeApiClient(
          sessionId: 'visitor-0123456789abcdef',
          baseUri: Uri.parse('http://localhost:8080'),
          connect: (_, _) {
            attempts++;
            return AdapterWebSocketChannel(
              Future<WebSocket>.error(WebSocketException('refused')),
            );
          },
        ),
      );
      await live.connect();
      await Future<void>.delayed(const Duration(milliseconds: 40));

      expect(attempts, greaterThan(1));
    });

    test('close hangs up and stops retrying', () async {
      final live = build();
      await live.connect();

      await live.close();
      await pumpEventQueue();
      await Future<void>.delayed(const Duration(milliseconds: 40));

      expect(received, [isA<CloseReceived>()]);
      expect(connections, 1);
      expect(live.isConnected, isFalse);
      expect(live.moveTo(DateTime.utc(2026)), isFalse);
    });

    test('closing while it waits for a retry cancels it', () async {
      final live = build(retryDelay: (_) => const Duration(milliseconds: 30));
      await live.connect();
      await server.close(3001);
      await pumpEventQueue();

      await live.close();
      await Future<void>.delayed(const Duration(milliseconds: 60));

      expect(connections, 1);
    });

    test('connects again after it was closed', () async {
      final live = build();
      await live.connect();
      await live.close();
      await live.connect();

      expect(connections, 2);
      expect(live.isConnected, isTrue);
    });
  });
}
