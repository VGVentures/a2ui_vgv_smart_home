import 'package:dart_frog/dart_frog.dart';
import 'package:home_backend/cors/cors_config.dart';
import 'package:home_backend/cors/cors_middleware.dart';
import 'package:home_backend/gemini_key/gemini_key_middleware.dart';
import 'package:home_backend/prompt/system_prompt.dart';
import 'package:home_backend/runtime.dart';
import 'package:home_backend/session/session_middleware.dart';
import 'package:home_backend/transcribe/transcriber.dart';
import 'package:home_backend/validation/llm_response_validator.dart';
import 'package:logging/logging.dart';

final _log = Logger('requests');

/// Wraps every route with what it reads from the [runtime] (system prompt,
/// validators, transcriber, CORS allowlist), the Gemini key check, the
/// visitor's session, request logging and CORS.
Handler middleware(Handler handler) {
  return handler
      .use(provider<SystemPrompt>((_) => runtime.systemPrompt))
      .use(
        provider<List<LlmResponseValidator>>((_) => runtime.validators),
      )
      .use(provider<Transcriber>((_) => runtime.transcriber))
      .use(provider<CorsConfig>((_) => runtime.cors))
      .use(requireGeminiKey())
      .use(provideSession(runtime.sessions))
      .use(
        requestLogger(
          logger: (message, isError) =>
              isError ? _log.severe(message) : _log.info(message),
        ),
      )
      .use(cors(runtime.cors));
}
