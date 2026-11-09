/// {@template app_config}
/// Build-time configuration, read from the JSON file passed with
/// `--dart-define-from-file=config.json`. See `config.example.json`.
///
/// No API key is here, and none can be: each person enters their own Gemini key
/// when the app opens, and it is never stored.
/// {@endtemplate}
abstract final class AppConfig {
  /// The base URL of the backend, `http://localhost:8080` unless
  /// `GENUI_BACKEND_URL` says otherwise.
  static const backendUrl = String.fromEnvironment(
    'GENUI_BACKEND_URL',
    defaultValue: 'http://localhost:8080',
  );
}
