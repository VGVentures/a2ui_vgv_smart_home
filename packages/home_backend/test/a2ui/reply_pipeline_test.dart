import 'package:home_backend/a2ui/reply_outcome.dart';
import 'package:home_backend/a2ui/reply_pipeline.dart';
import 'package:home_backend/data/mock_database.dart';
import 'package:home_backend/devices/device_readings.dart';
import 'package:home_backend/scenario/scenario_world.dart';
import 'package:test/test.dart';

import '../helpers/pipeline.dart';
import '../helpers/replies.dart';

Json _body(Json message, String key) => message[key]! as Json;

List<Json> _components(Json message) =>
    (_body(
              message,
              message.containsKey('createSurface')
                  ? 'createSurface'
                  : 'updateComponents',
            )['components']!
            as List)
        .cast<Json>();

void main() {
  late MockDatabase database;
  late ReplyPipeline pipeline;

  setUp(() async {
    database = await MockDatabase.load();
    ScenarioWorld(database);
    pipeline = buildPipeline(database);
  });

  group(ReplyOutcome, () {
    test('an accepted outcome carries messages and no errors', () {
      const outcome = ReplyOutcome.accepted([
        {'a': 1},
      ]);

      expect(outcome.isAccepted, isTrue);
      expect(outcome.errors, isEmpty);
      expect(outcome.messages, hasLength(1));
    });

    test('a rejected outcome carries errors and no messages', () {
      const outcome = ReplyOutcome.rejected(['bad']);

      expect(outcome.isAccepted, isFalse);
      expect(outcome.messages, isEmpty);
    });
  });

  group('ReplyPipeline for a surface the panel does not show', () {
    ReplyOutcome run(String reply, {String? userId}) =>
        pipeline.process(reply, surfaceExists: false, userId: userId);

    test('returns one createSurface with the whole dashboard', () {
      final outcome = run(createReply());

      expect(outcome.isAccepted, isTrue, reason: '${outcome.errors}');
      final message = outcome.messages.single;
      expect(message['version'], '1.0');
      final create = _body(message, 'createSurface');
      expect(create['surfaceId'], 'dashboard');
      expect(create['catalogId'], 'verygood.ventures/catalogs/home/v1');
      expect(create['sendDataModel'], isTrue);
    });

    test('addresses the dashboard surface whatever id the model chose', () {
      final outcome = run(createReply(surfaceId: 'my_surface'));

      expect(outcome.isAccepted, isTrue, reason: '${outcome.errors}');
      expect(
        _body(outcome.messages.single, 'createSurface')['surfaceId'],
        'dashboard',
      );
    });

    test(
      'binds the device cards and seeds the data model with the readings',
      () {
        final outcome = run(createReply());

        final create = _body(outcome.messages.single, 'createSurface');
        final oven = _components(outcome.messages.single).firstWhere(
          (c) => c['deviceId'] == 'oven',
        );
        expect(oven['status'], {'@path': '/devices/oven/status'});
        expect(
          (create['dataModel']! as Json)['devices'],
          containsPair('oven', DeviceReadings(database).of('oven')),
        );
      },
    );

    test('lays the cards out on the grid and fills the empty cells', () {
      final outcome = run(createReply());

      final components = _components(outcome.messages.single);
      final fills = components.where(
        (c) => '${c['id']}'.startsWith('fill_'),
      );
      expect(fills, isNotEmpty);
      expect(
        components.firstWhere((c) => c['id'] == 'root')['children'],
        ['grid_row_1', 'grid_row_2', 'chips'],
      );
    });

    test('fills with the devices of the person the screen is for first', () {
      List<Object?> fills(ReplyOutcome outcome) => [
        for (final c in _components(outcome.messages.single))
          if ('${c['id']}'.startsWith('fill_')) c['deviceId'],
      ];

      final forMarco = fills(run(createReply(), userId: 'marco'));

      expect(forMarco, isNotEmpty);
      final usedBy =
          database.deviceOrNull('${forMarco.first}')!['usedBy'] as List?;
      expect(usedBy, contains('marco'));
    });

    test('rejects a reply with no A2UI in it', () {
      final outcome = run('Sorry, I cannot help with that.');

      expect(outcome.isAccepted, isFalse);
      expect(outcome.errors.single, contains('no A2UI message'));
    });

    test('rejects an unknown component, naming it', () {
      final outcome = run(
        createReply(
          components: [
            {
              'id': 'root',
              'component': 'Column',
              'children': ['x'],
            },
            {'id': 'x', 'component': 'Carousel'},
          ],
        ),
      );

      expect(outcome.isAccepted, isFalse);
      expect(outcome.errors.join(), contains('Carousel'));
    });

    test('rejects a child id that is not defined', () {
      final outcome = run(
        createReply(
          components: [
            {
              'id': 'root',
              'component': 'Column',
              'children': ['ghost'],
            },
          ],
        ),
      );

      expect(outcome.isAccepted, isFalse);
      expect(outcome.errors.join(), contains('ghost'));
    });

    test('rejects JSON that is not valid A2UI', () {
      final outcome = run('<a2ui-json>{not json</a2ui-json>');

      expect(outcome.isAccepted, isFalse);
      expect(outcome.errors, isNotEmpty);
    });

    test('rejects a screen that is off the grid and cannot be mended', () {
      final outcome = run(
        createReply(
          components: [
            {
              'id': 'root',
              'component': 'Column',
              'children': ['chips'],
            },
            dashboardComponents().last,
          ],
        ),
      );

      expect(outcome.isAccepted, isFalse);
      expect(outcome.errors.join(), contains('no `Row` of cards'));
    });

    test('keeps a card of a device with no readings as it was written', () {
      final base = dashboardComponents();
      final outcome = run(
        createReply(
          components: [
            for (final c in base)
              if (c['id'] == 'row1')
                {
                  ...c,
                  'children': [...(c['children']! as List), 'card_toaster'],
                }
              else
                c,
            {
              'id': 'card_toaster',
              'component': 'DeviceCard',
              'deviceId': 'toaster',
              'name': 'Toaster',
              'status': 'Off',
              'weight': 4,
            },
          ],
        ),
      );

      expect(outcome.isAccepted, isTrue, reason: '${outcome.errors}');
      final toaster = _components(
        outcome.messages.single,
      ).firstWhere((c) => c['deviceId'] == 'toaster');
      expect(toaster['status'], 'Off');
      final create = _body(outcome.messages.single, 'createSurface');
      expect(
        (create['dataModel']! as Json)['devices'],
        isNot(contains('toaster')),
      );
    });
  });

  group('ReplyPipeline for a surface the panel already shows', () {
    ReplyOutcome run(String reply) =>
        pipeline.process(reply, surfaceExists: true);

    test('returns the device values, then the components of the dashboard', () {
      final outcome = run(updateReply());

      expect(outcome.isAccepted, isTrue, reason: '${outcome.errors}');
      final messages = outcome.messages;
      expect(messages.last, contains('updateComponents'));
      expect(
        _body(messages.last, 'updateComponents')['surfaceId'],
        'dashboard',
      );
      final updates = messages.take(messages.length - 1).toList();
      expect(updates, isNotEmpty);
      for (final message in updates) {
        final update = _body(message, 'updateDataModel');
        expect(update['surfaceId'], 'dashboard');
        expect('${update['path']}', startsWith('/devices/'));
      }
    });

    test('seeds the devices the composer adds to the screen', () {
      final outcome = run(
        updateReply(
          components: [
            {
              'id': 'root',
              'component': 'Column',
              'children': ['row1', 'chips'],
            },
            {
              'id': 'row1',
              'component': 'Row',
              'children': ['a', 'b', 'c'],
            },
            for (final id in ['a', 'b', 'c'])
              {
                'id': id,
                'component': 'DeviceCard',
                'deviceId': 'toaster',
                'name': id,
                'status': 'Off',
                'weight': 4,
              },
            dashboardComponents().last,
          ],
        ),
      );

      expect(outcome.isAccepted, isTrue, reason: '${outcome.errors}');
      expect(
        outcome.messages.where((m) => m.containsKey('updateDataModel')),
        isNotEmpty,
      );
    });

    test('rejects a createSurface for the surface that exists', () {
      final outcome = run(createReply());

      expect(outcome.isAccepted, isFalse);
      expect(outcome.errors.join(), contains('dashboard'));
    });
  });
}
