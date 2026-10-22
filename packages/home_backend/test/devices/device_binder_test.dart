import 'dart:convert';

import 'package:home_backend/data/mock_database.dart';
import 'package:home_backend/devices/device_binder.dart';
import 'package:home_backend/devices/device_readings.dart';
import 'package:home_backend/scenario/scenario_world.dart';
import 'package:test/test.dart';

typedef _Json = Map<String, Object?>;

String _fence(_Json message) => '```json\n${jsonEncode(message)}\n```';

_Json _create() => {
  'version': 'v0.9',
  'createSurface': {'surfaceId': 's1', 'catalogId': 'cat'},
};

_Json _update(List<_Json> components, {String surfaceId = 's1'}) => {
  'version': 'v0.9',
  'updateComponents': {'surfaceId': surfaceId, 'components': components},
};

_Json _device(String id, [_Json props = const {}]) => {
  'id': 'card_$id',
  'component': 'DeviceCard',
  'deviceId': id,
  'name': id,
  'status': 'The model said this',
  'value': '1',
  'isActive': false,
  ...props,
};

List<_Json> _messages(String reply) => [
  for (final m in RegExp(r'```json\b(.*?)```', dotAll: true).allMatches(reply))
    jsonDecode(m.group(1)!) as _Json,
];

Map<String, _Json> _components(String reply) => {
  for (final message in _messages(reply))
    if (message['updateComponents'] case final _Json update)
      for (final c in (update['components']! as List).cast<_Json>())
        c['id']! as String: c,
};

void main() {
  late DeviceReadings readings;

  setUp(() async {
    final database = await MockDatabase.load();
    ScenarioWorld(database);
    readings = DeviceReadings(database);
  });

  group('bindDevices', () {
    test('binds the three values of a device to the data model', () {
      final reply = bindDevices(
        [
          _fence(_create()),
          _fence(_update([_device('oven')])),
        ].join('\n'),
        readings,
      );

      final card = _components(reply)['card_oven']!;
      expect(card['status'], {'path': '/devices/oven/status'});
      expect(card['value'], {'path': '/devices/oven/value'});
      expect(card['isActive'], {'path': '/devices/oven/isActive'});
      // What the model chose about the card stays as it was.
      expect(card['name'], 'oven');
      expect(card['deviceId'], 'oven');
    });

    test('seeds the data model with the readings, after the components', () {
      final reply = bindDevices(
        [
          _fence(_create()),
          _fence(_update([_device('oven')])),
        ].join('\n'),
        readings,
      );

      final messages = _messages(reply);
      expect(messages.map((m) => m.keys.last), [
        'createSurface',
        'updateComponents',
        'updateDataModel',
      ]);
      final seed = messages.last['updateDataModel']! as _Json;
      expect(messages.last['version'], 'v0.9');
      expect(seed['surfaceId'], 's1');
      expect(seed['path'], '/devices/oven');
      expect(seed['value'], readings.of('oven'));
    });

    test('leaves out a value the device has no reading for', () {
      final reply = bindDevices(
        _fence(_update([_device('fridge')])),
        readings,
      );

      final card = _components(reply)['card_fridge']!;
      expect(card['status'], {'path': '/devices/fridge/status'});
      // The fridge has no switch: the model's own `isActive` stays.
      expect(card['isActive'], isFalse);
    });

    test('binds every card of a screen and seeds each device once', () {
      final reply = bindDevices(
        _fence(
          _update([
            _device('oven'),
            _device('table_lights'),
            {..._device('oven'), 'id': 'another_oven'},
          ]),
        ),
        readings,
      );

      final seeds = [
        for (final m in _messages(reply))
          if (m['updateDataModel'] case final _Json seed)
            (seed['path']! as String),
      ];
      expect(seeds, ['/devices/oven', '/devices/table_lights']);
      expect(_components(reply)['another_oven']!['status'], {
        'path': '/devices/oven/status',
      });
    });

    test('leaves a device with no readings and other cards as they are', () {
      final other = {
        'id': 'trip',
        'component': 'TripCard',
        'deviceId': 'oven',
        'status': 'x',
      };
      final reply = _fence(
        _update([
          _device('doorbell'),
          _device('no_such_device'),
          other,
          {'id': 'x', 'component': 'DeviceCard'},
          {'id': 'y', 'component': 'DeviceCard', 'deviceId': 7},
        ]),
      );

      expect(bindDevices(reply, readings), same(reply));
    });

    test('puts the seeds after the last block of components', () {
      final reply = bindDevices(
        [
          _fence(_create()),
          _fence(_update([_device('oven')])),
          _fence(
            _update([
              {'id': 'late', 'component': 'ActionChips'},
            ]),
          ),
        ].join('\n'),
        readings,
      );

      expect(_messages(reply).map((m) => m.keys.last), [
        'createSurface',
        'updateComponents',
        'updateComponents',
        'updateDataModel',
      ]);
    });

    test('ignores what is not a message, and a reply with no components', () {
      const noise =
          '```json\n{oops\n```\n```json\n[1]\n```\n'
          '```json\n{"updateComponents": {"components": 3}}\n```\n'
          '```json\n'
          '{"updateComponents": {"components": [1, {"id": "a"}]}}\n'
          '```';

      expect(bindDevices('plain prose', readings), 'plain prose');
      expect(bindDevices(noise, readings), noise);
    });

    test('names the surface of the block that holds the cards', () {
      final reply = bindDevices(
        _fence(_update([_device('oven')], surfaceId: 'mine')),
        readings,
      );

      final seed = _messages(reply).last['updateDataModel']! as _Json;
      expect(seed['surfaceId'], 'mine');
    });
  });

  group('bindingDevices', () {
    test('binds what the model returns, for every call', () async {
      var calls = 0;
      final generate = bindingDevices((key, messages) async {
        calls++;
        return _fence(_update([_device('oven')]));
      }, readings);

      final first = await generate('key', const []);
      final second = await generate('key', const []);

      expect(calls, 2);
      expect(
        _components(first)['card_oven']!['status'],
        isA<Map<String, Object?>>(),
      );
      expect(
        _components(second)['card_oven']!['status'],
        isA<Map<String, Object?>>(),
      );
    });
  });
}
