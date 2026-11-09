import 'package:home_backend/data/mock_database.dart';
import 'package:home_backend/devices/device_readings.dart';

/// {@template device_filler}
/// `DeviceCard`s for the devices a screen does not show yet, to fill the cells
/// the model's own cards leave empty.
/// {@endtemplate}
///
/// A person's screen is a handful of cards they need, and the grid is bigger
/// than that: with a trip, a car and two devices there is no way to fill two
/// rows. The cards the model chose always stay. These are only what is added
/// after them, as few as the grid needs, so a screen is never left with an
/// empty row. They are the cards the Figma screens fill with: a device and its
/// control.
///
/// The devices the person uses come first, as the device data says, then the
/// rest of the home. Their values are those of `DeviceReadings`, so they are
/// bound to the data model like any card the model wrote.
class DeviceFiller {
  /// {@macro device_filler}
  ///
  /// Creates a filler over the devices of the mock database.
  DeviceFiller(this._database, this._readings);

  final MockDatabase _database;
  final DeviceReadings _readings;

  static const _icons = {
    'oven': 'oven',
    'fridge': 'fridge',
    'table_lights': 'light',
    'dining_speaker': 'speaker',
    'thermostat': 'thermostat',
    'front_door': 'lock',
  };

  static const _tones = {
    'oven': 'neutral',
    'fridge': 'neutral',
    'table_lights': 'lighting',
    'dining_speaker': 'neutral',
    'thermostat': 'climate',
    'front_door': 'security',
  };

  static const _units = {
    'oven': '°F',
    'fridge': '°F',
    'table_lights': '%',
    'dining_speaker': '%',
    'thermostat': '°F',
  };

  /// The cards to add, best first, for devices not in [shown].
  ///
  /// [userId], when it is known, puts the devices that person uses first.
  List<Map<String, Object?>> cards(Set<String> shown, {String? userId}) {
    final candidates = [
      for (final id in DeviceReadings.deviceIds)
        if (!shown.contains(id) && _database.deviceOrNull(id) != null) id,
    ];
    bool uses(String id) {
      final usedBy = _database.deviceOrNull(id)!['usedBy'];
      return userId != null && usedBy is List && usedBy.contains(userId);
    }

    return [
      for (final id in [
        ...candidates.where(uses),
        ...candidates.where((id) => !uses(id)),
      ])
        _card(id),
    ];
  }

  Map<String, Object?> _card(String id) {
    final device = _database.deviceOrNull(id)!;
    final readings = _readings.of(id)!;
    final room = (device['room'] as String? ?? '').replaceAll('_', ' ');
    return {
      'id': 'fill_$id',
      'component': 'DeviceCard',
      'deviceId': id,
      'name': device['name'],
      if (room.isNotEmpty) 'room': room[0].toUpperCase() + room.substring(1),
      'icon': _icons[id],
      'tone': _tones[id],
      'unit': ?_units[id],
      'control': {'type': _control(id)},
      ...readings,
    };
  }

  /// What a device's card lets a person do: raise it, switch it, or nothing.
  String _control(String id) => switch (id) {
    'thermostat' => 'stepper',
    'fridge' => 'none',
    _ => 'toggle',
  };
}

/// The person a conversation is about: the `user_id` the dashboard prompt
/// names, or null when no message does.
String? userIdOf(Iterable<String> texts) {
  final match = RegExp('user_id "([^"]+)"');
  for (final text in texts) {
    final found = match.firstMatch(text)?.group(1);
    if (found != null) return found;
  }
  return null;
}
