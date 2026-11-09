import 'package:home_backend/data/mock_database.dart';
import 'package:home_backend/devices/device_command.dart';
import 'package:home_backend/devices/device_exceptions.dart';
import 'package:home_backend/devices/device_state_machine.dart';
import 'package:test/test.dart';

import '../fixtures/fixture_database.dart';

Matcher rejected(String message) => throwsA(
  isA<CommandRejected>().having((e) => e.message, 'message', message),
);

Matcher notFound(String message) => throwsA(
  isA<DeviceNotFound>().having((e) => e.message, 'message', message),
);

void main() {
  late MockDatabase database;
  late DeviceStateMachine machine;

  Map<String, dynamic> device(String id) =>
      database.homeDevices.firstWhere((d) => d['id'] == id);
  Map<String, dynamic> trait(String id, String name) =>
      (device(id)['traits'] as Map<String, dynamic>)[name]
          as Map<String, dynamic>;

  setUp(() async {
    database = await loadFixtureDatabase();
    machine = DeviceStateMachine(database);
  });

  group('power', () {
    test('starts the oven and records what changed', () {
      final result = machine.setPower('oven', on: true);

      expect(result.changed, isTrue);
      final change = result.changes.single;
      expect(change.deviceId, 'oven');
      expect(change.trait, 'OperationalState');
      expect(change.from, 'stopped');
      expect(change.to, 'running');
      expect(result.summary, 'oven state: stopped -> running');
      expect(result.toJson()['changes'], [change.toJson()]);
    });

    test('the change is what every read tool sees', () {
      machine.setPower('oven', on: true);

      final read = database.homeFor('ana', room: 'kitchen');
      final oven = (read['devices']! as List<Map<String, dynamic>>).firstWhere(
        (d) => d['id'] == 'oven',
      );
      final traits = oven['traits'] as Map<String, dynamic>;
      expect(
        (traits['OperationalState'] as Map<String, dynamic>)['state'],
        'running',
      );
    });

    test('is a no-op when the device is already there', () {
      machine.setPower('oven', on: false);
      final result = machine.setPower('oven', on: false);

      expect(result.changed, isFalse);
      expect(result.summary, contains('nothing changed'));
    });

    test('flips a light through OnOff', () {
      machine.setPower('kitchen_pendants', on: false);
      expect(trait('kitchen_pendants', 'OnOff')['onOff'], isFalse);
    });

    test('runs and stops the range hood fan', () {
      machine.execute('range_hood', DeviceCommand.start);
      expect(trait('range_hood', 'FanControl'), {
        'fanMode': 'low',
        'percentSetting': 33,
      });
      machine.execute('range_hood', DeviceCommand.stop);
      expect(trait('range_hood', 'FanControl')['fanMode'], 'off');
    });

    test('switches the thermostat mode', () {
      machine.setPower('thermostat', on: false);
      expect(trait('thermostat', 'Thermostat')['mode'], 'off');
      machine.setPower('thermostat', on: true);
      expect(trait('thermostat', 'Thermostat')['mode'], 'heat');
    });

    test('opens and closes the blinds', () {
      machine.setPower('blinds', on: false);
      expect(
        trait('living_blinds', 'WindowCovering')['positionPercentOpen'],
        0,
      );
      machine.setPower('blinds', on: true);
      expect(
        trait('living_blinds', 'WindowCovering')['positionPercentOpen'],
        100,
      );
    });

    test('opening a locked garage door unlocks it first', () {
      final result = machine.setPower('garage_door', on: true);

      expect(result.changes.map((c) => c.trait), ['DoorLock', 'OpenClose']);
      expect(trait('garage_door', 'DoorLock')['lockState'], 'unlocked');
      expect(trait('garage_door', 'OpenClose')['openState'], 'open');
    });

    test('starts and stops charging', () {
      machine.setPower('ev_charger', on: true);
      expect(trait('ev_charger', 'EnergyEvse')['state'], 'charging');
      machine.setPower('ev_charger', on: false);
      expect(trait('ev_charger', 'EnergyEvse')['state'], 'pluggedInNoDemand');
    });

    test('stops the timer', () {
      machine.setPower('dessert_timer', on: false);
      expect(trait('dessert_timer', 'Timer')['state'], 'stopped');
      machine.setPower('dessert_timer', on: true);
      expect(trait('dessert_timer', 'Timer')['state'], 'running');
    });

    test('toggles energy saver', () {
      machine.setPower('energy_meter', on: true);
      expect(trait('energy_meter', 'EnergySaver')['enabled'], isTrue);
    });

    test('arms and disarms the fridge door alarm', () {
      machine.setPower('fridge', on: false);
      expect(trait('fridge', 'AlarmSettings')['doorOpenAlarm'], 'disarmed');
      machine.setPower('fridge', on: true);
      expect(trait('fridge', 'AlarmSettings')['doorOpenAlarm'], 'armed');
    });

    test('unlocks and locks a door lock', () {
      machine.setPower('front_door', on: false);
      expect(trait('front_door', 'DoorLock')['lockState'], 'unlocked');
      machine.setPower('front_door', on: true);
      expect(trait('front_door', 'DoorLock')['lockState'], 'locked');
    });

    test('rejects a device with nothing to switch', () {
      expect(
        () => machine.setPower('coffee_maker', on: true),
        rejected("The coffee maker can't do that right now."),
      );
    });
  });

  group('open, close, lock', () {
    test('closes and opens the garage door', () {
      machine.execute('garage_door', DeviceCommand.open);
      expect(trait('garage_door', 'OpenClose')['openState'], 'open');
      machine.execute('garage_door', DeviceCommand.close);
      expect(trait('garage_door', 'OpenClose')['openState'], 'closed');
    });

    test('rejects open on a device that cannot', () {
      expect(
        () => machine.execute('oven', DeviceCommand.open),
        rejected("The oven can't do that right now."),
      );
    });

    test('locks and unlocks', () {
      machine.execute('front_door', DeviceCommand.unlock);
      expect(trait('front_door', 'DoorLock')['lockState'], 'unlocked');
      machine.execute('front_door', DeviceCommand.lock);
      expect(trait('front_door', 'DoorLock')['lockState'], 'locked');
    });

    test('rejects locking an open garage door', () {
      machine.execute('garage_door', DeviceCommand.open);
      expect(
        () => machine.execute('garage_door', DeviceCommand.lock),
        rejected('The garage door has to close first.'),
      );
    });

    test('rejects lock and unlock on a device without a lock', () {
      expect(
        () => machine.execute('oven', DeviceCommand.lock),
        throwsA(isA<CommandRejected>()),
      );
      expect(
        () => machine.execute('oven', DeviceCommand.unlock),
        throwsA(isA<CommandRejected>()),
      );
    });
  });

  group('appliance commands', () {
    test('adds five minutes by default, or the value', () {
      machine.execute('timer', DeviceCommand.addTime);
      expect(trait('dessert_timer', 'Timer')['remainingMinutes'], 17);
      machine.execute('timer', DeviceCommand.addTime, value: 10);
      expect(trait('dessert_timer', 'Timer')['remainingMinutes'], 27);
    });

    test('restarts a stopped timer when time is added', () {
      machine
        ..setPower('dessert_timer', on: false)
        ..execute('timer', DeviceCommand.addTime);
      expect(trait('dessert_timer', 'Timer')['state'], 'running');
    });

    test('rejects bad minutes and the wrong device', () {
      expect(
        () => machine.execute('timer', DeviceCommand.addTime, value: 0),
        rejected('Add between 1 and 120 minutes.'),
      );
      expect(
        () => machine.execute('timer', DeviceCommand.addTime, value: 500),
        rejected('Add between 1 and 120 minutes.'),
      );
      expect(
        () => machine.execute('oven', DeviceCommand.addTime),
        throwsA(isA<CommandRejected>()),
      );
    });
  });

  group('levels and temperatures', () {
    test('sets a level', () {
      machine.execute('kitchen_pendants', DeviceCommand.setLevel, value: 25);
      expect(trait('kitchen_pendants', 'LevelControl')['currentLevel'], 25);
    });

    test('rejects a missing or out of range level', () {
      for (final value in [null, -1, 101]) {
        expect(
          () => machine.execute(
            'kitchen_pendants',
            DeviceCommand.setLevel,
            value: value,
          ),
          rejected('Pick a level from 0 to 100.'),
        );
      }
    });

    test('rejects a level on a device without one', () {
      expect(
        () => machine.execute('oven', DeviceCommand.setLevel, value: 5),
        throwsA(isA<CommandRejected>()),
      );
    });

    test('sets the thermostat and the oven', () {
      machine
        ..execute('thermostat', DeviceCommand.setTemperature, value: 71)
        ..execute('oven', DeviceCommand.setTemperature, value: 350);
      expect(trait('thermostat', 'Thermostat')['heatSetpointF'], 71);
      expect(trait('oven', 'TemperatureControl')['temperatureSetpointF'], 350);
    });

    test('rejects out of range temperatures', () {
      expect(
        () => machine.execute(
          'thermostat',
          DeviceCommand.setTemperature,
          value: 99,
        ),
        rejected('Pick a temperature from 50 to 90.'),
      );
      expect(
        () => machine.execute('oven', DeviceCommand.setTemperature),
        rejected('Pick a temperature from 150 to 500.'),
      );
      expect(
        () => machine.execute(
          'kitchen_pendants',
          DeviceCommand.setTemperature,
          value: 70,
        ),
        throwsA(isA<CommandRejected>()),
      );
    });

    test('steps the thermostat, the oven, a light and the blinds', () {
      machine
        ..adjust('thermostat', up: true)
        ..adjust('oven', up: false)
        ..adjust('kitchen_pendants', up: false)
        ..adjust('blinds', up: false);
      expect(trait('thermostat', 'Thermostat')['heatSetpointF'], 69);
      expect(trait('oven', 'TemperatureControl')['temperatureSetpointF'], 375);
      expect(trait('kitchen_pendants', 'LevelControl')['currentLevel'], 70);
      expect(
        trait('living_blinds', 'WindowCovering')['positionPercentOpen'],
        75,
      );
    });

    test('clamps a step at the end of the range', () {
      final result = machine.adjust('living_blinds', up: true);
      expect(result.changed, isFalse);
    });

    test('rejects a step on a device without a setting', () {
      expect(
        () => machine.adjust('fridge', up: true),
        rejected("The fridge can't do that right now."),
      );
    });
  });

  group('lookup and availability', () {
    test('finds a device by id, name, alias and loose spelling', () {
      for (final id in ['living_blinds', 'Blinds', 'LIVING-BLINDS', 'blinds']) {
        expect(machine.adjust(id, up: false).changed, isTrue);
        machine.undoLast();
      }
      expect(
        machine.adjust('office-thermostat', up: true).changes.single.deviceId,
        'office_thermostat',
      );
    });

    test('prefers an exact id over a name or alias', () {
      database.homeDevices.add({
        'id': 'extra',
        'name': 'Oven',
        'room': 'kitchen',
        'type': 'OvenDevice',
        'traits': {
          'OperationalState': {'state': 'stopped'},
        },
      });
      machine.setPower('oven', on: true);
      expect(trait('oven', 'OperationalState')['state'], 'running');
      expect(trait('extra', 'OperationalState')['state'], 'stopped');
    });

    test('an unknown device is not found', () {
      expect(
        () => machine.setPower('ovenn', on: true),
        notFound("Couldn't find the ovenn."),
      );
      expect(
        () => machine.setPower('rm -rf /', on: true),
        notFound("Couldn't find that."),
      );
    });

    test('an offline device is rejected', () {
      device('oven')['online'] = false;
      expect(
        () => machine.setPower('oven', on: true),
        rejected('The oven is offline.'),
      );
    });

    test('exceptions print their message', () {
      expect(const DeviceNotFound('x').toString(), 'x');
    });
  });

  group('scenes', () {
    test('runs the dinner party scene across devices', () {
      final result = machine.runScene('Dinner party scene');

      expect(result.changes.first.trait, 'Scene');
      expect(database.scenes.single['state'], 'running');
      expect(trait('kitchen_pendants', 'LevelControl')['currentLevel'], 40);
      expect(trait('table_lights', 'LevelControl')['currentLevel'], 40);
      expect(trait('thermostat', 'Thermostat')['heatSetpointF'], 70);
      expect(trait('dining_speaker', 'OnOff')['onOff'], isTrue);
      expect(trait('dining_speaker', 'MediaPlayback'), {
        'state': 'playing',
        'playlist': 'Dinner jazz',
      });
    });

    test('running a running scene is a no-op', () {
      machine.runScene('dinner_party');
      expect(machine.runScene('dining scene').changed, isFalse);
    });

    test('an unknown scene is not found', () {
      expect(
        () => machine.runScene('movie_night'),
        notFound("Couldn't find the movie night scene."),
      );
    });

    test('a failing step rolls the whole scene back', () {
      device('thermostat')['online'] = false;

      expect(
        () => machine.runScene('dinner_party'),
        throwsA(isA<CommandRejected>()),
      );

      expect(database.scenes.single['state'], 'ready');
      expect(trait('kitchen_pendants', 'LevelControl')['currentLevel'], 80);
    });

    test('runs the other action kinds a scene may carry', () {
      database.scenes.single['actions'] = [
        {'deviceId': 'oven', 'command': 'setTemperature', 'temperatureF': 300},
        {'deviceId': 'ev_charger', 'command': 'startCharging'},
      ];
      machine.runScene('dinner_party');
      expect(trait('oven', 'TemperatureControl')['temperatureSetpointF'], 300);
      expect(trait('ev_charger', 'EnergyEvse')['state'], 'charging');
    });

    test('rejects a scene action it does not know', () {
      database.scenes.single['actions'] = [
        {'deviceId': 'oven', 'command': 'explode'},
      ];
      expect(
        () => machine.runScene('dinner_party'),
        rejected("That scene can't run right now."),
      );
      expect(database.scenes.single['state'], 'ready');
    });

    test('rejects a playlist on a device that cannot play', () {
      database.scenes.single['actions'] = [
        {'deviceId': 'oven', 'command': 'startPlaylist', 'playlist': 'x'},
      ];
      expect(
        () => machine.runScene('dinner_party'),
        throwsA(isA<CommandRejected>()),
      );
    });
  });

  group('to-do lists', () {
    Map<String, dynamic> item(String id) =>
        (database.todoLists.single['items'] as List<dynamic>)
            .cast<Map<String, dynamic>>()
            .firstWhere((Map<String, dynamic> i) => i['id'] == id);

    test('ticks an item in a named list', () {
      final result = machine.toggleTodo(
        listId: 'shopping',
        itemId: 'ribs',
        checked: true,
      );

      expect(item('ribs')['checked'], isTrue);
      expect(result.changes.single.deviceId, 'shopping');
    });

    test('finds the item without a list, by list title too', () {
      machine.toggleTodo(itemId: 'shallots', checked: false);
      expect(item('shallots')['checked'], isFalse);
      machine.toggleTodo(
        listId: 'Shopping for tonight',
        itemId: 'ribs',
        checked: true,
      );
      expect(item('ribs')['checked'], isTrue);
    });

    test('ticking a ticked item is a no-op', () {
      expect(
        machine.toggleTodo(itemId: 'shallots', checked: true).changed,
        isFalse,
      );
    });

    test('an unknown item or list is not found', () {
      expect(
        () => machine.toggleTodo(itemId: 'nope', checked: true),
        notFound("Couldn't find that item on the list."),
      );
      expect(
        () =>
            machine.toggleTodo(listId: 'chores', itemId: 'ribs', checked: true),
        notFound("Couldn't find the chores list."),
      );
    });

    test('shares with the list target once', () {
      final result = machine.shareList('shopping');

      expect(database.todoLists.single['sharedWith'], ['marco']);
      expect(result.changed, isTrue);
      expect(machine.shareList('shopping').changed, isFalse);
    });

    test('a list with nobody to share with is rejected', () {
      database.todoLists.single.remove('shareTarget');
      expect(
        () => machine.shareList('shopping'),
        rejected("That list can't be shared."),
      );
    });

    test('sharing an unknown list is not found', () {
      expect(() => machine.shareList('chores'), throwsA(isA<DeviceNotFound>()));
    });
  });

  group('undo', () {
    test('has nothing to undo at first', () {
      final result = machine.undoLast();
      expect(result.changed, isFalse);
      expect(result.summary, 'There was nothing to undo.');
    });

    test('reverts the last command that changed something', () {
      machine
        ..setPower('oven', on: true)
        ..setPower('oven', on: true); // a no-op is not remembered

      final result = machine.undoLast();

      expect(trait('oven', 'OperationalState')['state'], 'stopped');
      expect(result.summary, startsWith('Undid the last change'));
      expect(result.changes.single.to, 'stopped');
      expect(machine.undoLast().changed, isFalse);
    });

    test('undoes a whole scene', () {
      machine
        ..runScene('dinner_party')
        ..undoLast();
      expect(database.scenes.single['state'], 'ready');
      expect(trait('thermostat', 'Thermostat')['heatSetpointF'], 68);
    });

    test('remembers only the last twenty commands', () {
      for (var i = 0; i < 25; i++) {
        machine.setPower('oven', on: i.isEven);
      }
      var undone = 0;
      while (machine.undoLast().changed) {
        undone++;
      }
      expect(undone, 20);
    });
  });

  group('lookup', () {
    test('lists the ids of devices, scenes and lists', () {
      expect(machine.deviceIds, contains('oven'));
      expect(machine.deviceIds, hasLength(20));
      expect(machine.sceneIds, ['dinner_party']);
      expect(machine.listIds, ['shopping']);
    });

    test('resolves an id, a name or an alias the way commands do', () {
      expect(machine.hasDevice('oven'), isTrue);
      expect(machine.hasDevice('Front door lock'), isTrue);
      expect(machine.hasDevice('front-door'), isTrue);
      expect(machine.hasDevice('ovn'), isFalse);
      expect(machine.hasScene('dinner_party'), isTrue);
      expect(machine.hasScene('oven'), isFalse);
      expect(machine.hasList('shopping'), isTrue);
      expect(machine.hasList('chores'), isFalse);
    });

    test('lists the item ids of a list, or null for an unknown list', () {
      expect(machine.itemIds('shopping'), contains('ribs'));
      expect(machine.itemIds('chores'), isNull);
    });
  });
}
