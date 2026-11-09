import 'package:home_backend/devices/device_command.dart';
import 'package:home_backend/devices/device_exceptions.dart';
import 'package:home_backend/devices/device_state_machine.dart';
import 'package:home_backend/tools/agent_tool.dart';

/// A tool that changes a device, so a spoken or typed request moves the same
/// state a component press does.
///
/// It calls the [DeviceStateMachine], the only writer of the home data, and
/// returns what changed. A device that does not exist or cannot do the command
/// throws, and the model gets the reason back.
AgentTool runDeviceCommandTool(DeviceStateMachine machine) {
  return AgentTool(
    name: 'run_device_command',
    description:
        'Changes one home device and returns what changed. Use it when the '
        'user asks you to do something to a device, then read the data again '
        'before you describe the result. Commands: on and off (run or stop, '
        'light, arm, open or lock, by the device), start, stop, open, close, '
        'lock, unlock, add_time '
        '(timer, value is minutes, default 5), set_level (value 0 to 100), '
        'set_temperature (value in F), up and down (one step on the main '
        'setting). A command that finds the device already there changes '
        'nothing.',
    inputSchema: {
      'type': 'object',
      'properties': {
        'device_id': {
          'type': 'string',
          'description': 'The device id, for example "oven" or "garage_door".',
        },
        'command': {'type': 'string', 'enum': DeviceCommand.wireNames},
        'value': {
          'type': 'number',
          'description':
              'The number set_level, set_temperature and add_time '
              'take.',
        },
      },
      'required': ['device_id', 'command'],
    },
    onCall: (args) {
      final command = DeviceCommand.tryParse(args['command']);
      if (command == null) {
        throw CommandRejected(
          'Unknown command. Use one of: ${DeviceCommand.wireNames.join(', ')}.',
        );
      }
      return machine
          .execute(
            _text(args, 'device_id'),
            command,
            value: args['value'] as num?,
          )
          .toJson();
    },
  );
}

/// A tool that starts a scene such as the dinner party scene.
AgentTool runSceneTool(DeviceStateMachine machine) {
  return AgentTool(
    name: 'run_scene',
    description:
        'Starts a scene, a named group of device settings such as the dinner '
        'party scene, and returns what changed. Scenes are the automations '
        'marked kind "scene" in the Google Home data.',
    inputSchema: const {
      'type': 'object',
      'properties': {
        'scene_id': {
          'type': 'string',
          'description': 'The scene id, for example "dinner_party".',
        },
      },
      'required': ['scene_id'],
    },
    onCall: (args) => machine.runScene(_text(args, 'scene_id')).toJson(),
  );
}

/// A tool that ticks or unticks a to-do item.
AgentTool setTodoItemTool(DeviceStateMachine machine) {
  return AgentTool(
    name: 'set_todo_item',
    description:
        'Ticks or unticks an item on a to-do list and returns what changed.',
    inputSchema: const {
      'type': 'object',
      'properties': {
        'item_id': {'type': 'string', 'description': 'The item id.'},
        'checked': {'type': 'boolean'},
        'list_id': {
          'type': 'string',
          'description': 'Optional list id, for example "shopping".',
        },
      },
      'required': ['item_id', 'checked'],
    },
    onCall: (args) {
      final checked = args['checked'];
      if (checked is! bool) {
        throw const CommandRejected('checked must be true or false.');
      }
      return machine
          .toggleTodo(
            itemId: _text(args, 'item_id'),
            checked: checked,
            listId: args['list_id'] as String?,
          )
          .toJson();
    },
  );
}

String _text(Map<String, dynamic> args, String key) {
  final value = args[key];
  if (value is! String || value.isEmpty) {
    throw CommandRejected('$key is required.');
  }
  return value;
}
