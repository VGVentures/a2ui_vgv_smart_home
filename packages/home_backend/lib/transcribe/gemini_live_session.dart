import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:home_backend/transcribe/transcription_session.dart';
import 'package:web_socket_channel/io.dart';
import 'package:web_socket_channel/web_socket_channel.dart';

/// The Gemini Live API WebSocket endpoint.
const geminiLiveEndpoint =
    'wss://generativelanguage.googleapis.com/ws/'
    'google.ai.generativelanguage.v1beta.GenerativeService.BidiGenerateContent';

/// Gemini's live speech-to-text model.
const geminiTranscribeModel = 'gemini-3.5-transcribe-live';

const _defaultFinishTimeout = Duration(seconds: 2);

/// {@template gemini_live_session}
/// A [TranscriptionSession] on Gemini's live transcription model.
/// {@endtemplate}
///
/// Speaks the [Gemini Live API](https://ai.google.dev/api/live) over one
/// WebSocket. It sends `setup` as soon as it is created and is [ready] on
/// `setupComplete`. Audio goes out as `realtimeInput`, and
/// `interimInputTranscription` and `inputTranscription` come back as interim
/// and final [Transcript]s.
class GeminiLiveSession implements TranscriptionSession {
  /// {@macro gemini_live_session}
  ///
  /// Runs a session over a channel that may still be connecting.
  ///
  /// [finish] waits up to `finishTimeout` for Gemini's last transcript. Gemini
  /// sends nothing at all for audio with no speech in it, so the timeout is
  /// what ends a silent session.
  GeminiLiveSession(
    this._channel, {
    String model = geminiTranscribeModel,
    this._finishTimeout = _defaultFinishTimeout,
  }) {
    // A failed connection also arrives on the stream, which reports it.
    _channel.ready.ignore();
    // Callers that stop waiting for setup must not turn its failure into an
    // unhandled error.
    _ready.future.ignore();
    _subscription = _channel.stream.listen(
      _onMessage,
      onError: _onError,
      onDone: _onDone,
    );
    _send({
      'setup': {
        'model': 'models/$model',
        'generationConfig': {
          'responseModalities': ['TEXT'],
        },
        'inputAudioTranscription': <String, Object?>{},
      },
    });
  }

  /// {@macro gemini_live_session}
  ///
  /// Opens a session to [endpoint].
  ///
  /// [apiKey] travels in the `x-goog-api-key` header rather than the URL, so
  /// it stays out of anything that logs URLs.
  factory GeminiLiveSession.connect({
    required String apiKey,
    String endpoint = geminiLiveEndpoint,
    Duration finishTimeout = _defaultFinishTimeout,
  }) => GeminiLiveSession(
    IOWebSocketChannel.connect(
      Uri.parse(endpoint),
      headers: {'x-goog-api-key': apiKey},
    ),
    finishTimeout: finishTimeout,
  );

  final WebSocketChannel _channel;
  final Duration _finishTimeout;
  late final StreamSubscription<dynamic> _subscription;
  final _ready = Completer<void>();
  final _transcripts = StreamController<Transcript>();
  Completer<void>? _finished;
  bool _closed = false;

  @override
  Future<void> get ready => _ready.future;

  @override
  Stream<Transcript> get transcripts => _transcripts.stream;

  @override
  void sendAudio(List<int> pcm) => _send({
    'realtimeInput': {
      'audio': {'data': base64Encode(pcm), 'mimeType': 'audio/pcm;rate=16000'},
    },
  });

  @override
  Future<void> finish() {
    if (_closed) return Future.value();
    final finished = _finished = Completer<void>();
    _send({
      'realtimeInput': {'audioStreamEnd': true},
    });
    return finished.future.timeout(_finishTimeout, onTimeout: () {});
  }

  @override
  Future<void> close() async {
    if (_closed) return;
    _closed = true;
    await _subscription.cancel();
    // Not awaited: on a connection that never opened, the close never
    // completes.
    unawaited(_channel.sink.close(WebSocketStatus.normalClosure));
    _end();
  }

  void _send(Map<String, Object?> message) {
    if (!_closed) _channel.sink.add(jsonEncode(message));
  }

  void _onMessage(dynamic message) {
    final Object? decoded;
    try {
      decoded = jsonDecode(
        message is String ? message : utf8.decode(message as List<int>),
      );
    } on FormatException catch (error) {
      _fail(TranscriptionException('Unreadable message from Gemini: $error'));
      return;
    }
    if (decoded is! Map<String, dynamic>) return;

    if (decoded.containsKey('setupComplete')) {
      if (!_ready.isCompleted) _ready.complete();
      return;
    }

    final content = decoded['serverContent'];
    if (content is! Map<String, dynamic>) return;
    final interim = _text(content['interimInputTranscription']);
    if (interim != null) _transcripts.add(Transcript(interim, isFinal: false));
    final last = _text(content['inputTranscription']);
    if (last != null) _transcripts.add(Transcript(last, isFinal: true));
    if (content['generationComplete'] == true) _completeFinish();
  }

  void _onError(Object error) =>
      _fail(TranscriptionException('Gemini connection failed: $error'));

  void _onDone() {
    _closed = true;
    final code = _channel.closeCode;
    if (code != null && code != WebSocketStatus.normalClosure) {
      _fail(
        TranscriptionException(
          'Gemini closed the session: $code ${_channel.closeReason}',
        ),
      );
    } else if (!_ready.isCompleted) {
      _fail(TranscriptionException('Gemini closed the session before setup'));
    }
    _end();
  }

  /// Reports [error] through [ready] before setup and through [transcripts]
  /// after it.
  void _fail(TranscriptionException error) {
    if (_ready.isCompleted) {
      _transcripts.addError(error);
    } else {
      _ready.completeError(error);
    }
  }

  void _end() {
    _completeFinish();
    if (!_ready.isCompleted) {
      _ready.completeError(TranscriptionException('Session closed'));
    }
    // Not awaited: with no listener the done event would wait forever.
    unawaited(_transcripts.close());
  }

  void _completeFinish() {
    final finished = _finished;
    if (finished != null && !finished.isCompleted) finished.complete();
  }

  static String? _text(Object? transcription) {
    if (transcription is! Map<String, dynamic>) return null;
    final text = transcription['text'];
    return text is String ? text : null;
  }
}
