import 'package:home_backend/transcribe/gemini_live_session.dart';
import 'package:home_backend/transcribe/transcription_session.dart';

/// {@template transcriber}
/// Opens the live transcription sessions behind `/transcribe`.
/// {@endtemplate}
class Transcriber {
  /// {@macro transcriber}
  ///
  /// A transcriber that opens each session with [connect], given the caller's
  /// Gemini API key.
  const Transcriber(TranscriptionSession Function(String apiKey) connect)
    : _connect = connect;

  /// {@macro transcriber}
  ///
  /// A transcriber on Gemini's live transcription model at [endpoint].
  factory Transcriber.gemini({String endpoint = geminiLiveEndpoint}) =>
      Transcriber(
        (apiKey) =>
            GeminiLiveSession.connect(apiKey: apiKey, endpoint: endpoint),
      );

  final TranscriptionSession Function(String apiKey) _connect;

  /// Opens a new session authenticated with [apiKey], the caller's own key.
  TranscriptionSession connect(String apiKey) => _connect(apiKey);
}
