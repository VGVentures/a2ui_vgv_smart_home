import 'package:home_backend/data/mock_database.dart';
import 'package:home_backend/devices/device_binder.dart';
import 'package:home_backend/devices/device_readings.dart';
import 'package:home_backend/scenario/scenario_world.dart';
import 'package:test/test.dart';

typedef _Json = Map<String, Object?>;

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

_Json _byId(List<_Json> components, String id) =>
    components.firstWhere((c) => c['id'] == id);

void main() {
  late DeviceReadings readings;

  setUp(() async {
    final database = await MockDatabase.load();
    ScenarioWorld(database);
    readings = DeviceReadings(database);
  });

  group('bindDevices', () {
    test('binds the three values of a device to the data model', () {
      final bound = bindDevices([_device('oven')], readings);

      final card = _byId(bound.components, 'card_oven');
      expect(card['isActive'], {'@path': '/devices/oven/isActive'});
      expect(card['status'], {'@path': '/devices/oven/status'});
      expect(card['value'], {'@path': '/devices/oven/value'});
      expect(card['name'], 'oven');
    });

    test('seeds the bindings with the values of the readings', () {
      final bound = bindDevices([_device('oven')], readings);

      expect(bound.seeds, {'oven': readings.of('oven')});
    });

    test('binds only the values a device has readings for', () {
      final bound = bindDevices([_device('fridge')], readings);

      final card = _byId(bound.components, 'card_fridge');
      expect(card['status'], {'@path': '/devices/fridge/status'});
      expect(card['value'], {'@path': '/devices/fridge/value'});
      expect(card['isActive'], false);
    });

    test('binds every card, a device once in the seeds', () {
      final bound = bindDevices(
        [
          _device('oven'),
          _device('table_lights'),
          _device('oven', {'id': 'again'}),
        ],
        readings,
      );

      expect(bound.seeds.keys, ['oven', 'table_lights']);
      expect(
        _byId(bound.components, 'again')['status'],
        isA<Map<String, Object?>>(),
      );
    });

    test('keeps a card of a device with no readings as the model wrote it', () {
      final unknown = _device('toaster');
      final bound = bindDevices([unknown], readings);

      expect(bound.components, [unknown]);
      expect(bound.seeds, isEmpty);
    });

    test('keeps what is not a device card', () {
      final trip = {'id': 'trip', 'component': 'TripCard', 'deviceId': 'oven'};
      final noId = {'id': 'bare', 'component': 'DeviceCard'};
      final bound = bindDevices([trip, noId], readings);

      expect(bound.components, [trip, noId]);
      expect(bound.seeds, isEmpty);
    });

    test('leaves the components it was given as they were', () {
      final card = _device('oven');
      bindDevices([card], readings);

      expect(card['status'], 'The model said this');
    });
  });
}
