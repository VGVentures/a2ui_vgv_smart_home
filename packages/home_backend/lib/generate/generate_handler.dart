import 'package:dart_frog/dart_frog.dart';
import 'package:genkit/genkit.dart'
    show Message, MessageExtension, Role, TextPart;
import 'package:home_backend/a2ui/reply_outcome.dart';
import 'package:home_backend/a2ui/reply_pipeline.dart';
import 'package:home_backend/api_error.dart';
import 'package:home_backend/devices/device_filler.dart';
import 'package:home_backend/gemini_key/gemini_api_key.dart';
import 'package:home_backend/generate/generate_request.dart';
import 'package:home_backend/llm/llm.dart';
import 'package:home_backend/prompt/system_prompt.dart';
import 'package:home_catalog/home_catalog.dart' show dashboardSurfaceId;
import 'package:logging/logging.dart';

const _retryInstruction =
    'Reissue your response, fixing every error above: use only components '
    'from the catalog and only the ids and commands listed as valid.';

const _createNote =
    'The surface "$dashboardSurfaceId" does not exist yet: send a '
    '`createSurface` for it, then an `updateComponents` with every component '
    'of the dashboard.';

const _updateNote =
    'The surface "$dashboardSurfaceId" is already on screen: do not send '
    '`createSurface`. Send one `updateComponents` for it with every component '
    'of the new dashboard, `root` included.';

/// Runs the generation shared by `POST /generate` and `POST /action`: the
/// system prompt, the conversation, the model, the reply pipeline and one
/// validated retry.
///
/// The reply is buffered and checked before it is returned, so a bad reply is
/// a real `422` instead of an already committed `200` stream. The body is
/// `{messages, reply}`: `messages` are the validated A2UI 1.0 messages for the
/// panel, and `reply` is the model's own text, which the panel keeps as the
/// assistant turn of the history, since the backend holds none. [routeName] is
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
  final pipeline = context.read<ReplyPipeline>();
  final surfaceExists = request.surfaceIds.contains(dashboardSurfaceId);

  final messages = [
    _message(Role.system, context.read<SystemPrompt>().text),
    for (final message in request.history)
      _message(
        message.role == GenerateMessageRole.assistant ? Role.model : Role.user,
        message.content,
      ),
    _message(
      Role.user,
      '${prompt ?? request.prompt}\n\n'
      '${surfaceExists ? _updateNote : _createNote}',
    ),
  ];
  final userId = userIdOf([for (final m in messages.skip(1)) m.text]);

  try {
    late String reply;
    late ReplyOutcome outcome;
    for (var attempt = 0; attempt < 2; attempt++) {
      reply = (await generate(key.value, messages)).trim();
      outcome = pipeline.process(
        reply,
        surfaceExists: surfaceExists,
        userId: userId,
      );
      if (outcome.isAccepted) break;
      if (attempt == 0) {
        log.warning('Reply failed validation, retrying: ${_joined(outcome)}');
        messages
          ..add(_message(Role.model, reply))
          ..add(
            _message(
              Role.user,
              '${outcome.errors.join('\n')}\n\n$_retryInstruction',
            ),
          );
      }
    }
    if (!outcome.isAccepted) {
      log.severe('Validation exhausted: ${_joined(outcome)}');
      return const ApiError.unprocessableEntity().toResponse();
    }
    return Response.json(body: {'messages': outcome.messages, 'reply': reply});
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

String _joined(ReplyOutcome outcome) => outcome.errors.join(' | ');
