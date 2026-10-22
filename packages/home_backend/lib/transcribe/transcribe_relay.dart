import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:home_backend/transcribe/transcription_session.dart';
import 'package:logging/logging.dart';
import 'package:web_socket_channel/web_socket_channel.dart';

final _log = Logger('transcribe');

/// The WebSocket subprotocol `/transcribe` clients offer and the server
/// selects.
///
/// Browsers can't set an `Authorization` header on a WebSocket, so clients
/// offer their Gemini API key as a second subprotocol entry. The server only
/// ever selects this name, so the key is never echoed back.
const transcribeProtocol = 'genui.transcribe.v1';

/// Close code for a client that sent a message the protocol doesn't define.
///
/// WebSocket applications may only close with 1000 or a code from 3000 to
/// 4999, so the relay's own codes follow the HTTP status they resemble.
const transcribeUnsupportedMessageCode = 4400;

/// Close code for a provider that failed or never became ready.
const transcribeProviderFailedCode = 4502;

const _defaultSetupTimeout = Duration(seconds: 5);

/// {@template transcribe_relay}
/// Relays one `/transcribe` client connection to one [TranscriptionSession].
/// {@endtemplate}
///
/// The client sends binary frames of raw 16 kHz mono 16-bit little-endian PCM,
/// then a `{"type": "stop"}` text frame when the user stops talking. The relay
/// answers with `interim`, `final` and `error` messages. The backend README's
/// "Voice transcription" section describes the full protocol.
///
/// ## Audio that arrives before the session is ready
///
/// The relay starts when the client's socket connects, and the session starts
/// connecting to the provider at the same moment. The provider needs a setup
/// round trip before it accepts audio, and the user may already be talking.
/// The relay covers that gap, so every frontend gets the same behavior without
/// writing code for it:
///
/// - [_pending] is a list of audio frames held in memory for this connection
///   only. It starts empty.
/// - Until [TranscriptionSession.ready] completes, every binary frame from the
///   client is appended to [_pending].
/// - When the session is ready, the relay sends the listed frames in order,
///   empties the list, and forwards later frames straight through.
/// - A `stop` that arrives before the session is ready is handled after the
///   listed frames, so no audio is lost.
/// - If setup fails or takes longer than the setup timeout, the relay sends an
///   `error` message, closes the client socket and drops the list.
///
/// The list never outlives its connection. Audio arrives at 32 KB per second,
/// so at real-time rate the default 5-second setup timeout keeps it under
/// about 160 KB.
class TranscribeRelay {
  /// {@macro transcribe_relay}
  ///
  /// Creates a relay between the `client` socket and the `session`.
  ///
  /// Failures go to the log. The client only ever sees a generic message.
  TranscribeRelay({
    required this._client,
    required this._session,
    this._setupTimeout = _defaultSetupTimeout,
  });

  final WebSocketChannel _client;
  final TranscriptionSession _session;
  final Duration _setupTimeout;

  /// Audio frames received before the session is ready. See the class
  /// documentation.
  final _pending = <List<int>>[];
  final _done = Completer<void>();
  StreamSubscription<dynamic>? _clientSubscription;
  StreamSubscription<Transcript>? _transcriptSubscription;
  bool _ready = false;
  bool _stopping = false;
  bool _closed = false;

  /// Relays until either side closes or fails. Completes once the session is
  /// closed and the client socket is closing.
  Future<void> run() {
    _clientSubscription = _client.stream.listen(
      _onClientMessage,
      onError: _onClientGone,
      onDone: _onClientGone,
    );
    _transcriptSubscription = _session.transcripts.listen(
      _onTranscript,
      onError: (Object error, StackTrace stackTrace) =>
          _fail('Transcription failed.', 'stream', error, stackTrace),
      onDone: () => _close(WebSocketStatus.normalClosure),
    );
    unawaited(_awaitReady());
    return _done.future;
  }

  Future<void> _awaitReady() async {
    try {
      await _session.ready.timeout(_setupTimeout);
    } on Object catch (error, stackTrace) {
      await _fail('Transcription is unavailable.', 'setup', error, stackTrace);
      return;
    }
    if (_closed) return;
    _ready = true;
    _pending
      ..forEach(_session.sendAudio)
      ..clear();
    if (_stopping) await _finish();
  }

  void _onClientMessage(dynamic message) {
    if (_closed) return;
    if (message is List<int>) {
      _onAudio(message);
    } else if (_isStop(message)) {
      _onStop();
    } else {
      unawaited(_reject());
    }
  }

  void _onAudio(List<int> frame) {
    if (_stopping) return;
    if (_ready) {
      _session.sendAudio(frame);
    } else {
      _pending.add(frame);
    }
  }

  void _onStop() {
    if (_stopping) return;
    _stopping = true;
    if (_ready) unawaited(_finish());
  }

  Future<void> _finish() async {
    await _session.finish();
    await _close(WebSocketStatus.normalClosure);
  }

  void _onTranscript(Transcript transcript) => _send({
    'type': transcript.isFinal ? 'final' : 'interim',
    'text': transcript.text,
  });

  /// Handles the client leaving, cleanly or with a socket [error].
  void _onClientGone([Object? error]) => unawaited(_close(null));

  Future<void> _reject() async {
    _log.warning('/transcribe: closed a client that sent an unknown message');
    _send({'type': 'error', 'message': 'Unsupported message.'});
    await _close(transcribeUnsupportedMessageCode);
  }

  Future<void> _fail(
    String message,
    String phase,
    Object error,
    StackTrace stackTrace,
  ) async {
    if (_closed) return;
    _log.severe(
      '/transcribe: transcription failed during $phase',
      error,
      stackTrace,
    );
    _send({'type': 'error', 'message': message});
    await _close(transcribeProviderFailedCode);
  }

  Future<void> _close(int? code) async {
    if (_closed) return;
    _closed = true;
    _pending.clear();
    await _clientSubscription?.cancel();
    await _transcriptSubscription?.cancel();
    await _session.close();
    // Not awaited: a client that never answers the close frame must not keep
    // the relay open.
    unawaited(_client.sink.close(code));
    _done.complete();
  }

  void _send(Map<String, Object?> message) =>
      _client.sink.add(jsonEncode(message));

  static bool _isStop(Object? message) {
    if (message is! String) return false;
    try {
      final decoded = jsonDecode(message);
      return decoded is Map<String, dynamic> && decoded['type'] == 'stop';
    } on FormatException {
      return false;
    }
  }
}
