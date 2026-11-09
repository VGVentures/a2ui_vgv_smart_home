import 'dart:convert';
import 'dart:io';

import 'package:dart_frog/dart_frog.dart';
import 'package:home_backend/data/mock_database.dart';
import 'package:home_backend/scenario/scenario_world.dart';
import 'package:mocktail/mocktail.dart';
import 'package:test/test.dart';

import '../../routes/clock.dart' as route;

class _MockRequestContext extends Mock implements RequestContext {}

void main() {
  late ScenarioWorld world;

  setUp(() async {
    world = ScenarioWorld(await MockDatabase.load());
  });

  RequestContext contextFor(HttpMethod method, {Object? body}) {
    final context = _MockRequestContext();
    when(() => context.request).thenReturn(
      Request(
        method.value,
        Uri.parse('http://localhost/clock'),
        body: body == null ? null : jsonEncode(body),
      ),
    );
    when(() => context.read<ScenarioWorld>()).thenReturn(world);
    return context;
  }

  Future<Map<String, dynamic>> answer(Response response) async =>
      jsonDecode(await response.body()) as Map<String, dynamic>;

  group('/clock', () {
    test('GET answers the scenario clock', () async {
      final response = await route.onRequest(contextFor(HttpMethod.get));

      expect(response.statusCode, HttpStatus.ok);
      expect(await answer(response), {
        'now': '2026-10-10T07:30:00',
        'start': '2026-10-10T07:30:00',
        'end': '2026-10-10T23:59:00',
        'timeZone': 'America/Chicago',
      });
    });

    test('POST minutes moves the clock forward and reconciles', () async {
      final response = await route.onRequest(
        contextFor(HttpMethod.post, body: {'minutes': 75}),
      );

      expect((await answer(response))['now'], '2026-10-10T08:45:00');
      final oven =
          (world.database.deviceOrNull('oven')!['traits']
                  as Map<String, dynamic>)['OperationalState']
              as Map<String, dynamic>;
      expect(oven['state'], 'stopped');
    });

    test('POST minutes can go back, but not before the start', () async {
      await route.onRequest(contextFor(HttpMethod.post, body: {'minutes': 30}));
      final response = await route.onRequest(
        contextFor(HttpMethod.post, body: {'minutes': -60}),
      );

      expect((await answer(response))['now'], '2026-10-10T07:30:00');
    });

    test('POST to sets the clock to a time', () async {
      final response = await route.onRequest(
        contextFor(HttpMethod.post, body: {'to': '2026-10-10T18:42:00'}),
      );

      expect((await answer(response))['now'], '2026-10-10T18:42:00');
      expect(world.database.clock.nowIso, '2026-10-10T18:42:00');
    });

    test('POST with both, neither or nonsense is a 400', () async {
      for (final body in <Object?>[
        {'to': '2026-10-10T18:00:00', 'minutes': 5},
        <String, Object?>{},
        {'to': 'noon'},
        {'minutes': 'soon'},
        'text',
      ]) {
        final response = await route.onRequest(
          contextFor(HttpMethod.post, body: body),
        );

        expect(response.statusCode, HttpStatus.badRequest, reason: '$body');
      }
      expect(world.database.clock.nowIso, '2026-10-10T07:30:00');
    });

    test('other methods are a 405', () async {
      final response = await route.onRequest(contextFor(HttpMethod.delete));

      expect(response.statusCode, HttpStatus.methodNotAllowed);
    });
  });
}
