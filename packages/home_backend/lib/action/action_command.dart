import 'package:home_backend/devices/command_result.dart';
import 'package:home_backend/devices/device_command.dart';
import 'package:home_backend/devices/device_state_machine.dart';

/// {@template invalid_action_exception}
/// Thrown when an action cannot be applied at all: an unknown name, or a known
/// action with a missing or mistyped field. Maps to `400`. The [message] is
/// safe to show to the user.
/// {@endtemplate}
class InvalidActionException implements Exception {
  /// {@macro invalid_action_exception}
  ///
  /// An action name outside the vocabulary.
  const InvalidActionException.unsupported()
    : message = "That action isn't supported.";

  /// {@macro invalid_action_exception}
  ///
  /// A known action with a missing or mistyped field, or an unreadable body.
  const InvalidActionException.malformed()
    : message = "That action couldn't be understood.";

  /// {@macro user_safe_reason}
  final String message;

  @override
  String toString() => message;
}

/// {@template action_command}
/// A component press the backend knows how to apply, parsed from the action's
/// `name` and `context`.
/// {@endtemplate}
///
/// Code writes every action: the model only chooses targets (ids and closed
/// enums) and the client builds the event from them, so the parser is strict.
/// The keys and types below are exact, with no aliases and no lenient forms.
/// `progressLabel` in the context is for the client's snackbar and is ignored.
///
/// - `toggle_device`: `deviceId`, `on` (bool)
/// - `adjust_device`: `deviceId`, `direction` (`up` or `down`)
/// - `run_device_action`: `deviceId`, `command` (a [DeviceCommand] wire
///   name), optional `value` (num)
/// - `run_scene`: `sceneId`
/// - `toggle_todo`: `listId`, `itemId`, `checked` (bool)
/// - `share_list`: `listId`
/// - `undo_change`: nothing
///
/// `ask` is not an action name here: the client sends it to `/generate` as a
/// typed request.
sealed class ActionCommand {
  /// {@macro action_command}
  const ActionCommand();

  /// {@macro action_command}
  ///
  /// Parses an action [name] and [context].
  ///
  /// Throws [InvalidActionException] for an unknown [name] or a missing or
  /// mistyped field.
  factory ActionCommand.parse(String name, Map<String, dynamic> context) {
    String text(String key) {
      final value = context[key];
      return value is String && value.isNotEmpty
          ? value
          : (throw const InvalidActionException.malformed());
    }

    bool flag(String key) {
      final value = context[key];
      return value is bool
          ? value
          : (throw const InvalidActionException.malformed());
    }

    return switch (name) {
      'toggle_device' => ToggleDevice(text('deviceId'), on: flag('on')),
      'adjust_device' => AdjustDevice(
        text('deviceId'),
        up: switch (context['direction']) {
          'up' => true,
          'down' => false,
          _ => throw const InvalidActionException.malformed(),
        },
      ),
      'run_device_action' => RunDeviceAction(
        text('deviceId'),
        DeviceCommand.tryParse(context['command']) ??
            (throw const InvalidActionException.malformed()),
        value: switch (context['value']) {
          null => null,
          final num value => value,
          _ => throw const InvalidActionException.malformed(),
        },
      ),
      'run_scene' => RunScene(text('sceneId')),
      'toggle_todo' => ToggleTodo(
        listId: text('listId'),
        itemId: text('itemId'),
        checked: flag('checked'),
      ),
      'share_list' => ShareList(text('listId')),
      'undo_change' => const UndoChange(),
      _ => throw const InvalidActionException.unsupported(),
    };
  }

  /// Every action name the backend accepts.
  static const names = [
    'toggle_device',
    'adjust_device',
    'run_device_action',
    'run_scene',
    'toggle_todo',
    'share_list',
    'undo_change',
  ];

  /// Applies the action to [machine].
  ///
  /// Throws a `DeviceCommandException` when the state machine rejects it.
  CommandResult applyTo(DeviceStateMachine machine);
}

/// {@template toggle_device}
/// `toggle_device`: switch a device on or off.
/// {@endtemplate}
class ToggleDevice extends ActionCommand {
  /// {@macro toggle_device}
  const ToggleDevice(this.deviceId, {required this.on});

  /// The device id.
  final String deviceId;

  /// The value the user chose.
  final bool on;

  @override
  CommandResult applyTo(DeviceStateMachine machine) =>
      machine.setPower(deviceId, on: on);
}

/// {@template adjust_device}
/// `adjust_device`: one step up or down on a stepper.
/// {@endtemplate}
class AdjustDevice extends ActionCommand {
  /// {@macro adjust_device}
  const AdjustDevice(this.deviceId, {required this.up});

  /// The device id.
  final String deviceId;

  /// Whether the step goes up.
  final bool up;

  @override
  CommandResult applyTo(DeviceStateMachine machine) =>
      machine.adjust(deviceId, up: up);
}

/// {@template run_device_action}
/// `run_device_action`: a named command on a device.
/// {@endtemplate}
class RunDeviceAction extends ActionCommand {
  /// {@macro run_device_action}
  const RunDeviceAction(this.deviceId, this.command, {this.value});

  /// The device id.
  final String deviceId;

  /// The command to run.
  final DeviceCommand command;

  /// The number some commands take.
  final num? value;

  @override
  CommandResult applyTo(DeviceStateMachine machine) =>
      machine.execute(deviceId, command, value: value);
}

/// {@template run_scene}
/// `run_scene`: start a scene.
/// {@endtemplate}
class RunScene extends ActionCommand {
  /// {@macro run_scene}
  const RunScene(this.sceneId);

  /// The scene id.
  final String sceneId;

  @override
  CommandResult applyTo(DeviceStateMachine machine) =>
      machine.runScene(sceneId);
}

/// {@template toggle_todo}
/// `toggle_todo`: tick or untick a list item.
/// {@endtemplate}
class ToggleTodo extends ActionCommand {
  /// {@macro toggle_todo}
  const ToggleTodo({
    required this.listId,
    required this.itemId,
    required this.checked,
  });

  /// The item id.
  final String itemId;

  /// The value the user chose.
  final bool checked;

  /// The list the item is on.
  final String listId;

  @override
  CommandResult applyTo(DeviceStateMachine machine) =>
      machine.toggleTodo(itemId: itemId, checked: checked, listId: listId);
}

/// {@template share_list}
/// `share_list`: share a list with the rest of the household.
/// {@endtemplate}
class ShareList extends ActionCommand {
  /// {@macro share_list}
  const ShareList(this.listId);

  /// The list id.
  final String listId;

  @override
  CommandResult applyTo(DeviceStateMachine machine) =>
      machine.shareList(listId);
}

/// {@template undo_change}
/// `undo_change`: reverts the last command that changed something.
/// {@endtemplate}
class UndoChange extends ActionCommand {
  /// {@macro undo_change}
  const UndoChange();

  @override
  CommandResult applyTo(DeviceStateMachine machine) => machine.undoLast();
}
