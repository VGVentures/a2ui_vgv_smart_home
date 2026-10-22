import 'package:json_schema_builder/json_schema_builder.dart';

/// {@template home_actions}
/// The actions a home component can raise, and the typed spec a model uses to
/// choose one.
///
/// The model never writes an action's name, context or label. It chooses a
/// target (a device id, a scene id, a command from a closed list) and the
/// client builds the event from it, so the backend only ever sees payloads
/// that code wrote. The ids the model chooses are checked against the real
/// devices while the response is generated, not when the user presses.
/// {@endtemplate}
abstract final class HomeActions {
  /// `toggle_device` {deviceId, on}.
  static const toggleDevice = 'toggle_device';

  /// `adjust_device` {deviceId, direction}.
  static const adjustDevice = 'adjust_device';

  /// `run_device_action` {deviceId, command}.
  static const runDeviceAction = 'run_device_action';

  /// `run_scene` {sceneId}.
  static const runScene = 'run_scene';

  /// `toggle_todo` {listId, itemId, checked}.
  static const toggleTodo = 'toggle_todo';

  /// `share_list` {listId}.
  static const shareList = 'share_list';

  /// `undo_change`: reverts the last command that changed something.
  static const undoChange = 'undo_change';

  /// `ask` {text}: not applied by the backend. The client sends `text` as a
  /// typed request, so the model handles it with its tools.
  static const ask = 'ask';

  /// The device commands the backend knows, as `run_device_action` takes them.
  static const List<String> commands = [
    'on',
    'off',
    'start',
    'stop',
    'open',
    'close',
    'lock',
    'unlock',
    'add_time',
    'set_level',
    'set_temperature',
    'up',
    'down',
  ];

  /// What a chip or an alert button does: exactly one of `command`, `scene`,
  /// `undo` or `ask`.
  static Schema spec({String? description}) => S.combined(
    description:
        description ??
        'What the press does. Exactly one of: a device command, a scene, '
            'undo, or a request for the assistant.',
    oneOf: [
      S.object(
        description: 'Run a command on a device.',
        properties: {
          'command': S.object(
            properties: {
              'deviceId': S.string(
                description: 'The id of a device from the device data.',
              ),
              'command': S.string(enumValues: commands),
            },
            required: ['deviceId', 'command'],
          ),
        },
        required: ['command'],
      ),
      S.object(
        description: 'Start a scene.',
        properties: {
          'scene': S.string(description: 'The id of a scene.'),
        },
        required: ['scene'],
      ),
      S.object(
        description: 'Undo the last change.',
        properties: {'undo': S.boolean()},
        required: ['undo'],
      ),
      S.object(
        description:
            'Anything that is not a single device command: the text is sent '
            'to the assistant as if the user had typed it.',
        properties: {
          'ask': S.string(
            description: 'The request, e.g. "Tell guests dinner is at 8:00".',
            maxLength: 120,
          ),
        },
        required: ['ask'],
      ),
    ],
  );
}
