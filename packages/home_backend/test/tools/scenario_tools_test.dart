import 'package:home_backend/data/mock_database.dart';
import 'package:home_backend/scenario/scenario_world.dart';
import 'package:home_backend/tools/agent_tool.dart';
import 'package:home_backend/tools/scenario_tools.dart';
import 'package:test/test.dart';

void main() {
  late MockDatabase database;
  late ScenarioWorld world;

  setUp(() async {
    database = await MockDatabase.load();
    // The evening these tests walk starts at 4:30 PM, where the demo's Day is.
    world = ScenarioWorld(database)..moveTo(DateTime.utc(2026, 10, 10, 16, 30));
  });

  Future<Map<String, Object?>> run(
    AgentTool tool,
    Map<String, dynamic> args,
  ) async => Map<String, Object?>.from((await tool.call(args))! as Map);

  group('reschedule_guest_arrival', () {
    test('moves the whole dinner and lists what it touched', () async {
      final result = await run(
        rescheduleGuestArrivalTool(world),
        {'shift_minutes': -60},
      );

      expect(result['changed'], isTrue);
      final services = [
        for (final e in result['effects']! as List<dynamic>)
          (e as Map)['service'],
      ];
      expect(services, ['calendar', 'recipe', 'oven', 'bakery', 'inbox']);
    });

    test('takes a clock time too', () async {
      final result = await run(
        rescheduleGuestArrivalTool(world),
        {'new_arrival': '18:30'},
      );

      expect(result['summary'], contains('6:30 PM'));
    });

    test('hands a bad request back to the model', () {
      expect(
        rescheduleGuestArrivalTool(world).call(<String, dynamic>{}),
        throwsA(isA<MockDataNotFound>()),
      );
    });
  });

  group('schedule_oven', () {
    test('programmes the oven and reconciles', () async {
      final result = await run(
        scheduleOvenTool(world),
        {'preheat_start': '16:30', 'roast_in': '16:50'},
      );

      expect(result['preheatStart'], '16:30');
      final op =
          (database.deviceOrNull('oven')!['traits']
                  as Map<String, dynamic>)['OperationalState']
              as Map<String, dynamic>;
      expect(op['state'], 'preheating');
    });
  });

  group('request_bakery_delivery and get_bakery_orders', () {
    test('asks, then the orders show it pending', () async {
      final asked = await run(
        requestBakeryDeliveryTool(world),
        {'user_id': 'marco'},
      );
      final read = await run(
        bakeryOrdersTool(database),
        {'user_id': 'marco'},
      );

      expect(asked['action'], 'requested');
      expect(
        ((read['orders']! as List<dynamic>).single as Map)['status'],
        'pending',
      );
      expect(read['bakery'], 'Maple & Crumb Bakery');
    });

    test(
      'asking also puts the delivery on both calendars',
      () async {
        await run(
          requestBakeryDeliveryTool(world),
          {'user_id': 'marco', 'slot': '17:20'},
        );

        final delivery = database.calendarEvents.singleWhere(
          (e) => e['id'] == 'cal_cake_delivery',
        );
        expect(delivery['leavesAt'], '5:20 PM');
        expect(delivery['arrivesAt'], '5:45 PM');
        expect(database.inboxFor('ana')['items'], isEmpty);
      },
    );

    test('an unknown user is handed back', () {
      expect(
        bakeryOrdersTool(database).call({'user_id': 'nobody'}),
        throwsA(isA<MockDataNotFound>()),
      );
    });
  });

  group('get_home_activity', () {
    test('answers what just happened and what is next', () async {
      final result = await run(
        homeActivityTool(database),
        {'user_id': 'ana'},
      );

      expect(result['nowLabel'], '4:30 PM');
      expect(result['recent'], hasLength(1));
      expect(result['next'], isNotEmpty);
    });

    test('an unknown user is handed back', () {
      expect(
        homeActivityTool(database).call({'user_id': 'nobody'}),
        throwsA(isA<MockDataNotFound>()),
      );
    });
  });
}
