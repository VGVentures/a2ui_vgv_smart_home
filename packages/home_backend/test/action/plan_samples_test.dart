import 'package:home_backend/action/action_command.dart';
import 'package:home_backend/data/mock_database.dart';
import 'package:home_backend/devices/command_result.dart';
import 'package:home_backend/devices/device_command.dart';
import 'package:home_backend/devices/device_exceptions.dart';
import 'package:home_backend/devices/device_state_machine.dart';
import 'package:home_catalog/home_catalog.dart';
import 'package:test/test.dart';

/// Every press the components can raise, built exactly as the client builds it
/// (code writes the event, the model only chose the target), for every device,
/// scene and list in the shipped data.
///
/// None of them may be refused as malformed or as an unknown target. A device
/// that cannot do something right now may say so (`CommandRejected`).
void main() {
  late MockDatabase database;
  late DeviceStateMachine machine;

  setUp(() async {
    database = await MockDatabase.load();
    machine = DeviceStateMachine(database);
    // The presses are read at 4:30 PM, where the demo's Day is.
    database.clock.moveTo(DateTime.utc(2026, 10, 10, 16, 30));
  });

  // Parses and applies one event, failing on anything but a device's own
  // refusal.
  void applies(String name, Map<String, Object?> context) {
    final ActionCommand command;
    try {
      command = ActionCommand.parse(name, context);
    } on InvalidActionException catch (error) {
      fail('$name $context refused as invalid: ${error.message}');
    }
    try {
      expect(command.applyTo(machine), isA<CommandResult>());
    } on DeviceNotFound catch (error) {
      fail('$name $context unknown target: ${error.message}');
    } on CommandRejected catch (error) {
      expect(error.message.length, lessThanOrEqualTo(60));
    }
  }

  test('the shipped data has what the samples need', () {
    expect(database.homeDevices, isNotEmpty);
    expect(database.scenes, isNotEmpty);
    expect(database.todoLists, isNotEmpty);
  });

  test('toggle_device for every device, both ways', () {
    for (final device in database.homeDevices) {
      for (final on in [true, false]) {
        applies('toggle_device', {
          'progressLabel': 'Toggle ${device['name']}',
          'deviceId': device['id'],
          'on': on,
        });
      }
    }
  });

  test('adjust_device for every device, both ways', () {
    for (final device in database.homeDevices) {
      for (final direction in ['up', 'down']) {
        applies('adjust_device', {
          'progressLabel': 'Adjust ${device['name']}',
          'deviceId': device['id'],
          'direction': direction,
        });
      }
    }
  });

  test('run_device_action for every command on every device', () {
    for (final device in database.homeDevices) {
      for (final command in HomeActions.commands) {
        applies('run_device_action', {
          'progressLabel': '$command ${device['name']}',
          'deviceId': device['id'],
          'command': command,
          if (command == 'set_level') 'value': 40,
          if (command == 'set_temperature') 'value': 70,
          if (command == 'add_time') 'value': 5,
        });
      }
    }
  });

  test('run_scene for every scene', () {
    for (final scene in database.scenes) {
      applies('run_scene', {
        'progressLabel': 'Start ${scene['name']}',
        'sceneId': scene['id'],
      });
    }
  });

  test('toggle_todo and share_list for every list and item', () {
    for (final list in database.todoLists) {
      for (final item in list['items'] as List<dynamic>) {
        for (final checked in [true, false]) {
          applies('toggle_todo', {
            'progressLabel': 'Check off item',
            'listId': list['id'],
            'itemId': (item as Map<String, dynamic>)['id'],
            'checked': checked,
          });
        }
      }
      applies('share_list', {
        'progressLabel': 'Share list',
        'listId': list['id'],
      });
    }
  });

  test('undo_change', () {
    applies('undo_change', {'progressLabel': 'Undo change'});
  });

  group('presses that must change something', () {
    Map<String, dynamic> trait(String id, String name) =>
        (database.homeDevices.firstWhere((d) => d['id'] == id)['traits']
                as Map<String, dynamic>)[name]
            as Map<String, dynamic>;

    test('each runs, with the data it reads afterwards', () {
      applies('toggle_device', {'deviceId': 'oven', 'on': true});
      applies('toggle_device', {'deviceId': 'front_door', 'on': true});
      applies('adjust_device', {'deviceId': 'thermostat', 'direction': 'up'});
      applies('run_device_action', {'deviceId': 'car', 'command': 'start'});
      applies('run_scene', {'sceneId': 'dinner_party'});
      applies('toggle_todo', {
        'listId': 'shopping',
        'itemId': 'thyme',
        'checked': true,
      });
      applies('share_list', {'listId': 'shopping'});

      // The oven preheats from now, the front door locks and the car's climate
      // is set for the departure.
      expect(trait('oven', 'TemperatureControl')['scheduledStart'], '16:30');
      expect(trait('front_door', 'DoorLock')['lockState'], 'locked');
      expect(trait('car', 'Climate')['startAt'], '16:50');
      expect(trait('thermostat', 'Thermostat')['heatSetpointF'], 70);
      expect(database.scenes.single['state'], 'running');
      expect(database.todoLists.single['sharedWith'], ['marco']);
    });
  });

  test('the closed command list is the machine vocabulary', () {
    expect(HomeActions.commands, DeviceCommand.wireNames);
  });
}
