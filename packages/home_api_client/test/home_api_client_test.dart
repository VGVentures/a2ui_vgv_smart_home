import 'dart:convert';

import 'package:home_api_client/home_api_client.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:test/test.dart';
import 'package:web_socket/testing.dart';
import 'package:web_socket_channel/adapter_web_socket_channel.dart';

const _sessionId = 'visitor-0123456789abcdef';

void main() {
  final baseUri = Uri.parse('http://localhost:8080/api');

  HomeApiClient build(
    http.Client httpClient, {
    Uri? uri,
    LiveConnector? connect,
  }) => HomeApiClient(
    sessionId: _sessionId,
    baseUri: uri ?? baseUri,
    httpClient: httpClient,
    connect: connect ?? (_, _) => throw StateError('no socket'),
  );

  group(HomeApiClient, () {
    test('gets /users in the visitor world', () async {
      late http.Request seen;
      final client = build(
        MockClient((request) async {
          seen = request;
          return http.Response(
            jsonEncode({
              'users': [
                {'id': 'ana'},
              ],
            }),
            200,
          );
        }),
      );

      final users = await client.getUsers();

      expect(users, [
        {'id': 'ana'},
      ]);
      expect(seen.method, 'GET');
      expect(seen.url, Uri.parse('http://localhost:8080/users'));
      expect(seen.headers, isNot(contains('Authorization')));
      expect(seen.headers[sessionHeader], _sessionId);
    });

    test('posts /clock with the time', () async {
      late http.Request seen;
      final client = build(
        MockClient((request) async {
          seen = request;
          return http.Response(jsonEncode({'now': 'x'}), 200);
        }),
      );

      final reading = await client.moveClock('2026-10-10T16:45:00');

      expect(reading, {'now': 'x'});
      expect(seen.method, 'POST');
      expect(seen.url.path, '/clock');
      expect(seen.headers, isNot(contains('Authorization')));
      expect(seen.headers[sessionHeader], _sessionId);
      expect(seen.headers['Content-Type'], 'application/json');
      expect(jsonDecode(seen.body), {'to': '2026-10-10T16:45:00'});
    });

    test('posts /reset with no body', () async {
      late http.Request seen;
      final client = build(
        MockClient((request) async {
          seen = request;
          return http.Response(jsonEncode(<String, Object?>{}), 200);
        }),
      );

      await client.reset();

      expect(seen.url.path, '/reset');
      expect(seen.body, isEmpty);
      expect(seen.headers, isNot(contains('Content-Type')));
      expect(seen.headers[sessionHeader], _sessionId);
    });

    test('throws on a status other than 200', () async {
      final client = build(MockClient((_) async => http.Response('no', 401)));

      for (final call in [client.getUsers, () => client.moveClock('t')]) {
        await expectLater(
          call(),
          throwsA(
            isA<HomeApiException>().having((e) => e.statusCode, 'code', 401),
          ),
        );
      }
      expect(const HomeApiException(400).toString(), contains('400'));
    });

    test('opens /live with the protocol and the session id', () {
      Uri? connectedTo;
      Iterable<String>? offered;
      build(
        MockClient((_) async => http.Response('', 200)),
        connect: (uri, protocols) {
          connectedTo = uri;
          offered = protocols;
          final (socket, _) = fakes(protocol: liveProtocol);
          return AdapterWebSocketChannel(socket);
        },
      ).connectLive();

      expect(connectedTo, Uri.parse('ws://localhost:8080/live'));
      expect(offered, [liveProtocol, _sessionId]);
    });

    test('uses wss for an https backend', () {
      Uri? connectedTo;
      build(
        MockClient((_) async => http.Response('', 200)),
        uri: Uri.parse('https://backend.example.com'),
        connect: (uri, _) {
          connectedTo = uri;
          final (socket, _) = fakes(protocol: liveProtocol);
          return AdapterWebSocketChannel(socket);
        },
      ).connectLive();

      expect(connectedTo, Uri.parse('wss://backend.example.com/live'));
    });

    test('makes its own clients when none are given', () {
      // Nothing listens on port 1, so the connection fails.
      HomeApiClient(
          sessionId: _sessionId,
          baseUri: Uri.parse('http://localhost:1'),
        ).connectLive()
        ..ready.ignore()
        ..stream.listen(null, onError: (Object _) {})
        ..sink.close().ignore();
    });
  });
}
