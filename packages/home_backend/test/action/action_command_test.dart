import 'package:home_backend/action/action_command.dart';
import 'package:home_backend/action/action_request.dart';
import 'package:home_backend/data/mock_database.dart';
import 'package:home_backend/devices/device_command.dart';
import 'package:home_backend/devices/device_state_machine.dart';
import 'package:test/test.dart';

import '../fixtures/fixture_database.dart';

Matcher invalid(String message) => throwsA(
  isA<InvalidActionException>().having((e) => e.message, 'message', message),
);

void main() {
  late MockDatabase database;
  late DeviceStateMachine machine;

  Map<String, dynamic> trait(String id, String name) =>
      (database.homeDevices.firstWhere((d) => d['id'] == id)['traits']
              as Map<String, dynamic>)[name]
          as Map<String, dynamic>;

  setUp(() async {
    database = await loadFixtureDatabase();
    machine = DeviceStateMachine(database);
  });

  group('ActionCommand.parse', () {
    test('knows exactly the seven names', () {
      final contexts = <String, Map<String, dynamic>>{
        'toggle_device': {'deviceId': 'oven', 'on': true},
        'adjust_device': {'deviceId': 'oven', 'direction': 'up'},
        'run_device_action': {'deviceId': 'oven', 'command': 'start'},
        'run_scene': {'sceneId': 'dinner_party'},
        'toggle_todo': {
          'listId': 'shopping',
          'itemId': 'ribs',
          'checked': true,
        },
        'share_list': {'listId': 'shopping'},
        'undo_change': <String, dynamic>{},
      };
      expect(contexts.keys, ActionCommand.names);
      for (final entry in contexts.entries) {
        expect(
          () => ActionCommand.parse(entry.key, entry.value),
          returnsNormally,
        );
      }
    });

    test('refuses a name outside the vocabulary as unsupported', () {
      for (final name in [
        'nope',
        'ask',
        'suggestion_selected',
        'lock_door',
        '',
      ]) {
        expect(
          () => ActionCommand.parse(name, {'progressLabel': 'Lock up'}),
          invalid("That action isn't supported."),
          reason: name,
        );
      }
    });

    test('refuses a missing or mistyped field as not understood', () {
      for (final entry in <(String, Map<String, dynamic>)>[
        ('toggle_device', {'on': true}),
        ('toggle_device', {'deviceId': '', 'on': true}),
        ('toggle_device', {'deviceId': 3, 'on': true}),
        ('toggle_device', {'deviceId': 'oven'}),
        ('toggle_device', {'deviceId': 'oven', 'on': 'true'}),
        ('toggle_device', {'deviceId': 'oven', 'on': 'on'}),
        ('toggle_device', {'deviceId': 'oven', 'on': 1}),
        ('adjust_device', {'deviceId': 'oven', 'direction': 'sideways'}),
        ('adjust_device', {'deviceId': 'oven', 'direction': 'Up'}),
        ('adjust_device', {'deviceId': 'oven'}),
        ('run_device_action', {'deviceId': 'oven'}),
        ('run_device_action', {'command': 'start'}),
        ('run_device_action', {'deviceId': 'oven', 'command': 'explode'}),
        ('run_device_action', {'deviceId': 'oven', 'command': 'turn_on'}),
        ('run_device_action', {'deviceId': 'oven', 'command': 5}),
        (
          'run_device_action',
          {'deviceId': 'timer', 'command': 'add_time', 'value': '10'},
        ),
        ('run_scene', {}),
        ('toggle_todo', {'itemId': 'ribs', 'checked': true}),
        ('toggle_todo', {'listId': 'shopping', 'checked': true}),
        ('toggle_todo', {'listId': 'shopping', 'itemId': 'ribs'}),
        ('share_list', {}),
      ]) {
        expect(
          () => ActionCommand.parse(entry.$1, entry.$2),
          invalid("That action couldn't be understood."),
          reason: '${entry.$1} ${entry.$2}',
        );
      }
    });

    test('the two refusals print their user-safe message', () {
      expect(
        const InvalidActionException.unsupported().toString(),
        "That action isn't supported.",
      );
      expect(
        const InvalidActionException.malformed().toString(),
        "That action couldn't be understood.",
      );
    });

    test('does not alias keys', () {
      for (final entry in <(String, Map<String, dynamic>)>[
        ('toggle_device', {'device_id': 'oven', 'on': true}),
        ('toggle_device', {'device': 'oven', 'on': true}),
        ('toggle_device', {'deviceId': 'oven', 'checked': true}),
        ('toggle_todo', {'list': 'shopping', 'item': 'ribs', 'done': true}),
        ('run_scene', {'scene': 'dinner_party'}),
      ]) {
        expect(
          () => ActionCommand.parse(entry.$1, entry.$2),
          invalid("That action couldn't be understood."),
          reason: '${entry.$1} ${entry.$2}',
        );
      }
    });

    test('reads the exact keys and a numeric value', () {
      final toggle =
          ActionCommand.parse('toggle_device', {
                'deviceId': 'oven',
                'on': false,
              })
              as ToggleDevice;
      final step =
          ActionCommand.parse('adjust_device', {
                'deviceId': 'office',
                'direction': 'down',
              })
              as AdjustDevice;
      final todo =
          ActionCommand.parse('toggle_todo', {
                'itemId': 'ribs',
                'checked': true,
                'listId': 'shopping',
              })
              as ToggleTodo;
      final run =
          ActionCommand.parse('run_device_action', {
                'deviceId': 'timer',
                'command': 'add_time',
                'value': 10,
              })
              as RunDeviceAction;
      final share =
          ActionCommand.parse('share_list', {'listId': 'shopping'})
              as ShareList;

      expect((toggle.deviceId, toggle.on), ('oven', false));
      expect((step.deviceId, step.up), ('office', false));
      expect(
        (todo.itemId, todo.checked, todo.listId),
        ('ribs', true, 'shopping'),
      );
      expect((run.command, run.value), (DeviceCommand.addTime, 10));
      expect(share.listId, 'shopping');
      expect(ActionCommand.parse('undo_change', {}), isA<UndoChange>());
    });

    test('ignores progressLabel', () {
      final command = ActionCommand.parse('run_scene', {
        'progressLabel': 'Start dinner party',
        'sceneId': 'dinner_party',
      });
      expect((command as RunScene).sceneId, 'dinner_party');
    });
  });

  group('applyTo', () {
    test('toggle_device', () {
      ActionCommand.parse('toggle_device', {
        'deviceId': 'oven',
        'on': true,
      }).applyTo(machine);
      expect(trait('oven', 'OperationalState')['state'], 'running');
    });

    test('adjust_device', () {
      ActionCommand.parse('adjust_device', {
        'deviceId': 'thermostat',
        'direction': 'down',
      }).applyTo(machine);
      expect(trait('thermostat', 'Thermostat')['heatSetpointF'], 67);
    });

    test('run_device_action with and without a value', () {
      ActionCommand.parse('run_device_action', {
        'deviceId': 'timer',
        'command': 'add_time',
        'value': 10,
      }).applyTo(machine);
      expect(trait('dessert_timer', 'Timer')['remainingMinutes'], 22);
    });

    test('run_scene, toggle_todo and share_list', () {
      ActionCommand.parse('run_scene', {
        'sceneId': 'dinner_party',
      }).applyTo(machine);
      ActionCommand.parse('toggle_todo', {
        'listId': 'shopping',
        'itemId': 'ribs',
        'checked': true,
      }).applyTo(machine);
      ActionCommand.parse('share_list', {
        'listId': 'shopping',
      }).applyTo(machine);
      expect(database.scenes.single['state'], 'running');
      expect(database.todoLists.single['sharedWith'], ['marco']);
    });

    test('undo_change reverts the last command', () {
      ActionCommand.parse('run_device_action', {
        'deviceId': 'oven',
        'command': 'start',
      }).applyTo(machine);
      final result = ActionCommand.parse('undo_change', {}).applyTo(machine);

      expect(result.changed, isTrue);
      expect(trait('oven', 'OperationalState')['state'], 'stopped');
    });

    test('undo_change with nothing to undo changes nothing', () {
      expect(
        ActionCommand.parse('undo_change', {}).applyTo(machine).changed,
        isFalse,
      );
    });

    test('RunDeviceAction exposes the parsed command', () {
      final command =
          ActionCommand.parse('run_device_action', {
                'deviceId': 'oven',
                'command': 'set_level',
                'value': 5,
              })
              as RunDeviceAction;
      expect(command.command, DeviceCommand.setLevel);
      expect(command.value, 5);
    });
  });

  group('ActionRequest', () {
    Map<String, dynamic> body({Object? action, Object? messages}) => {
      'messages':
          messages ??
          [
            {'role': 'user', 'content': 'pressed'},
          ],
      'action': ?action,
    };

    test('parses the conversation and the command', () {
      final request = ActionRequest.fromJson(
        body(
          action: {
            'name': 'share_list',
            'context': {'listId': 'shopping'},
          },
        ),
      );
      expect(request.conversation.prompt, 'pressed');
      expect(request.command, isA<ShareList>());
    });

    test('treats a missing context as empty', () {
      expect(
        ActionRequest.fromJson(body(action: {'name': 'undo_change'})).command,
        isA<UndoChange>(),
      );
      expect(
        () => ActionRequest.fromJson(body(action: {'name': 'run_scene'})),
        invalid("That action couldn't be understood."),
      );
    });

    test('rejects a bad conversation or action', () {
      for (final json in [
        body(messages: <Object>[], action: {'name': 'run_scene'}),
        body(),
        body(action: 'run_scene'),
        body(action: {'name': 3, 'context': <String, dynamic>{}}),
        body(action: {'name': 'run_scene', 'context': 'x'}),
      ]) {
        expect(
          () => ActionRequest.fromJson(json),
          invalid("That action couldn't be understood."),
        );
      }
    });

    test('an unknown name is unsupported', () {
      expect(
        () => ActionRequest.fromJson(
          body(action: {'name': 'nope', 'context': <String, dynamic>{}}),
        ),
        invalid("That action isn't supported."),
      );
    });
  });
}
