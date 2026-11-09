import 'package:home_backend/devices/device_readings.dart';

/// The components of a screen with its device cards bound to the data model,
/// and the values that seed the bindings.
typedef BoundDevices = ({
  List<Map<String, Object?>> components,
  Map<String, Map<String, Object?>> seeds,
});

/// Binds the device cards of [components] to the data model.
///
/// The model writes each `DeviceCard` with literal values read from the device
/// data. For a device with [readings], this replaces the three values that
/// follow from the device alone (`isActive`, `status`, `value`) with a binding
/// to `/devices/<id>/<value>`, and returns the values that seed them, by device
/// id. The values are the readings' own, so what the card says first and what
/// it says after each update are written in one place.
///
/// This is how the surface is updated in place without asking the model again:
/// the backend moves the values in the data model as the device changes, as an
/// A2UI agent does, and only the widgets bound to them rebuild. A card of a
/// device with no readings keeps what the model wrote, and the press on it
/// answers `404` as for any unknown id.
///
/// [components] is left as it is: the bound cards are copies.
BoundDevices bindDevices(
  List<Map<String, Object?>> components,
  DeviceReadings readings,
) {
  final seeds = <String, Map<String, Object?>>{};
  final bound = <Map<String, Object?>>[];
  for (final component in components) {
    final id = component['deviceId'];
    final values = component['component'] == 'DeviceCard' && id is String
        ? readings.of(id)
        : null;
    if (id is! String || values == null) {
      bound.add(component);
      continue;
    }
    seeds[id] = values;
    bound.add({
      ...component,
      for (final name in values.keys) name: {'@path': devicePath(id, name)},
    });
  }
  return (components: bound, seeds: seeds);
}
