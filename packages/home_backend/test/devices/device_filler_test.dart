import 'dart:convert';

import 'package:genkit/genkit.dart' show Message, Role, TextPart;
import 'package:home_backend/data/mock_database.dart';
import 'package:home_backend/devices/device_filler.dart';
import 'package:home_backend/devices/device_readings.dart';
import 'package:home_backend/scenario/scenario_world.dart';
import 'package:home_backend/validation/layout_composer.dart';
import 'package:home_backend/validation/layout_validator.dart';
import 'package:home_catalog/home_catalog.dart';
import 'package:test/test.dart';

typedef _Json = Map<String, Object?>;

String _fence(_Json message) => '```json\n${jsonEncode(message)}\n```';

String _reply(List<_Json> components) => [
  _fence({
    'version': 'v0.9',
    'createSurface': {'surfaceId': 's', 'catalogId': homeCatalog.id},
  }),
  _fence({
    'version': 'v0.9',
    'updateComponents': {'surfaceId': 's', 'components': components},
  }),
].join('\n');

_Json _c(String id, String type, [_Json props = const {}]) => {
  'id': id,
  'component': type,
  ...props,
};

Map<String, _Json> _components(String reply) => {
  for (final m in RegExp(r'```json\b(.*?)```', dotAll: true).allMatches(reply))
    if ((jsonDecode(m.group(1)!) as _Json)['updateComponents']
        case final _Json update)
      for (final c in (update['components']! as List).cast<_Json>())
        c['id']! as String: c,
};

Message _user(String text) => Message(
  role: Role.user,
  content: [TextPart(text: text)],
);

