import 'package:home_backend/action/action_command.dart';
import 'package:home_backend/generate/generate_request.dart';

/// {@template action_request}
/// Body of a `POST /action` request: the conversation as `/generate` takes it,
/// plus the `action` the user pressed.
/// {@endtemplate}
///
/// ```json
/// {
///   "messages": [{"role": "user", "content": "<interaction JSON>"}],
///   "action": {"name": "toggle_device", "context": {"progressLabel": "Turn off
///   oven", "deviceId": "oven", "on": false}}
/// }
/// ```
class ActionRequest {
  /// {@macro action_request}
  const ActionRequest({required this.conversation, required this.command});

  /// {@macro action_request}
  ///
  /// Parses and validates an [ActionRequest].
  ///
  /// Throws [InvalidActionException] for a malformed body, or a known action
  /// missing a field it needs.
  factory ActionRequest.fromJson(Map<String, dynamic> json) {
    final GenerateRequest conversation;
    try {
      conversation = GenerateRequest.fromJson(json);
    } on FormatException {
      throw const InvalidActionException.malformed();
    }
    final action = json['action'];
    if (action is! Map<String, dynamic>) {
      throw const InvalidActionException.malformed();
    }
    final name = action['name'];
    final context = action['context'] ?? <String, dynamic>{};
    if (name is! String || context is! Map<String, dynamic>) {
      throw const InvalidActionException.malformed();
    }
    return ActionRequest(
      conversation: conversation,
      command: ActionCommand.parse(name, context),
    );
  }

  /// The conversation, ending with the user's interaction message.
  final GenerateRequest conversation;

  /// The validated command to apply.
  final ActionCommand command;
}
