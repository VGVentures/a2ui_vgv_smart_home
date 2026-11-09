import 'package:home_backend/data/mock_database.dart';
import 'package:home_timeline/home_timeline.dart';

/// The path of a device's values in the surface's data model, or of one value
/// of it.
String devicePath(String deviceId, [String? value]) =>
    '/devices/$deviceId${value == null ? '' : '/$value'}';

/// {@template device_readings}
/// What a `DeviceCard` shows of a device, worked out from the device's state.
/// {@endtemplate}
///
/// A card has three values that follow from the device alone: whether it is on
/// (`isActive`), its status line (`status`) and its hero reading (`value`).
/// This is the one place they are written, so the first screen and every
/// update after it say the same thing in the same words: the screen is bound
/// to these values (see `bindDevices`) and the backend sends the new ones as
/// the state changes, with no model run.
///
/// Only the devices the panel shows are known. A device with no reading leaves
/// out the value it has none for, and the card keeps whatever the model sent.
class DeviceReadings {
  /// {@macro device_readings}
  ///
  /// Creates the readings of the devices of the mock database.
  const DeviceReadings(this._database);

  final MockDatabase _database;

  /// The ids of the devices with readings.
  static const deviceIds = [
    'oven',
    'fridge',
    'table_lights',
    'dining_speaker',
    'thermostat',
    'front_door',
  ];

  /// Every known device's readings, by device id.
  Map<String, Map<String, Object?>> all() => {
    for (final id in deviceIds)
      if (of(id) case final readings?) id: readings,
  };

  /// The readings of [deviceId] now, or null for a device with none.
  Map<String, Object?>? of(String deviceId) {
    final traits = _database.deviceOrNull(deviceId)?['traits'];
    if (traits is! Map<String, dynamic>) return null;
    return switch (deviceId) {
      'oven' => _oven(traits),
      'fridge' => _fridge(traits),
      'table_lights' => _lights(traits),
      'dining_speaker' => _speaker(traits),
      'thermostat' => _thermostat(traits),
      'front_door' => _lock(traits),
      _ => null,
    };
  }

  Map<String, dynamic> _trait(Map<String, dynamic> traits, String name) =>
      traits[name] as Map<String, dynamic>? ?? const {};

  String _number(Object? value) => value is num ? '${value.round()}' : '';

  Map<String, Object?> _oven(Map<String, dynamic> traits) {
    final operational = _trait(traits, 'OperationalState');
    final control = _trait(traits, 'TemperatureControl');
    final state = operational['state'] as String? ?? 'stopped';
    final start = control['scheduledStart'] as String?;
    final status = state == 'stopped' && start != null
        // It is off until its programme starts: say when that is.
        ? 'Preheats at ${clock12(atHhmm(_database.clock.now, start))}'
        : operational['statusLabel'] as String? ?? 'Off';
    return {
      'isActive': state != 'stopped',
      'status': status,
      'value': _number(control['currentTemperatureF']),
    };
  }

  Map<String, Object?> _fridge(Map<String, dynamic> traits) {
    final open = _trait(traits, 'BooleanState')['doorOpen'] == true;
    return {
      'status': open ? 'Door open' : 'Door closed',
      'value': _number(
        _trait(traits, 'TemperatureMeasurement')['cabinetTemperatureF'],
      ),
    };
  }

  Map<String, Object?> _lights(Map<String, dynamic> traits) {
    final on = _trait(traits, 'OnOff')['onOff'] == true;
    final level = _number(_trait(traits, 'LevelControl')['currentLevel']);
    return {
      'isActive': on,
      'status': on ? 'On · $level%' : 'Off',
      'value': on ? level : '0',
    };
  }

  Map<String, Object?> _speaker(Map<String, dynamic> traits) {
    final on = _trait(traits, 'OnOff')['onOff'] == true;
    final playback = _trait(traits, 'MediaPlayback');
    final playlist = playback['playlist'] as String?;
    final status = !on
        ? 'Off'
        : playback['state'] == 'playing' && playlist != null
        ? 'Playing $playlist'
        : 'On';
    return {
      'isActive': on,
      'status': status,
      'value': _number(_trait(traits, 'LevelControl')['currentLevel']),
    };
  }

  Map<String, Object?> _thermostat(Map<String, dynamic> traits) {
    final thermostat = _trait(traits, 'Thermostat');
    final mode = thermostat['mode'] as String? ?? 'off';
    final setpoint = _number(thermostat['heatSetpointF']);
    final now = _number(thermostat['currentTemperatureF']);
    final status = switch (mode) {
      'heat' => 'Heating to $setpoint °F · now $now °F',
      'cool' => 'Cooling to $setpoint °F · now $now °F',
      _ => 'Off · now $now °F',
    };
    return {
      'isActive': mode != 'off',
      'status': status,
      // The hero is the setpoint: it is what a press on the stepper changes.
      'value': setpoint,
    };
  }

  Map<String, Object?> _lock(Map<String, dynamic> traits) {
    final locked = _trait(traits, 'DoorLock')['lockState'] == 'locked';
    final word = locked ? 'Locked' : 'Unlocked';
    return {'isActive': locked, 'status': word, 'value': word};
  }
}
