import 'package:meta/meta.dart';

/// {@template gemini_api_key}
/// The caller's own Gemini API key, read from the request that carries it.
/// {@endtemplate}
///
/// The server never stores it: it lives in the request context, is handed to
/// the model call and is gone when the response is sent. [toString] hides it so
/// a log line can't leak it.
@immutable
class GeminiApiKey {
  /// {@macro gemini_api_key}
  ///
  /// Wraps [value], the key as the caller sent it.
  const GeminiApiKey(this.value);

  /// The key itself.
  final String value;

  /// [text] with every occurrence of the key replaced, for anything that is
  /// about to be logged.
  String redact(String text) => text.replaceAll(value, '[redacted]');

  @override
  String toString() => 'GeminiApiKey(<redacted>)';
}
