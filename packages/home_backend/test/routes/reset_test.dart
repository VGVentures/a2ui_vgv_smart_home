import 'dart:convert';
import 'dart:io';

import 'package:dart_frog/dart_frog.dart';
import 'package:home_backend/data/mock_database.dart';
import 'package:home_backend/devices/device_state_machine.dart';
import 'package:home_backend/scenario/scenario_world.dart';
import 'package:mocktail/mocktail.dart';
import 'package:test/test.dart';

import '../../routes/reset.dart' as route;

class _MockRequestContext extends Mock implements RequestContext {}

void main() {
  late MockDatabase database;
  late ScenarioWorld world;
  late DeviceStateMachine machine;

  setUp(() async {
    database = await MockDatabase.load();
    world = ScenarioWorld(database);
    machine = DeviceStateMachine(database, onChanged: world.reconcile);
  });

  RequestContext contextFor(HttpMethod method) {
    final context = _MockRequestContext();
    when(() => context.request).thenReturn(
      Request(method.value, Uri.parse('http://localhost/reset')),
    );
    when(() => context.read<ScenarioWorld>()).thenReturn(world);
    when(() => context.read<DeviceStateMachine>()).thenReturn(machine);
    return context;
  }

  group('POST /reset', () {
    test('restores the data, the clock and the undo stack', () async {
      world.moveTo(DateTime.utc(2026, 10, 10, 17, 50));
      world.planner.moveGuests(shiftMinutes: -60);
      machine.toggleTodo(itemId: 'thyme', checked: true);

      final response = route.onRequest(contextFor(HttpMethod.post));

      expect(response.statusCode, HttpStatus.ok);
      expect(
        jsonDecode(await response.body()),
        containsPair(
          'now',
          '2026-10-10T07:30:00',
        ),
      );
      expect(database.calendarEvents.first['start'], '2026-10-10T19:00:00');
      expect(machine.undoLast().changed, isFalse);
      final items = database.todoLists.single['items'] as List<dynamic>;
      final thyme = items.cast<Map<String, dynamic>>().firstWhere(
        (i) => i['id'] == 'thyme',
      );
      expect(thyme['checked'], isFalse);
    });

    test('rejects other methods with 405', () {
      final response = route.onRequest(contextFor(HttpMethod.get));

      expect(response.statusCode, HttpStatus.methodNotAllowed);
    });
  });
}
