import 'package:home_backend/data/mock_database.dart';
import 'package:home_backend/devices/device_exceptions.dart';
import 'package:home_backend/devices/device_state_machine.dart';
import 'package:home_backend/tools/agent_tool.dart';
import 'package:home_backend/tools/device_command_tools.dart';
import 'package:home_backend/tools/google_home_tool.dart';
import 'package:home_backend/tools/todo_lists_tool.dart';
import 'package:test/test.dart';

import '../fixtures/fixture_database.dart';

void main() {
  late MockDatabase database;
  late DeviceStateMachine machine;

  setUp(() async {
    database = await loadFixtureDatabase();
    machine = DeviceStateMachine(database);
  });

  Matcher message(String text) =>
      throwsA(isA<CommandRejected>().having((e) => e.message, 'message', text));

  group('run_device_command', () {
    late AgentTool tool;
    setUp(() => tool = runDeviceCommandTool(machine));

    test('describes its arguments', () {
      expect(tool.name, 'run_device_command');
      expect(
        tool.inputSchema,
        containsPair('required', ['device_id', 'command']),
      );
    });

    test('changes the state every read tool sees', () async {
      final result =
          (await tool.call({'device_id': 'oven', 'command': 'start'}))!
              as Map<String, Object?>;

      expect(result['changed'], isTrue);
      expect(result['summary'], 'oven state: stopped -> running');
      final read = (await googleHomeTool(database).call({
        'user_id': 'ana',
        'room': 'kitchen',
      }))!.toString();
      expect(read, contains('state: running'));
    });

    test('passes the value through', () async {
      await tool.call({
        'device_id': 'kitchen_pendants',
        'command': 'set_level',
        'value': 30,
      });

      final read =
          database.homeFor('ana', room: 'kitchen')['devices']!
              as List<Map<String, dynamic>>;
      final pendants = read.firstWhere((d) => d['id'] == 'kitchen_pendants');
      expect(
        (pendants['traits'] as Map<String, dynamic>)['LevelControl'],
        {'currentLevel': 30},
      );
    });

    test('a failure is an Exception the model can read', () {
      expect(
        () => tool.call({'device_id': 'ovenn', 'command': 'start'}),
        throwsA(isA<DeviceNotFound>()),
      );
    });

    test('rejects an unknown command and a missing device id', () {
      expect(
        () => tool.call({'device_id': 'oven', 'command': 'explode'}),
        throwsA(isA<CommandRejected>()),
      );
      expect(
        () => tool.call({'command': 'start'}),
        message('device_id is required.'),
      );
    });
  });

  group('run_scene', () {
    late AgentTool tool;
    setUp(() => tool = runSceneTool(machine));

    test('starts the scene', () async {
      final result =
          (await tool.call({'scene_id': 'dinner_party'}))!
              as Map<String, Object?>;

      expect(result['changed'], isTrue);
      expect(database.scenes.single['state'], 'running');
    });

    test('needs a scene id', () {
      expect(() => tool.call({}), message('scene_id is required.'));
    });
  });

  group('set_todo_item', () {
    late AgentTool tool;
    setUp(() => tool = setTodoItemTool(machine));

    test('ticks an item, with or without a list', () async {
      await tool.call({'item_id': 'ribs', 'checked': true});
      await tool.call({
        'item_id': 'cream',
        'checked': true,
        'list_id': 'shopping',
      });

      final items = database.todoLists.single['items'] as List<dynamic>;
      expect(
        items.cast<Map<String, dynamic>>().where((i) => i['checked'] == true),
        hasLength(4),
      );
    });

    test('needs a boolean', () {
      expect(
        () => tool.call({'item_id': 'ribs', 'checked': 'yes'}),
        message('checked must be true or false.'),
      );
    });
  });

  group('get_todo_lists', () {
    final tool = todoListsTool(
      MockDatabase(
        users: {
          'users': [
            {'id': 'ana', 'name': 'Ana', 'role': 'Host'},
          ],
        },
        home: <String, dynamic>{},
        todos: {
          'source': 's',
          'lists': [
            {
              'id': 'shopping',
              'owners': ['ana'],
              'sharedWith': <String>[],
            },
          ],
        },
      ),
    );

    test('is named and requires a user id', () {
      expect(tool.name, 'get_todo_lists');
      expect(tool.inputSchema, containsPair('required', ['user_id']));
    });

    test('returns the lists of a user', () async {
      final result = (await tool.call({'user_id': 'ana'}))! as Map;
      expect(result['lists'], hasLength(1));
    });

    test('throws a recoverable exception for an unknown user', () {
      expect(
        () => tool.call({'user_id': 'nobody'}),
        throwsA(isA<MockDataNotFound>()),
      );
    });
  });
}
