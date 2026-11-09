import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:home_backend/transcribe/gemini_live_session.dart';
import 'package:home_backend/transcribe/transcription_session.dart';
import 'package:test/test.dart';

/// The server end of one connection to the fake Gemini.
class _Upstream {
  _Upstream(this.socket, this.apiKey)
    : _messages = StreamIterator(
        socket.map((message) => jsonDecode(message as String)),
      );

  final WebSocket socket;
  final String? apiKey;
  final StreamIterator<dynamic> _messages;

  /// The next message the session sent.
  Future<Map<String, dynamic>> next() async {
    expect(await _messages.moveNext(), isTrue, reason: 'socket closed');
    return _messages.current as Map<String, dynamic>;
  }

  /// Whether the session closed its end.
  Future<bool> get closedBySession async => !(await _messages.moveNext());

  void send(Object message) => socket.add(jsonEncode(message));

  Future<void> setupComplete(TranscriptionSession session) async {
    await next(); // setup
    send({'setupComplete': <String, dynamic>{}});
    await session.ready;
  }
}

void main() {
  late HttpServer server;
  late Future<_Upstream> upstream;

  setUp(() async {
    server = await HttpServer.bind(InternetAddress.loopbackIPv4, 0);
    final accepted = Completer<_Upstream>();
    server.listen((request) async {
      final apiKey = request.headers.value('x-goog-api-key');
      accepted.complete(
        _Upstream(await WebSocketTransformer.upgrade(request), apiKey),
      );
    });
    upstream = accepted.future;
  });

  tearDown(() => server.close(force: true));

  GeminiLiveSession connect({
    Duration finishTimeout = const Duration(seconds: 2),
  }) => GeminiLiveSession.connect(
    apiKey: 'test-key',
    endpoint: 'ws://localhost:${server.port}',
    finishTimeout: finishTimeout,
  );

  test('points at the Gemini Live API by default', () {
    final endpoint = Uri.parse(geminiLiveEndpoint);
    expect(endpoint.scheme, 'wss');
    expect(endpoint.host, 'generativelanguage.googleapis.com');
    expect(geminiTranscribeModel, 'gemini-3.5-transcribe-live');
  });

  test('sends setup for the transcription model, keyed in a header', () async {
    final session = connect();
    addTearDown(session.close);
    final gemini = await upstream;

    expect(gemini.apiKey, 'test-key');
    expect(await gemini.next(), {
      'setup': {
        'model': 'models/gemini-3.5-transcribe-live',
        'generationConfig': {
          'responseModalities': ['TEXT'],
        },
        'inputAudioTranscription': <String, dynamic>{},
      },
    });
  });

  test('is ready on setupComplete, sending no audio of its own', () async {
    final session = connect();
    addTearDown(session.close);
    final gemini = await upstream;
    await gemini.next();

    gemini.send({'setupComplete': <String, dynamic>{}});
    await session.ready;
    session.sendAudio([1]);

    expect(
      (await gemini.next())['realtimeInput'],
      containsPair('audio', containsPair('data', base64Encode([1]))),
    );
  });

  test('reads messages that arrive as binary frames', () async {
    final session = connect();
    addTearDown(session.close);
    final gemini = await upstream;
    await gemini.next();

    gemini.socket.add(
      utf8.encode(jsonEncode({'setupComplete': <String, dynamic>{}})),
    );

    await expectLater(session.ready, completes);
  });

  test('sends audio as base64 realtimeInput', () async {
    final session = connect();
    addTearDown(session.close);
    final gemini = await upstream;
    await gemini.setupComplete(session);

    session.sendAudio([1, 2, 3]);

    expect(await gemini.next(), {
      'realtimeInput': {
        'audio': {
          'data': base64Encode([1, 2, 3]),
          'mimeType': 'audio/pcm;rate=16000',
        },
      },
    });
  });

  test(
    'turns input transcriptions into interim and final transcripts',
    () async {
      final session = connect();
      addTearDown(session.close);
      final gemini = await upstream;
      await gemini.setupComplete(session);
      final transcripts = <Transcript>[];
      session.transcripts.listen(transcripts.add);

      gemini
        ..send({
          'serverContent': {
            'interimInputTranscription': {'text': 'Dinner'},
          },
        })
        ..send({
          'serverContent': {
            'inputTranscription': {'text': "Dinner's an hour later."},
          },
        });

      await _until(() => transcripts.length == 2);
      expect(transcripts, const [
        Transcript('Dinner', isFinal: false),
        Transcript("Dinner's an hour later.", isFinal: true),
      ]);
    },
  );

  test('ignores messages it has no use for', () async {
    final session = connect();
    addTearDown(session.close);
    final gemini = await upstream;
    await gemini.setupComplete(session);
    final transcripts = <Transcript>[];
    session.transcripts.listen(transcripts.add);

    gemini
      ..send(<dynamic>[])
      ..send({'usageMetadata': <String, dynamic>{}})
      ..send({
        'serverContent': {
          'voiceActivity': {'type': 'ACTIVITY_START'},
        },
      })
      ..send({
        'serverContent': {'inputTranscription': 'not an object'},
      })
      ..send({
        'serverContent': {
          'inputTranscription': {'text': 5},
        },
      })
      // A repeated setupComplete changes nothing.
      ..send({'setupComplete': <String, dynamic>{}})
      ..send({
        'serverContent': {
          'inputTranscription': {'text': 'done'},
        },
      });
    session.sendAudio([7]);

    await _until(() => transcripts.isNotEmpty);
    expect(transcripts, const [Transcript('done', isFinal: true)]);
    expect(
      (await gemini.next())['realtimeInput'],
      containsPair('audio', containsPair('data', base64Encode([7]))),
    );
  });

  group('finish', () {
    test('sends audioStreamEnd and completes on generationComplete', () async {
      final session = connect();
      addTearDown(session.close);
      final gemini = await upstream;
      await gemini.setupComplete(session);
      var finished = false;

      unawaited(session.finish().then((_) => finished = true));

      expect(await gemini.next(), {
        'realtimeInput': {'audioStreamEnd': true},
      });
      expect(finished, isFalse);
      gemini.send({
        'serverContent': {'generationComplete': true},
      });
      await _until(() => finished);
    });

    test('completes after the timeout when Gemini sends nothing', () async {
      final session = connect(finishTimeout: const Duration(milliseconds: 50));
      addTearDown(session.close);
      final gemini = await upstream;
      await gemini.setupComplete(session);

      await expectLater(session.finish(), completes);
    });

    test('completes when Gemini closes the session', () async {
      final session = connect();
      final gemini = await upstream;
      await gemini.setupComplete(session);

      final finished = session.finish();
      await gemini.next();
      await gemini.socket.close(WebSocketStatus.normalClosure);

      await expectLater(finished, completes);
    });

    test('completes right away once the session is closed', () async {
      final session = connect();
      final gemini = await upstream;
      await gemini.setupComplete(session);
      await session.close();

      await expectLater(session.finish(), completes);
    });
  });

  group('failures', () {
    test('ready fails when Gemini cannot be reached', () async {
      final port = server.port;
      await server.close(force: true);
      final session = GeminiLiveSession.connect(
        apiKey: 'test-key',
        endpoint: 'ws://localhost:$port',
      );

      await expectLater(
        session.ready,
        throwsA(
          isA<TranscriptionException>().having(
            (error) => error.message,
            'message',
            contains('connection failed'),
          ),
        ),
      );
    });

    test('ready fails when Gemini rejects the session', () async {
      final session = connect();
      final gemini = await upstream;
      await gemini.next();

      await gemini.socket.close(1008, 'API key not valid');

      await expectLater(
        session.ready,
        throwsA(
          isA<TranscriptionException>().having(
            (error) => error.message,
            'message',
            allOf(contains('1008'), contains('API key not valid')),
          ),
        ),
      );
    });

    test('ready fails when Gemini closes before setup', () async {
      final session = connect();
      final gemini = await upstream;
      await gemini.next();

      await gemini.socket.close(WebSocketStatus.normalClosure);

      await expectLater(
        session.ready,
        throwsA(
          isA<TranscriptionException>().having(
            (error) => error.message,
            'message',
            contains('before setup'),
          ),
        ),
      );
    });

    test('ready fails on an unreadable message', () async {
      final session = connect();
      addTearDown(session.close);
      final gemini = await upstream;
      await gemini.next();

      gemini.socket.add('not json');

      await expectLater(
        session.ready,
        throwsA(isA<TranscriptionException>()),
      );
    });

    test('ready fails when the session is closed during setup', () async {
      final session = connect();
      await upstream;

      await session.close();

      await expectLater(session.ready, throwsA(isA<TranscriptionException>()));
    });

    test('an abnormal close after setup fails the transcripts', () async {
      final session = connect();
      final gemini = await upstream;
      await gemini.setupComplete(session);

      await gemini.socket.close(WebSocketStatus.internalServerError, 'boom');

      await expectLater(
        session.transcripts,
        emitsInOrder(<Object>[
          emitsError(isA<TranscriptionException>()),
          emitsDone,
        ]),
      );
    });

    test('a normal close after setup ends the transcripts', () async {
      final session = connect();
      final gemini = await upstream;
      await gemini.setupComplete(session);

      await gemini.socket.close(WebSocketStatus.normalClosure);

      await expectLater(session.transcripts, emitsDone);
    });
  });

  group('close', () {
    test('closes the socket and ends the transcripts', () async {
      final session = connect();
      final gemini = await upstream;
      await gemini.setupComplete(session);

      await session.close();

      expect(await gemini.closedBySession, isTrue);
      expect(gemini.socket.closeCode, WebSocketStatus.normalClosure);
      await expectLater(session.transcripts, emitsDone);
    });

    test('is safe to call twice, and later audio is dropped', () async {
      final session = connect();
      final gemini = await upstream;
      await gemini.setupComplete(session);

      await session.close();
      await session.close();
      session.sendAudio([1]);

      expect(await gemini.closedBySession, isTrue);
    });
  });
}

/// Waits for [condition], failing the test after two seconds.
Future<void> _until(bool Function() condition) async {
  final deadline = DateTime.now().add(const Duration(seconds: 2));
  while (!condition()) {
    if (DateTime.now().isAfter(deadline)) fail('condition never became true');
    await Future<void>.delayed(const Duration(milliseconds: 5));
  }
}
