import 'package:home_backend/data/mock_database.dart';
import 'package:home_backend/devices/device_command.dart';
import 'package:home_backend/devices/device_state_machine.dart';
import 'package:home_backend/live/live_hub.dart';
import 'package:home_backend/scenario/scenario_world.dart';
import 'package:test/test.dart';

typedef _Json = Map<String, Object?>;

void main() {
  late MockDatabase database;
  late List<_Json> frames;
  late ScenarioWorld world;
  late DeviceStateMachine machine;

  /// The data model updates sent so far, as `path: value`.
  Map<String, Object?> updates() => {
    for (final frame in frames)
      if (frame['type'] == 'a2ui')
        ((frame['message']! as _Json)['updateDataModel']! as _Json)['path']!
                as String:
            ((frame['message']! as _Json)['updateDataModel']!
                as _Json)['value'],
  };

  setUp(() async {
    database = await MockDatabase.load();
    final hub = LiveHub();
    frames = [];
    world = ScenarioWorld(database, live: hub);
    // The world already read the devices once, before anyone listened. A
    // client that connects later is seeded by the reply it builds its screen
    // from, so only what changes from here on is sent.
    hub.listen(frames.add);
    machine = DeviceStateMachine(database, onChanged: world.reconcile);
  });

  test('sends nothing while nothing moves', () {
    world.reconcile();

    expect(frames.where((f) => f['type'] == 'a2ui'), isEmpty);
  });

  test('sends the new values of a device a command changed', () {
    machine.execute('table_lights', DeviceCommand.off);

    final message =
        frames.singleWhere((f) => f['type'] == 'a2ui')['message']! as _Json;
    expect(message['version'], 'v0.9');
    final update = message['updateDataModel']! as _Json;
    expect(update['surfaceId'], 'dashboard');
    expect(update['path'], '/devices/table_lights');
    expect(update['value'], {
      'isActive': false,
      'status': 'Off',
      'value': '0',
    });
  });

  test('sends only the device that moved, once', () {
    machine
      ..execute('table_lights', DeviceCommand.off)
      ..execute('table_lights', DeviceCommand.off);

    expect(updates().keys, ['/devices/table_lights']);
    expect(frames.where((f) => f['type'] == 'a2ui'), hasLength(1));
  });

  test('sends the oven as the clock moves it', () {
    machine.execute('oven', DeviceCommand.start);
    frames.clear();

    world.moveTo(database.clock.now.add(const Duration(minutes: 20)));

    final oven = updates()['/devices/oven']! as _Json;
    expect(oven['status'], startsWith('Ready'));
    expect(oven['value'], '400');
  });

  test('sends the first values again when the demo starts over', () {
    machine.execute('table_lights', DeviceCommand.off);
    frames.clear();

    world.reset();

    expect(updates()['/devices/table_lights'], {
      'isActive': true,
      'status': 'On · 100%',
      'value': '100',
    });
  });

  test('says nothing without a live connection', () async {
    final quiet = ScenarioWorld(await MockDatabase.load());

    expect(quiet.reconcile, returnsNormally);
  });
}
