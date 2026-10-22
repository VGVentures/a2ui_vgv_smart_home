import 'dart:io';

import 'package:dart_frog/dart_frog.dart';
import 'package:home_backend/action/action_command.dart';
import 'package:home_backend/action/action_request.dart';
import 'package:home_backend/api_error.dart';
import 'package:home_backend/devices/command_result.dart';
import 'package:home_backend/devices/device_exceptions.dart';
import 'package:home_backend/devices/device_state_machine.dart';
import 'package:home_backend/generate/generate_handler.dart';
import 'package:home_backend/generate/generate_request.dart';
import 'package:logging/logging.dart';

final _log = Logger('routes.action');

/// `POST /action`: a component press.
///
/// Code wrote the action: the model only chose targets, the client built the
/// event, so the vocabulary is strict (see [ActionCommand.parse]). The backend
/// applies the press to the device state machine first, with no model in the
/// loop, then runs the same generation as `/generate` so the model
/// composes the updated surface from the fresh data. The response is the same
/// `{text, usage}` body.
Future<Response> onRequest(RequestContext context) async {
  if (context.request.method != HttpMethod.post) {
    return Response(statusCode: HttpStatus.methodNotAllowed);
  }

  final ActionRequest request;
  try {
    final body = await context.request.json() as Map<String, dynamic>;
    request = ActionRequest.fromJson(body);
  } on InvalidActionException catch (error) {
    return ApiError.badRequest(message: error.message).toResponse();
  } catch (_) {
    return const ApiError.badRequest(
      message: "That action couldn't be understood.",
    ).toResponse();
  }

  final CommandResult result;
  try {
    result = request.command.applyTo(context.read<DeviceStateMachine>());
  } on DeviceNotFound catch (error) {
    _log.info('POST /action not found: ${error.message}');
    return ApiError.notFound(message: error.message).toResponse();
  } on CommandRejected catch (error) {
    _log.info('POST /action rejected: ${error.message}');
    return ApiError.conflict(message: error.message).toResponse();
  }
  _log.info('POST /action applied: ${result.summary}');

  return runGeneration(
    context,
    routeName: 'action',
    request: request.conversation,
    prompt: _promptFor(request.conversation, result),
  );
}

/// The interaction JSON the client sent, then a plain note of what the state
/// machine did, so the model composes from fresh data and claims nothing else.
String _promptFor(GenerateRequest conversation, CommandResult result) {
  final summary = result.summary.replaceFirst(RegExp(r'\.$'), '');
  final note = result.changed
      ? 'The backend already applied this command: $summary.'
      : 'The backend handled this command and no device state changed: '
            '$summary.';
  return '${conversation.prompt}\n\n$note Read the current device data with '
      'your tools and compose the updated dashboard; do not claim anything '
      'the data does not show.';
}
