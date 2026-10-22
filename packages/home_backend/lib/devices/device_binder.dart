import 'dart:convert';

import 'package:home_backend/devices/device_readings.dart';
import 'package:home_backend/llm/llm.dart';
import 'package:home_catalog/home_catalog.dart' show a2uiVersion;

/// Binds the device cards of [reply] to the data model.
///
/// The model writes each `DeviceCard` with literal values read from the device
/// data. For a device with [readings], this replaces the three values that
/// follow from the device alone (`isActive`, `status`, `value`) with a binding
/// to `/devices/<id>/<value>`, and adds the `updateDataModel` that seeds them.
/// The values are the readings' own, so what the card says first and what it
/// says after each update are written in one place.
///
/// This is how the surface is updated in place without asking the model again:
/// the backend moves the values in the data model as the device changes, as an
/// A2UI agent does, and only the widgets bound to them rebuild.
///
/// A reply with no such card is returned as it is.
String bindDevices(String reply, DeviceReadings readings) {
  final fence = RegExp(r'```json\b(.*?)```', dotAll: true);
  final messages = <Map<String, Object?>>[];
  for (final match in fence.allMatches(reply)) {
    try {
      final decoded = jsonDecode(match.group(1)!);
      if (decoded is Map<String, Object?>) messages.add(decoded);
    } on FormatException {
      continue;
    }
  }

  final seeds = <String, Map<String, Object?>>{};
  String? surfaceId;
  var lastUpdate = -1;
  for (final (index, message) in messages.indexed) {
    final update = message['updateComponents'];
    if (update is! Map<String, Object?>) continue;
    final components = update['components'];
    if (components is! List) continue;
    surfaceId = update['surfaceId'] as String? ?? surfaceId;
    lastUpdate = index;
    for (final component in components) {
      if (component is! Map<String, Object?>) continue;
      if (component['component'] != 'DeviceCard') continue;
      final id = component['deviceId'];
      final values = id is String ? readings.of(id) : null;
      if (id is! String || values == null) continue;
      seeds[id] = values;
      for (final name in values.keys) {
        component[name] = {'path': devicePath(id, name)};
      }
    }
  }
  if (seeds.isEmpty) return reply;

  return [
    for (final (index, message) in messages.indexed) ...[
      _fence(message),
      if (index == lastUpdate)
        for (final MapEntry(:key, :value) in seeds.entries)
          _fence({
            'version': a2uiVersion,
            'updateDataModel': {
              'surfaceId': surfaceId,
              'path': devicePath(key),
              'value': value,
            },
          }),
    ],
  ].join('\n');
}

String _fence(Map<String, Object?> message) =>
    '```json\n${jsonEncode(message)}\n```';

/// [inner], with the device cards of what it returns bound to the data model.
///
/// Wrapped around one visitor's `Generate`, so the readings are those of that
/// visitor's own home.
Generate bindingDevices(Generate inner, DeviceReadings readings) {
  return (apiKey, messages) async =>
      bindDevices(await inner(apiKey, messages), readings);
}