void main() {
  late MockDatabase database;
  late DeviceFiller filler;

  setUp(() async {
    database = await MockDatabase.load();
    ScenarioWorld(database);
    filler = DeviceFiller(database, DeviceReadings(database));
  });

  group('DeviceFiller', () {
    List<String> ids(Iterable<_Json> cards) => [
      for (final c in cards) c['deviceId']! as String,
    ];

    test('offers the devices that are not on the screen yet', () {
      final cards = filler.cards({'oven', 'fridge'});

      expect(
        ids(cards),
        unorderedEquals([
          'table_lights',
          'dining_speaker',
          'thermostat',
          'front_door',
        ]),
      );
    });

    test('puts the devices the person uses first', () {
      expect(ids(filler.cards(const {}, userId: 'marco')).take(2), [
        'thermostat',
        'front_door',
      ]);
      expect(ids(filler.cards(const {}, userId: 'ana')).first, 'oven');
    });

    test('keeps the order of the home when it does not know who it is for', () {
      expect(ids(filler.cards(const {})), DeviceReadings.deviceIds);
    });

    test('writes a card the model could have written, with the readings', () {
      final thermostat = filler
          .cards(const {})
          .singleWhere((c) => c['deviceId'] == 'thermostat');

      expect(thermostat, {
        'id': 'fill_thermostat',
        'component': 'DeviceCard',
        'deviceId': 'thermostat',
        'name': 'Thermostat',
        'room': 'Living room',
        'icon': 'thermostat',
        'tone': 'climate',
        'unit': '°F',
        'control': {'type': 'stepper'},
        'isActive': true,
        'status': 'Heating to 68 °F · now 67 °F',
        'value': '68',
      });
    });

    test('gives each device the control and unit that fit it', () {
      final byId = {
        for (final c in filler.cards(const {})) c['deviceId']! as String: c,
      };

      expect((byId['fridge']!['control']! as _Json)['type'], 'none');
      expect((byId['front_door']!['control']! as _Json)['type'], 'toggle');
      expect(byId['front_door']!.containsKey('unit'), isFalse);
      expect(byId['table_lights']!['unit'], '%');
    });

    test('has nothing to offer when every device is shown', () {
      expect(filler.cards(DeviceReadings.deviceIds.toSet()), isEmpty);
    });

    test('has no card for a device the home does not have', () {
      database.homeDevices.removeWhere((d) => d['id'] == 'thermostat');

      expect(ids(filler.cards(const {})), isNot(contains('thermostat')));
    });
  });

  group('LayoutComposer with cards to fill the grid', () {
    final composer = LayoutComposer(homeCatalog);
    final validator = LayoutValidator(homeCatalog);

    // Marco's screen as the model sends it: a trip, the car and two devices.
    List<_Json> marco() => [
      _c('root', 'Column', {
        'children': ['row', 'chips'],
      }),
      _c('row', 'Row', {
        'children': ['trip', 'charge', 'a', 'b'],
      }),
      _c('trip', 'TripCard', {'leaveBy': '5:00 PM'}),
      _c('charge', 'ChargeCard', {'percent': 80}),
      _c('a', 'DeviceCard', {'deviceId': 'thermostat'}),
      _c('b', 'DeviceCard', {'deviceId': 'front_door'}),
      _c('chips', 'ActionChips', {'chips': <Object?>[]}),
    ];

    test('keeps the trip and adds a device to fill the second row', () {
      final reply = composer.compose(
        _reply(marco()),
        fill: (shown) => filler.cards(shown, userId: 'marco'),
      )!;

      final byId = _components(reply);
      expect(validator.validate(reply), isNull);
      for (final id in ['trip', 'charge', 'a', 'b']) {
        expect(byId.containsKey(id), isTrue, reason: id);
      }
      // One device was added, a third for the row, and it is not one on screen.
      final fills = byId.keys.where((id) => id.startsWith('fill_')).toList();
      expect(fills, hasLength(1));
      expect(
        byId[fills.single]!['deviceId'],
        isNot(anyOf('thermostat', 'front_door')),
      );
    });

    test('asks for cards with the devices already on the screen', () {
      Set<String>? asked;
      composer.compose(
        _reply(marco()),
        fill: (shown) {
          asked = shown;
          return const [];
        },
      );

      expect(asked, {'thermostat', 'front_door'});
    });

    test('adds nothing when the cards of the model already fill the grid', () {
      var asked = 0;
      final reply = composer.compose(
        _reply([
          _c('root', 'Column', {
            'children': ['r1', 'r2', 'chips'],
          }),
          _c('r1', 'Row', {
            'children': ['trip', 'charge'],
          }),
          _c('r2', 'Row', {
            'children': ['a', 'b', 'c'],
          }),
          _c('trip', 'TripCard'),
          _c('charge', 'ChargeCard'),
          for (final id in ['a', 'b', 'c'])
            _c(id, 'DeviceCard', {'deviceId': id}),
          _c('chips', 'ActionChips', {'chips': <Object?>[]}),
        ]),
        fill: (shown) {
          asked++;
          return filler.cards(shown);
        },
      )!;

      expect(asked, 1);
      expect(
        _components(reply).keys.where((id) => id.startsWith('fill_')),
        isEmpty,
      );
    });

    test('never gives up a card of the model for a card to fill', () {
      // A trip alone cannot fill a row of 12, and no device can sit in a row
      // with a trip but a 5: the trip stays and a device pairs with it.
      final reply = composer.compose(
        _reply([
          _c('root', 'Column', {
            'children': ['row', 'chips'],
          }),
          _c('row', 'Row', {
            'children': ['trip'],
          }),
          _c('trip', 'TripCard'),
          _c('chips', 'ActionChips', {'chips': <Object?>[]}),
        ]),
        fill: (shown) => filler.cards(shown, userId: 'marco'),
      )!;

      final byId = _components(reply);
      expect(byId['trip']!['weight'], 7);
      expect(validator.validate(reply), isNull);
    });

    test('leaves a row short when there is nothing to fill it with', () {
      final reply = composer.compose(
        _reply(marco()),
        fill: (_) => const [],
      )!;

      final byId = _components(reply);
      // Without devices to add, the four cards of the model cannot fill two
      // rows, so the grid keeps what holds the most of them in rank order.
      expect(byId['trip'], isNotNull);
      expect(byId['root']!['children'], isNotEmpty);
    });

    test('leaves the lead cards in the top row', () {
      final reply = composer.compose(
        _reply([
          _c('root', 'Column', {
            'children': ['row', 'chips'],
          }),
          _c('row', 'Row', {
            'children': ['a', 'b', 'c', 'alert', 'd'],
          }),
          for (final id in ['a', 'b', 'c', 'd'])
            _c(id, 'DeviceCard', {'deviceId': id}),
          _c('alert', 'HeadsUpCard', {'title': 'Rain'}),
          _c('chips', 'ActionChips', {'chips': <Object?>[]}),
        ]),
        fill: (shown) => filler.cards(shown),
      )!;

      final byId = _components(reply);
      expect(byId['grid_row_1']!['children'], contains('alert'));
      expect(byId['grid_row_2']!['children'], isNot(contains('alert')));
      expect(validator.validate(reply), isNull);
    });
  });

  group('composingScreens', () {
    final composer = LayoutComposer(homeCatalog);

    List<_Json> marco() => [
      _c('root', 'Column', {
        'children': ['row', 'chips'],
      }),
      _c('row', 'Row', {
        'children': ['trip', 'charge', 'a', 'b'],
      }),
      _c('trip', 'TripCard', {'leaveBy': '5:00 PM'}),
      _c('charge', 'ChargeCard', {'percent': 80}),
      _c('a', 'DeviceCard', {'deviceId': 'thermostat'}),
      _c('b', 'DeviceCard', {'deviceId': 'front_door'}),
      _c('chips', 'ActionChips', {'chips': <Object?>[]}),
    ];

    test(
      'lays out and fills the screen of the person in the conversation',
      () async {
        final generate = composingScreens(
          (key, messages) async => _reply(marco()),
          composer,
          filler,
        );

        final reply = await generate('key', [
          _user(
            'Build the home dashboard for Marco (user_id "marco", logistics).',
          ),
        ]);

        expect(LayoutValidator(homeCatalog).validate(reply), isNull);
        // For Marco the first device to add is one of his own, but the two he
        // uses are already there, so it is the next of the home.
        final fills = _components(
          reply,
        ).keys.where((id) => id.startsWith('fill_'));
        expect(fills, isNotEmpty);
      },
    );

    test('returns a reply with no screen in it as it is', () async {
      final generate = composingScreens(
        (key, messages) async => 'plain prose',
        composer,
        filler,
      );

      expect(await generate('key', [_user('hi')]), 'plain prose');
    });
  });

  group('userIdOf', () {
    test('reads the person the dashboard prompt names', () {
      expect(
        userIdOf(['Build the dashboard (user_id "ana", host)', 'x']),
        'ana',
      );
    });

    test('looks through the whole conversation', () {
      expect(
        userIdOf(['{"action": {}}', 'Build it for (user_id "marco")']),
        'marco',
      );
    });

    test('is null when nothing names a person', () {
      expect(userIdOf(['hello', 'again']), isNull);
      expect(userIdOf(const []), isNull);
    });
  });
}
