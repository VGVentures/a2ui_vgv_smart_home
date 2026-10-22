import 'package:genkit/genkit.dart' show Genkit;
import 'package:home_backend/data/mock_database.dart';
import 'package:home_backend/devices/device_state_machine.dart';
import 'package:home_backend/scenario/scenario_world.dart';
import 'package:home_backend/tools/agent_tools.dart';
import 'package:test/test.dart';

void main() {
  final database = MockDatabase(
    users: {
      'users': [
        {'id': 'ana', 'name': 'Ana', 'role': 'Host'},
      ],
    },
    home: <String, dynamic>{},
  );
  final tools = buildAgentTools(
    database: database,
    machine: DeviceStateMachine(database),
    world: ScenarioWorld(database),
  );

  test('buildAgentTools ships the read and write tools the prompt names', () {
    expect(
      tools.map((tool) => tool.name),
      containsAll([
        'get_user_data',
        'get_google_home_data',
        'get_home_activity',
        'get_inbox',
        'mark_inbox_read',
        'get_bakery_orders',
        'get_todo_lists',
        'run_device_command',
        'run_scene',
        'set_todo_item',
        'schedule_oven',
        'reschedule_guest_arrival',
        'request_bakery_delivery',
      ]),
    );
  });

  group('registerAgentTools', () {
    test('registers a runnable tool that takes arguments', () async {
      final registered = registerAgentTools(Genkit(), tools);
      final userData = registered.firstWhere((t) => t.name == 'get_user_data');

      final result = await userData.runRaw({'user_id': 'ana'});

      expect((result.result as Map)['id'], 'ana');
    });

    test('registers a runnable tool called without arguments', () async {
      final registered = registerAgentTools(Genkit(), tools);
      final userData = registered.firstWhere((t) => t.name == 'get_user_data');

      final result = await userData.runRaw(null);

      expect((result.result as Map)['users'], isA<List<dynamic>>());
    });
  });
}
