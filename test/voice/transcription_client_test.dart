import 'dart:convert';

import 'package:a2ui_vgv_smart_home/api_key/gemini_key_store.dart';
import 'package:a2ui_vgv_smart_home/voice/transcription_client.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:web_socket/testing.dart';
import 'package:web_socket/web_socket.dart';
import 'package:web_socket_channel/adapter_web_socket_channel.dart';

void main() {
  test('TranscriptionFailed names its message', () {
    expect(
      const TranscriptionFailed('boom').toString(),
      'TranscriptionFailed: boom',
    );
  });

  group('WebSocketTranscriptionClient', () {
    late WebSocket server;
    late List<WebSocketEvent> received;
    Uri? connectedTo;
    Iterable<String>? offered;

    setUp(() {
      connectedTo = null;
      offered = null;
    });

    Future<TranscriptionSession> connect({
      String baseUrl = 'http://localhost:8080',
    }) {
      final (client, peer) = fakes(protocol: transcribeProtocol);
      server = peer;
      received = [];
      server.events.listen(received.add);
      return WebSocketTranscriptionClient(
        keys: GeminiKeyStore('key-1'),
        baseUri: Uri.parse(baseUrl),
        connect: (uri, protocols) {
          connectedTo = uri;
          offered = protocols;
          return AdapterWebSocketChannel(client);
        },
      ).connect();
    }

    test('offers the protocol and the Gemini key on /transcribe', () async {
      await connect(baseUrl: 'http://localhost:8080/api');

      expect(connectedTo, Uri.parse('ws://localhost:8080/transcribe'));
      expect(offered, [transcribeProtocol, 'key-1']);
    });

    test('uses wss for an https backend', () async {
      await connect(baseUrl: 'https://backend.example.com');

      expect(connectedTo, Uri.parse('wss://backend.example.com/transcribe'));
    });

    test('throws without a key and never connects', () async {
      final client = WebSocketTranscriptionClient(
        keys: GeminiKeyStore(),
        baseUri: Uri.parse('http://localhost:8080'),
        connect: (_, _) => fail('should not connect'),
      );

      await expectLater(client.connect(), throwsA(isA<TranscriptionFailed>()));
    });

    test('sends audio as binary frames and stop as a text frame', () async {
      final session = await connect();

      session
        ..sendAudio([1, 2, 3])
        ..stop();
      await pumpEventQueue();

      expect(received, [
        isA<BinaryDataReceived>().having((e) => e.data, 'data', [1, 2, 3]),
        TextDataReceived(jsonEncode({'type': 'stop'})),
      ]);
    });

    test('turns interim and final messages into transcripts', () async {
      final session = await connect();
      final transcripts = session.transcripts.toList();

      server
        ..sendText(jsonEncode({'type': 'interim', 'text': 'Delay'}))
        ..sendText(jsonEncode({'type': 'final', 'text': 'Delay the oven.'}));
      await server.close(1000);

      expect(await transcripts, const [
        Transcript('Delay', isFinal: false),
        Transcript('Delay the oven.', isFinal: true),
      ]);
    });

    test('ignores messages it does not understand', () async {
      final session = await connect();
      final transcripts = session.transcripts.toList();

      server
        ..sendBytes(utf8.encode('{}'))
        ..sendText('not json')
        ..sendText('[]')
        ..sendText(jsonEncode({'type': 'interim'}))
        ..sendText(jsonEncode({'type': 'error', 'text': 'Unsupported.'}));
      await server.close(1000);

      expect(await transcripts, isEmpty);
    });

    test('fails when the backend closes with an error code', () async {
      final session = await connect();
      final transcripts = session.transcripts.toList();

      server.sendText(
        jsonEncode({'type': 'error', 'message': 'Transcription failed.'}),
      );
      await server.close(4502);

      await expectLater(transcripts, throwsA(isA<TranscriptionFailed>()));
    });

    test('fails when the connection fails', () async {
      final session = await WebSocketTranscriptionClient(
        keys: GeminiKeyStore('key-1'),
        baseUri: Uri.parse('http://localhost:8080'),
        connect: (_, _) => AdapterWebSocketChannel(
          Future<WebSocket>.error(WebSocketException('refused')),
        ),
      ).connect();

      await expectLater(
        session.transcripts.toList(),
        throwsA(isA<TranscriptionFailed>()),
      );
    });

    test('close hangs up', () async {
      final session = await connect();

      session.close();
      await pumpEventQueue();

      expect(received, [isA<CloseReceived>()]);
    });

    test('connects for real by default', () async {
      // Nothing listens on port 1, so the connection fails.
      final session = await WebSocketTranscriptionClient(
        keys: GeminiKeyStore('key-1'),
        baseUri: Uri.parse('http://localhost:1'),
      ).connect();

      await expectLater(
        session.transcripts.toList(),
        throwsA(isA<TranscriptionFailed>()),
      );
    });
  });
}
