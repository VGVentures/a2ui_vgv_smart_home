import 'dart:async';
import 'dart:convert';

import 'package:a2ui_vgv_smart_home/api_key/gemini_key_store.dart';
import 'package:equatable/equatable.dart';
import 'package:web_socket_channel/web_socket_channel.dart';

/// The subprotocol `/transcribe` selects. The person's Gemini key rides next to
/// it, because browsers can't set an `Authorization` header on a WebSocket.
const transcribeProtocol = 'genui.transcribe.v1';

/// {@template transcript}
/// Text the backend heard.
/// {@endtemplate}
class Transcript extends Equatable {
  /// {@macro transcript}
  const Transcript(this.text, {required this.isFinal});

  /// What was heard.
  final String text;

  /// An interim transcript replaces the one before it. A final one ends an
  /// utterance and won't change.
  final bool isFinal;

  @override
  List<Object?> get props => [text, isFinal];
}

/// {@template transcription_failed}
/// A spoken command could not be turned into text.
/// {@endtemplate}
class TranscriptionFailed implements Exception {
  /// {@macro transcription_failed}
  const TranscriptionFailed(this.message);

  /// Why the transcription failed.
  final String message;

  @override
  String toString() => 'TranscriptionFailed: $message';
}

/// {@template transcription_session}
/// One spoken command on its way to text.
/// {@endtemplate}
abstract interface class TranscriptionSession {
  /// What the backend hears. Closes once the backend is done, and emits a
  /// [TranscriptionFailed] first if it failed.
  Stream<Transcript> get transcripts;

  /// Sends a chunk of raw 16 kHz mono 16-bit little-endian PCM.
  void sendAudio(List<int> pcm);

  /// Tells the backend the user stopped talking.
  void stop();

  /// Hangs up without waiting for the rest of the transcript.
  void close();
}

/// {@template transcription_client}
/// Opens [TranscriptionSession]s.
///
/// A seam so tests can run without a backend.
/// {@endtemplate}
// ignore: one_member_abstracts
abstract interface class TranscriptionClient {
  /// Throws a [TranscriptionFailed] when no Gemini key was entered.
  Future<TranscriptionSession> connect();
}

/// Opens a [WebSocketChannel] to a URI with the given subprotocols.
typedef WebSocketConnector =
    WebSocketChannel Function(Uri uri, Iterable<String> protocols);

WebSocketChannel _connect(Uri uri, Iterable<String> protocols) =>
    WebSocketChannel.connect(uri, protocols: protocols);

/// {@template web_socket_transcription_client}
/// Streams audio to the backend's `/transcribe` WebSocket. The backend README's
/// "Voice transcription" section describes the protocol.
/// {@endtemplate}
class WebSocketTranscriptionClient implements TranscriptionClient {
  /// {@macro web_socket_transcription_client}
  ///
  /// [connect] opens the WebSocket, and is replaced in tests.
  WebSocketTranscriptionClient({
    required this.keys,
    required Uri baseUri,
    WebSocketConnector connect = _connect,
  }) : _uri = baseUri
           .resolve('/transcribe')
           .replace(scheme: baseUri.scheme == 'https' ? 'wss' : 'ws'),
       _connectWebSocket = connect;

  /// Where the person's Gemini key is read from.
  final GeminiKeyStore keys;
  final Uri _uri;
  final WebSocketConnector _connectWebSocket;

  @override
  Future<TranscriptionSession> connect() async {
    final key = keys.key;
    if (key == null || key.isEmpty) {
      throw const TranscriptionFailed('No Gemini API key.');
    }
    return _WebSocketTranscriptionSession(
      _connectWebSocket(_uri, [transcribeProtocol, key]),
    );
  }
}

/// A [TranscriptionSession] over a WebSocket to the backend's `/transcribe`.
class _WebSocketTranscriptionSession implements TranscriptionSession {
  _WebSocketTranscriptionSession(this._channel) {
    // A failed connection also arrives on the stream, which reports it.
    _channel.ready.ignore();
  }

  final WebSocketChannel _channel;

  @override
  late final Stream<Transcript> transcripts = _channel.stream.transform(
    StreamTransformer.fromHandlers(
      handleData: (message, sink) {
        final transcript = _parse(message);
        if (transcript != null) sink.add(transcript);
      },
      handleError: (error, stackTrace, sink) => sink.addError(
        TranscriptionFailed('Connection failed: $error'),
        stackTrace,
      ),
      handleDone: (sink) {
        // An `error` message is always followed by a close with its own code,
        // so the code alone says whether the backend finished.
        final code = _channel.closeCode;
        if (code != null && code != 1000) {
          sink.addError(TranscriptionFailed('Closed with $code.'));
        }
        sink.close();
      },
    ),
  );

  @override
  void sendAudio(List<int> pcm) => _channel.sink.add(pcm);

  @override
  void stop() => _channel.sink.add(jsonEncode({'type': 'stop'}));

  // Not awaited: on a connection that never opened, the close never completes.
  @override
  void close() => unawaited(_channel.sink.close());

  static Transcript? _parse(Object? message) {
    if (message is! String) return null;
    final Object? decoded;
    try {
      decoded = jsonDecode(message);
    } on FormatException {
      return null;
    }
    if (decoded is! Map<String, dynamic>) return null;
    final text = decoded['text'];
    if (text is! String) return null;
    return switch (decoded['type']) {
      'interim' => Transcript(text, isFinal: false),
      'final' => Transcript(text, isFinal: true),
      _ => null,
    };
  }
}
