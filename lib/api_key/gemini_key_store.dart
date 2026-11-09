import 'dart:async';

/// {@template gemini_key_store}
/// Holds the person's own Gemini API key for as long as the app is open.
///
/// The key lives in memory only: it is not written to disk, browser storage or
/// anywhere on the backend. The backend gets it with each request that calls
/// Gemini and keeps nothing.
///
/// It tells whoever listens when a key is saved, so what was waiting for one,
/// such as the first dashboard, can start.
/// {@endtemplate}
class GeminiKeyStore {
  /// {@macro gemini_key_store}
  ///
  /// Starts with [key] already saved, if given.
  GeminiKeyStore([String? key]) : _key = key;

  String? _key;
  final _saved = StreamController<void>.broadcast(sync: true);

  /// Emits each time a key is saved.
  Stream<void> get saved => _saved.stream;

  /// The key, or `null` before one was entered.
  String? get key => _key;

  /// Whether a key was entered.
  bool get hasKey => _key != null;

  /// Keeps [key] in place of any earlier one. Surrounding whitespace is
  /// dropped, because a pasted key often carries some.
  void save(String key) {
    _key = key.trim();
    _saved.add(null);
  }

  /// The key, shaped as the agent's token provider wants it.
  Future<String?> token() async => _key;
}
