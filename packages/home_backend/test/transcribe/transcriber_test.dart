import 'dart:async';
import 'dart:io';

import 'package:home_backend/transcribe/gemini_live_session.dart';
import 'package:home_backend/transcribe/transcriber.dart';
import 'package:home_backend/transcribe/transcription_session.dart';
import 'package:mocktail/mocktail.dart';
import 'package:test/test.dart';

class _MockSession extends Mock implements TranscriptionSession {}

void main() {
  group('Transcriber', () {
    test('opens each session with the given function and key', () {
      final session = _MockSession();
      String? seenKey;
      final transcriber = Transcriber((key) {
        seenKey = key;
        return session;
      });

      expect(transcriber.connect('k-1'), same(session));
      expect(seenKey, 'k-1');
    });

    test("gemini opens Gemini sessions keyed with the caller's key", () async {
      final server = await HttpServer.bind(InternetAddress.loopbackIPv4, 0);
      addTearDown(() => server.close(force: true));
      final apiKey = Completer<String?>();
      server.listen((request) async {
        apiKey.complete(request.headers.value('x-goog-api-key'));
        await WebSocketTransformer.upgrade(request);
      });

      final session = Transcriber.gemini(
        endpoint: 'ws://localhost:${server.port}',
      ).connect('test-key');
      addTearDown(session.close);

      expect(session, isA<GeminiLiveSession>());
      expect(await apiKey.future, 'test-key');
    });
  });
}
