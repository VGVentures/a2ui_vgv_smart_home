import 'dart:async';

import 'package:dart_frog/dart_frog.dart';
import 'package:dart_frog_web_socket/dart_frog_web_socket.dart';
import 'package:home_backend/cors/cors_config.dart';
import 'package:home_backend/gemini_key/gemini_api_key.dart';
import 'package:home_backend/transcribe/transcribe_relay.dart';
import 'package:home_backend/transcribe/transcriber.dart';

/// `GET /transcribe`: a WebSocket that turns streamed audio into text.
///
/// The key middleware has already read the caller's Gemini key from the entry
/// the client offered in `Sec-WebSocket-Protocol`; each session is opened with
/// it and nothing keeps it afterwards. Browsers from origins outside the CORS
/// allowlist get a `403`. See the README's "Voice transcription" for the
/// protocol.
Future<Response> onRequest(RequestContext context) async {
  final transcriber = context.read<Transcriber>();
  final cors = context.read<CorsConfig>();
  final key = context.read<GeminiApiKey>();

  final handler = webSocketHandler(
    (channel, _) => unawaited(
      TranscribeRelay(
        client: channel,
        session: transcriber.connect(key.value),
      ).run(),
    ),
    protocols: const [transcribeProtocol],
    // The WebSocket handler lowercases the Origin header before comparing.
    allowedOrigins: {
      for (final origin in cors.allowedOrigins) origin.toLowerCase(),
    },
  );
  return handler(context);
}
