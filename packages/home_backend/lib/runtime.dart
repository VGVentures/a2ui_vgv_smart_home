import 'package:home_backend/cors/cors_config.dart';
import 'package:home_backend/prompt/system_prompt.dart';
import 'package:home_backend/session/session_store.dart';
import 'package:home_backend/transcribe/transcriber.dart';
import 'package:home_backend/validation/llm_response_validator.dart';

/// {@template runtime}
/// Everything the routes share between visitors, built once by `init` in
/// `main.dart` and handed to each request by `routes/_middleware.dart`.
/// {@endtemplate}
///
/// Dart Frog builds the server and its routes separately, so a process-wide
/// value is the only way `init` can hand them what it built.
class Runtime {
  /// {@macro runtime}
  ///
  /// Creates the runtime from its parts.
  const Runtime({
    required this.sessions,
    required this.systemPrompt,
    required this.validators,
    required this.transcriber,
    required this.cors,
  });

  /// The demo worlds of the visitors using the server, one each. The mock
  /// household, its clock, its devices and the model's tools all live in a
  /// world, so nothing a visitor changes reaches another.
  final SessionStore sessions;

  /// The system message sent with every request.
  final SystemPrompt systemPrompt;

  /// The checks a reply must pass before it reaches the client.
  final List<LlmResponseValidator> validators;

  /// Opens the `/transcribe` sessions.
  final Transcriber transcriber;

  /// The browser origins allowed to call the API.
  final CorsConfig cors;
}

Runtime? _runtime;

/// The [Runtime] built at boot. Throws before `init` has set it.
Runtime get runtime =>
    _runtime ?? (throw StateError('runtime accessed before init ran.'));

/// Stores [value] as the process-wide [Runtime].
set runtime(Runtime value) => _runtime = value;
