import 'package:dart_frog/dart_frog.dart';
import 'package:genkit/genkit.dart' show Message, Role, TextPart;
import 'package:home_backend/api_error.dart';
import 'package:home_backend/gemini_key/gemini_api_key.dart';
import 'package:home_backend/generate/generate_request.dart';
import 'package:home_backend/llm/llm.dart';
import 'package:home_backend/prompt/system_prompt.dart';
import 'package:home_backend/validation/llm_response_validator.dart';
import 'package:logging/logging.dart';

const _retryInstruction =
    'Reissue your response, fixing every error above: use only components '
    'from the catalog and only the ids and commands listed as valid.';

/// Runs the generation shared by `POST /generate` and `POST /action`: the
/// system prompt, the conversation, the model, the repair of what code can
/// mend, and one validated retry.
///
/// The reply is buffered and validated before it is returned, so a bad reply
/// is a real `422` instead of an already committed `200` stream. [routeName] is
/// the route's path segment and names the logger. [prompt] replaces the last
/// user message when given; the history still comes from [request].
Future<Response> runGeneration(
  RequestContext context, {
  required String routeName,
  required GenerateRequest request,
  String? prompt,
}) async {
  final log = Logger('routes.$routeName');
  final generate = context.read<Generate>();
  final key = context.read<GeminiApiKey>();
  final validators = context.read<List<LlmResponseValidator>>();

  final messages = [
    _message(Role.system, context.read<SystemPrompt>().text),
    for (final message in request.history)
      _message(
        message.role == GenerateMessageRole.assistant ? Role.model : Role.user,
        message.content,
      ),
    _message(Role.user, prompt ?? request.prompt),
  ];

  try {
    var reply = _repair(log, validators, await generate(key.value, messages));
    var errors = _validate(validators, reply);
    if (errors.isNotEmpty) {
      log.warning('Reply failed validation, retrying: ${errors.join(' | ')}');
      messages
        ..add(_message(Role.model, reply))
        ..add(
          _message(Role.user, '${errors.join('\n')}\n\n$_retryInstruction'),
        );
      reply = _repair(log, validators, await generate(key.value, messages));
      errors = _validate(validators, reply);
    }
    if (errors.isNotEmpty) {
      log.severe('Validation exhausted: ${errors.join(' | ')}');
      return const ApiError.unprocessableEntity().toResponse();
    }
    return Response.json(body: {'text': reply});
  } on Object catch (error, stackTrace) {
    // The cause stays in the log: forwarding it would leak provider internals.
    // The caller's key is scrubbed first, in case the provider echoed it.
    log.severe('Generation failed: ${key.redact('$error')}', null, stackTrace);
    return const ApiError.badGateway().toResponse();
  }
}

Message _message(Role role, String text) => Message(
  role: role,
  content: [TextPart(text: text)],
);

/// The trimmed [reply], with what a validator can mend put right first: a
/// screen off the grid is laid out again with the model's own cards.
String _repair(
  Logger log,
  List<LlmResponseValidator> validators,
  String reply,
) {
  final trimmed = reply.trim();
  var repaired = trimmed;
  for (final validator in validators.whereType<LlmResponseRepairer>()) {
    repaired = validator.repair(repaired);
  }
  if (repaired != trimmed) log.info('Laid the cards of the reply out again.');
  return repaired;
}

List<String> _validate(List<LlmResponseValidator> validators, String reply) => [
  for (final validator in validators) ...?validator.validate(reply),
];
