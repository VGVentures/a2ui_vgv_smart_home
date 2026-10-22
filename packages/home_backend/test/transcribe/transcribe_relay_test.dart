import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:home_backend/transcribe/transcribe_relay.dart';
import 'package:home_backend/transcribe/transcription_session.dart';
import 'package:test/test.dart';
import 'package:web_socket_channel/io.dart';

/// A provider session the test drives by hand.
class _FakeSession implements TranscriptionSession {
  final setup = Completer<void>();
  final output = StreamController<Transcript>();
  final finished = Completer<void>();

  /// What the relay did, in order: `audio:<bytes>`, `finish` and `close`.
  final calls = <String>[];

  @override
  Future<void> get ready => setup.future;

  @override
  Stream<Transcript> get transcripts => output.stream;

  @override
  void sendAudio(List<int> pcm) => calls.add('audio:${pcm.join(',')}');

  @override
  Future<void> finish() {
    calls.add('finish');
    return finished.future;
  }

  @override
  Future<void> close() async => calls.add('close');
}

/// The client end of a socket with a relay on the other end.
class _Client {
  _Client(this.socket) {
    socket.listen(
      (message) => messages.add(
        jsonDecode(message as String) as Map<String, dynamic>,
      ),
      onDone: _closed.complete,
    );
  }

  final WebSocket socket;
  final messages = <Map<String, dynamic>>[];
  final _closed = Completer<void>();

  bool get isClosed => _closed.isCompleted;

  /// Waits for the relay to close the socket and returns the close code.
  Future<int?> closed() async {
    await _closed.future.timeout(const Duration(seconds: 2));
    return socket.closeCode;
  }

  void audio(List<int> pcm) => socket.add(pcm);

  void stop() => socket.add(jsonEncode({'type': 'stop'}));
}

void main() {
  late _FakeSession session;
  setUp(() => session = _FakeSession());

  /// Runs a relay behind a real local WebSocket and connects to it.
  Future<_Client> connect({
    Duration setupTimeout = const Duration(seconds: 5),
  }) async {
    final server = await HttpServer.bind(InternetAddress.loopbackIPv4, 0);
    addTearDown(() => server.close(force: true));
    server.listen((request) async {
      final socket = await WebSocketTransformer.upgrade(request);
      unawaited(
        TranscribeRelay(
          client: IOWebSocketChannel(socket),
          session: session,
          setupTimeout: setupTimeout,
        ).run(),
      );
    });
    final client = _Client(
      await WebSocket.connect('ws://localhost:${server.port}'),
    );
    addTearDown(client.socket.close);
    return client;
  }

  group('audio before the session is ready', () {
    test('is held, then sent in order once the session is ready', () async {
      final client = await connect();

      client
        ..audio([1])
        ..audio([2]);
      await _settle();
      expect(session.calls, isEmpty);

      session.setup.complete();
      await _until(() => session.calls.length == 2);
      client.audio([3]);
      await _until(() => session.calls.length == 3);

      expect(session.calls, ['audio:1', 'audio:2', 'audio:3']);
    });

    test('is followed by a stop that arrived before the session', () async {
      final client = await connect();

      client
        ..audio([1])
        ..stop();
      await _settle();
      session.setup.complete();
      await _until(() => session.calls.contains('finish'));
      session.finished.complete();

      expect(await client.closed(), WebSocketStatus.normalClosure);
      expect(session.calls, ['audio:1', 'finish', 'close']);
    });

    test('is dropped when the client leaves before setup', () async {
      final client = await connect();

      client.audio([1]);
      await client.socket.close();
      await _until(() => session.calls.contains('close'));
      session.setup.complete();
      await _settle();

      expect(session.calls, ['close']);
    });
  });

  test('sends interim and final transcripts to the client', () async {
    final client = await connect();
    session.setup.complete();

    session.output
      ..add(const Transcript('Dinner', isFinal: false))
      ..add(const Transcript("Dinner's an hour later.", isFinal: true));

    await _until(() => client.messages.length == 2);
    expect(client.messages, [
      {'type': 'interim', 'text': 'Dinner'},
      {'type': 'final', 'text': "Dinner's an hour later."},
    ]);
  });

  test('stop finishes the session, then closes normally', () async {
    final client = await connect();
    session.setup.complete();
    await _settle();

    client
      ..stop()
      ..audio([9])
      ..stop();
    await _until(() => session.calls.contains('finish'));
    session.output.add(const Transcript('Delay the oven.', isFinal: true));
    session.finished.complete();

    expect(await client.closed(), WebSocketStatus.normalClosure);
    expect(client.messages, [
      {'type': 'final', 'text': 'Delay the oven.'},
    ]);
    expect(session.calls, ['finish', 'close']);
  });

  test('closes normally when the session ends', () async {
    final client = await connect();
    session.setup.complete();

    await session.output.close();

    expect(await client.closed(), WebSocketStatus.normalClosure);
    expect(session.calls, ['close']);
  });

  group('failures', () {
    test('a failed setup sends an error and closes', () async {
      final client = await connect();
      final error = TranscriptionException('API key not valid');

      session.setup.completeError(error);

      expect(await client.closed(), transcribeProviderFailedCode);
      expect(client.messages, [
        {'type': 'error', 'message': 'Transcription is unavailable.'},
      ]);
      expect(session.calls, ['close']);
    });

    test('a setup slower than the timeout fails the same way', () async {
      final client = await connect(
        setupTimeout: const Duration(milliseconds: 50),
      );
      client.audio([1]);

      expect(await client.closed(), transcribeProviderFailedCode);
      expect(client.messages, [
        {'type': 'error', 'message': 'Transcription is unavailable.'},
      ]);
      expect(session.calls, ['close']);
    });

    test('a session failure after setup sends an error', () async {
      final client = await connect();
      session.setup.complete();

      session.output.addError(TranscriptionException('boom'));

      expect(await client.closed(), transcribeProviderFailedCode);
      expect(client.messages, [
        {'type': 'error', 'message': 'Transcription failed.'},
      ]);
    });

    for (final message in ['hello', '{"type": "start"}']) {
      test('an unknown message "$message" closes the client', () async {
        final client = await connect();

        client.socket.add(message);

        expect(await client.closed(), transcribeUnsupportedMessageCode);
        expect(client.messages, [
          {'type': 'error', 'message': 'Unsupported message.'},
        ]);
        expect(session.calls, ['close']);
      });
    }
  });

  test('closes the session when the client disconnects', () async {
    final client = await connect();
    session.setup.complete();

    await client.socket.close();

    await _until(() => session.calls.contains('close'));
    expect(client.isClosed, isTrue);
  });
}

/// Lets in-flight socket traffic arrive.
Future<void> _settle() =>
    Future<void>.delayed(const Duration(milliseconds: 50));

/// Waits for [condition], failing the test after two seconds.
Future<void> _until(bool Function() condition) async {
  final deadline = DateTime.now().add(const Duration(seconds: 2));
  while (!condition()) {
    if (DateTime.now().isAfter(deadline)) fail('condition never became true');
    await Future<void>.delayed(const Duration(milliseconds: 5));
  }
}
