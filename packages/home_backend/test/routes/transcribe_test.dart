import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:dart_frog/dart_frog.dart';
import 'package:home_backend/cors/cors_config.dart';
import 'package:home_backend/gemini_key/gemini_api_key.dart';
import 'package:home_backend/transcribe/transcribe_relay.dart';
import 'package:home_backend/transcribe/transcriber.dart';
import 'package:home_backend/transcribe/transcription_session.dart';
import 'package:test/test.dart';

import '../../routes/transcribe.dart' as route;

/// A provider session that is ready at once and records the audio it gets.
class _ReadySession implements TranscriptionSession {
  final audio = <List<int>>[];
  final _transcripts = StreamController<Transcript>();

  @override
  Future<void> get ready => Future.value();

  @override
  Stream<Transcript> get transcripts => _transcripts.stream;

  @override
  void sendAudio(List<int> pcm) => audio.add(pcm);

  @override
  Future<void> finish() => Future.value();

  @override
  Future<void> close() async => unawaited(_transcripts.close());
}

void main() {
  group('GET /transcribe', () {
    group('over a real socket', () {
      late _ReadySession session;
      late List<String> openedWith;
      late String url;

      setUp(() async {
        session = _ReadySession();
        openedWith = [];
        const Handler handler = route.onRequest;
        final server = await serve(
          handler
              .use(
                provider<Transcriber>(
                  (_) => Transcriber((key) {
                    openedWith.add(key);
                    return session;
                  }),
                ),
              )
              .use(provider<GeminiApiKey>((_) => const GeminiApiKey('k-1')))
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
        url = 'ws://localhost:${server.port}/transcribe';
      });

      Future<WebSocket> connect({String? origin}) async {
        final socket = await WebSocket.connect(
          url,
          protocols: [transcribeProtocol, 'k-1'],
          headers: {'Origin': ?origin},
        );
        addTearDown(socket.close);
        return socket;
      }

      test('selects the protocol name, never the key', () async {
        final socket = await connect();

        expect(socket.protocol, transcribeProtocol);
      });

      test("opens the session with the caller's key", () async {
        final socket = await connect();
        socket.add(jsonEncode({'type': 'stop'}));
        await socket.drain<void>();

        expect(openedWith, ['k-1']);
      });

      test('relays the audio and closes after stop', () async {
        final socket = await connect();
        final done = Completer<void>();
        socket
          ..listen((_) {}, onDone: done.complete)
          ..add([1, 2])
          ..add(jsonEncode({'type': 'stop'}));
        await done.future.timeout(const Duration(seconds: 2));

        expect(socket.closeCode, WebSocketStatus.normalClosure);
        expect(session.audio, [
          [1, 2],
        ]);
      });

      test('accepts an allowed origin whatever its case', () async {
        final socket = await connect(origin: 'https://app.example.com');

        expect(socket.protocol, transcribeProtocol);
      });

      test('refuses an origin outside the allowlist', () async {
        await expectLater(
          connect(origin: 'https://evil.example.com'),
          throwsA(isA<WebSocketException>()),
        );
      });
    });
  });
}
