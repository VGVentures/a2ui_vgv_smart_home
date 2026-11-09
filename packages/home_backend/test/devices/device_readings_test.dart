import 'package:home_backend/data/mock_database.dart';
import 'package:home_backend/devices/device_command.dart';
import 'package:home_backend/devices/device_readings.dart';
import 'package:home_backend/devices/device_state_machine.dart';
import 'package:home_backend/scenario/scenario_world.dart';
import 'package:test/test.dart';

void main() {
  late MockDatabase database;
  late ScenarioWorld world;
  late DeviceStateMachine machine;
  late DeviceReadings readings;

  setUp(() async {
    database = await MockDatabase.load();
    world = ScenarioWorld(database);
    machine = DeviceStateMachine(database, onChanged: world.reconcile);
    readings = DeviceReadings(database);
  });

  test('paths address a device or one of its values', () {
    expect(devicePath('oven'), '/devices/oven');
    expect(devicePath('oven', 'status'), '/devices/oven/status');
  });

  test('knows the devices the panel shows, and no other', () {
    expect(readings.all().keys, DeviceReadings.deviceIds);
    expect(readings.of('doorbell'), isNull);
    expect(readings.of('no_such_device'), isNull);
  });

  group('the oven', () {
    test('is off until its programme starts, and says when that is', () {
      expect(readings.of('oven'), {
        'isActive': false,
        'status': 'Preheats at 6:30 PM',
        'value': '72',
      });
    });

    test('is off with nothing scheduled once it is stopped', () {
      machine.execute('oven', DeviceCommand.off);

      expect(readings.of('oven')!['status'], 'Off');
      expect(readings.of('oven')!['isActive'], isFalse);
    });

    test('is on and preheating as soon as it is started', () {
      machine.execute('oven', DeviceCommand.start);

      final oven = readings.of('oven')!;
      expect(oven['isActive'], isTrue);
      expect(oven['status'], startsWith('Preheating'));
    });

    test('follows the clock to the temperature it reaches', () {
      machine.execute('oven', DeviceCommand.start);
      world.moveTo(database.clock.now.add(const Duration(minutes: 20)));

      final oven = readings.of('oven')!;
      expect(oven['status'], startsWith('Ready'));
      expect(oven['value'], '400');
    });
  });

  group('the lights', () {
    test('are on at their level', () {
      expect(readings.of('table_lights'), {
        'isActive': true,
        'status': 'On · 100%',
        'value': '100',
      });
    });

    test('are off at zero', () {
      machine.execute('table_lights', DeviceCommand.off);

      expect(readings.of('table_lights'), {
        'isActive': false,
        'status': 'Off',
        'value': '0',
      });
    });
  });

  group('the speaker', () {
    test('is off', () {
      expect(readings.of('dining_speaker'), {
        'isActive': false,
        'status': 'Off',
        'value': '30',
      });
    });

    test('is on once started, and says so', () {
      machine.execute('dining_speaker', DeviceCommand.on);

      expect(readings.of('dining_speaker')!['status'], 'On');
      expect(readings.of('dining_speaker')!['isActive'], isTrue);
    });

    test('says what is playing', () {
      final traits =
          database.deviceOrNull('dining_speaker')!['traits']
              as Map<String, dynamic>;
      (traits['OnOff'] as Map<String, dynamic>)['onOff'] = true;
      (traits['MediaPlayback'] as Map<String, dynamic>)
        ..['state'] = 'playing'
        ..['playlist'] = 'Dinner jazz';

      expect(readings.of('dining_speaker')!['status'], 'Playing Dinner jazz');
    });
  });

  group('the thermostat', () {
    test('heats to its setpoint, which is its hero value', () {
      expect(readings.of('thermostat'), {
        'isActive': true,
        'status': 'Heating to 68 °F · now 67 °F',
        'value': '68',
      });
    });

    test('moves with the stepper', () {
      machine.execute('thermostat', DeviceCommand.up);

      expect(readings.of('thermostat')!['value'], '69');
      expect(
        readings.of('thermostat')!['status'],
        'Heating to 69 °F · now 67 °F',
      );
    });

    test('cools and turns off', () {
      final thermostat =
          (database.deviceOrNull('thermostat')!['traits']
                  as Map<String, dynamic>)['Thermostat']
              as Map<String, dynamic>;

      thermostat['mode'] = 'cool';
      expect(readings.of('thermostat')!['status'], startsWith('Cooling to'));

      thermostat['mode'] = 'off';
      expect(readings.of('thermostat')!['status'], 'Off · now 67 °F');
      expect(readings.of('thermostat')!['isActive'], isFalse);
    });
  });

  group('the front door', () {
    test('is locked, and then unlocked', () {
      expect(readings.of('front_door'), {
        'isActive': true,
        'status': 'Locked',
        'value': 'Locked',
      });

      machine.execute('front_door', DeviceCommand.unlock);

      expect(readings.of('front_door'), {
        'isActive': false,
        'status': 'Unlocked',
        'value': 'Unlocked',
      });
    });
  });

  group('the fridge', () {
    test('has no switch: it says its door and its temperature', () {
      expect(readings.of('fridge'), {
        'status': 'Door closed',
        'value': '37',
      });
    });

    test('says when the door is open', () {
      final traits =
          database.deviceOrNull('fridge')!['traits'] as Map<String, dynamic>;
      (traits['BooleanState'] as Map<String, dynamic>)['doorOpen'] = true;

      expect(readings.of('fridge')!['status'], 'Door open');
    });
  });

  test('a device with no traits has no readings', () {
    database.deviceOrNull('oven')!['traits'] = null;

    expect(readings.of('oven'), isNull);
  });
}
