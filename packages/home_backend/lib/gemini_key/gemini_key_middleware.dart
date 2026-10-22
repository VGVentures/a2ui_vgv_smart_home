import 'package:dart_frog/dart_frog.dart';
import 'package:home_backend/api_error.dart';
import 'package:home_backend/gemini_key/gemini_api_key.dart';
import 'package:home_backend/transcribe/transcribe_relay.dart';

/// The paths that call Gemini, and so need the caller's key. Everything else is
/// the demo's mock world and answers without one.
const _keyedPaths = {'/generate', '/action', '/transcribe'};

/// Browsers can't set an `Authorization` header on a WebSocket, so a client of
/// `/transcribe` offers the key as a `Sec-WebSocket-Protocol` entry next to the
/// protocol name. The header travels inside TLS and stays out of request logs,
/// and the server only ever selects the protocol name, so the key is never
/// echoed back.
const _transcribePath = '/transcribe';

/// Builds the middleware that requires the caller's Gemini key on the paths
/// that call Gemini. A request without one gets a `401`; otherwise the key is
/// provided to the route as a [GeminiApiKey]. The key is checked by Gemini
/// itself when the model is called, not here.
Middleware requireGeminiKey() {
  return (handler) {
    return (context) async {
      if (!_keyedPaths.contains(context.request.uri.path)) {
        return handler(context);
      }

      final key = _bearerKey(context.request);
      if (key == null) {
        return const ApiError.unauthorized(
          message: 'Missing Gemini API key',
        ).toResponse();
      }
      return handler(context.provide<GeminiApiKey>(() => GeminiApiKey(key)));
    };
  };
}

/// The key [request] carries, or `null` when it has none.
///
/// On [_transcribePath] the key is the one `Sec-WebSocket-Protocol` entry that
/// isn't the protocol name. Everywhere else it comes from
/// `Authorization: Bearer <key>`.
String? _bearerKey(Request request) {
  if (request.uri.path == _transcribePath) {
    final entries = (request.headers['sec-websocket-protocol'] ?? '')
        .split(',')
        .map((entry) => entry.trim())
        .where((entry) => entry.isNotEmpty && entry != transcribeProtocol)
        .toList();
    return entries.length == 1 ? entries.single : null;
  }

  final header = request.headers['authorization'];
  if (header == null || !header.toLowerCase().startsWith('bearer ')) {
    return null;
  }
  final key = header.substring('bearer '.length).trim();
  return key.isEmpty ? null : key;
}
