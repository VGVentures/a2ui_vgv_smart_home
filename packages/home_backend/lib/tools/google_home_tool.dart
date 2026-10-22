import 'package:home_backend/data/mock_database.dart';
import 'package:home_backend/tools/agent_tool.dart';
import 'package:home_backend/tools/tool_args.dart';

/// A tool that returns the Google Home data model for one user.
///
/// The result carries the structure, rooms, devices with their trait values,
/// groups and the user's automations. Calendar and trips are
/// not Home data and have their own tools. `room` and `device_type` narrow the
/// devices.
AgentTool googleHomeTool(MockDatabase database) {
  return AgentTool(
    name: 'get_google_home_data',
    description:
        'Returns the Google Home data model of the Rivera household as one '
        'user sees it: structure, rooms, devices with trait values, groups '
        "and that user's automations. Every device and automation has an `id`; "
        'scenes are the automations with `"kind": "scene"`. These are the ids '
        'a screen may point at (a DeviceCard `deviceId`, a SceneCard '
        '`sceneId`, a command target). Optionally narrow the devices by room '
        'or device type. Calendar and trips are not part '
        'of it, use their own tools.',
    inputSchema: const {
      'type': 'object',
      'properties': {
        'user_id': {
          'type': 'string',
          'description': 'The user id, for example "ana" or "marco".',
        },
        'room': {
          'type': 'string',
          'description': 'Optional room id or name, for example "Kitchen".',
        },
        'device_type': {
          'type': 'string',
          'description':
              'Optional Home APIs device type, for example "OvenDevice".',
        },
      },
      'required': ['user_id'],
    },
    onCall: (args) {
      return database.homeFor(
        requiredUserId(args),
        room: args['room'] as String?,
        deviceType: args['device_type'] as String?,
      );
    },
  );
}
