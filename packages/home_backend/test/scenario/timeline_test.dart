import 'package:home_backend/data/mock_database.dart';
import 'package:home_backend/devices/device_command.dart';
import 'package:home_backend/devices/device_exceptions.dart';
import 'package:home_backend/devices/device_state_machine.dart';
import 'package:home_backend/scenario/scenario_world.dart';
import 'package:home_timeline/home_timeline.dart';
import 'package:test/test.dart';

/// Walks the demo's event timeline against the shipped data, from the Saturday
/// 4:30 PM start to the guests at the door, the way the document lists it.
void main() {
  late MockDatabase database;
  late ScenarioWorld world;
  late DeviceStateMachine machine;

  setUp(() async {
    database = await MockDatabase.load();
    world = ScenarioWorld(database);
    machine = DeviceStateMachine(database, onChanged: world.reconcile);
    // The evening these tests walk starts at 4:30 PM, where the demo's Day is.
    world.moveTo(DateTime.utc(2026, 10, 10, 16, 30));
  });

  void at(String hhmmTime) =>
      world.moveTo(atHhmm(database.clock.start, hhmmTime));

  Map<String, dynamic> trait(String device, String name) =>
      (database.deviceOrNull(device)!['traits'] as Map<String, dynamic>)[name]
          as Map<String, dynamic>;

  Map<String, dynamic> trip() => database.tripRows.single;

  List<String> stopTimes() => [
    for (final stop
        in (trip()['stops'] as List<dynamic>).cast<Map<String, dynamic>>())
      '${stop['name']} ${clock12(parseWall(stop['arriveBy'] as String))}',
  ];

  Map<String, dynamic> event(String id) =>
      database.calendarEvents.firstWhere((e) => e['id'] == id);

  List<String> plan() => [
    for (final step in database.recipeSteps)
      '${step['at']} ${step['id']}${step['done'] == true ? ' ✓' : ''}',
  ];

  group('4:30 PM, the initial state', () {
    test('the oven is off with the recipe preset', () {
      expect(trait('oven', 'OperationalState')['state'], 'stopped');
      expect(
        trait('oven', 'OperationalState')['statusLabel'],
        'Off · preheats at 6:30 PM',
      );
      expect(trait('oven', 'TemperatureControl')['temperatureSetpointF'], 400);
      expect(trait('oven', 'CookSchedule')['cookMinutes'], 25);
    });

    test('the fridge is 37 °F with the door closed', () {
      expect(
        trait('fridge', 'TemperatureMeasurement')['cabinetTemperatureF'],
        37,
      );
      expect(trait('fridge', 'BooleanState')['doorOpen'], isFalse);
    });

    test('the calendar has the guests at 7:00 and both of Marco pickups', () {
      expect(event('cal_dinner')['start'], '2026-10-10T19:00:00');
      expect(event('cal_piano')['start'], '2026-10-10T17:15:00');
      expect(event('cal_cake')['start'], '2026-10-10T17:45:00');
    });

    test(
      "tonight's plan is 6:00 prep, 6:30 preheat, 6:45 roast, 7:15 serve",
      () {
        expect(plan(), [
          '18:00 prep',
          '18:30 preheat',
          '18:45 roast_in',
          '18:45 scene',
          '19:15 serve',
        ]);
      },
    );

    test('shopping has five items, four ticked and only the thyme open', () {
      final items = (database.todoLists.single['items'] as List<dynamic>)
          .cast<Map<String, dynamic>>();
      expect(items.map((i) => i['label']), [
        'Rack of lamb',
        'Red wine',
        'Fresh thyme',
        'Shallots',
        'Sparkling water',
      ]);
      expect(
        [
          for (final i in items)
            if (i['checked'] == false) i['id'],
        ],
        ['thyme'],
      );
    });

    test("Marco's route leaves at 4:55 with enough range for both stops", () {
      expect(stopTimes(), [
        'Piano lesson pickup 5:15 PM',
        'Bakery 5:45 PM',
        'Home 6:30 PM',
      ]);
      expect(trip()['leaveBy'], '2026-10-10T16:55:00');
      expect(
        (trip()['rangeCheck'] as Map)['summary'],
        'Enough range for both stops',
      );
      expect(trip()['homeAfterGuestsArrive'], isFalse);
    });

    test('the car, the front door and thermostat match', () {
      expect(trait('car', 'Battery'), {'levelPercent': 82, 'rangeMiles': 190});
      expect(trait('front_door', 'DoorLock')['lockState'], 'locked');
      expect(trait('thermostat', 'Thermostat')['currentTemperatureF'], 67);
    });
  });

  test('Ana checks off the thyme', () {
    machine.toggleTodo(itemId: 'thyme', checked: true);
    final items = database.todoLists.single['items'] as List<dynamic>;
    final thyme = items.cast<Map<String, dynamic>>().firstWhere(
      (i) => i['id'] == 'thyme',
    );
    expect(thyme['checked'], isTrue);
  });

  test('Marco preconditions the cabin for the 4:55 departure', () {
    at('16:33');
    machine.execute('car', DeviceCommand.start);

    expect(trait('car', 'Climate')['startAt'], '16:50');
    expect(trait('car', 'Climate')['statusLabel'], 'Climate on at 4:50 PM');

    at('16:50');
    expect(trait('car', 'Climate')['state'], 'on');

    at('16:40');
    expect(trait('car', 'Climate')['state'], 'scheduled');
  });

  test('the car has nothing to get ready for without a trip', () {
    database.tripRows.clear();

    expect(
      () => machine.execute('car', DeviceCommand.start),
      throwsA(isA<CommandRejected>()),
    );
  });

  test('stopping the car climate cancels the precondition', () {
    machine
      ..execute('car', DeviceCommand.start)
      ..execute('car', DeviceCommand.stop);

    expect(trait('car', 'Climate')['state'], 'off');
  });

  group('guests an hour earlier', () {
    setUp(() {
      at('16:36');
      world.planner.moveGuests(shiftMinutes: -60);
    });

    test('reflows every step of the plan one hour earlier', () {
      expect(plan(), [
        '17:00 prep',
        '17:30 preheat',
        '17:45 roast_in',
        '17:45 scene',
        '18:15 serve',
      ]);
    });

    test('moves the guests on the calendar to 6:00', () {
      expect(event('cal_dinner')['start'], '2026-10-10T18:00:00');
      expect(event('cal_dinner')['end'], '2026-10-10T21:30:00');
    });

    test('the oven confirms the new preheat, 5:30 and was 6:30', () {
      expect(trait('oven', 'TemperatureControl')['scheduledStart'], '17:30');
      expect(trait('oven', 'CookSchedule')['previousPreheatStart'], '18:30');
    });

    test('tells the bakery', () {
      final messages = database.bakery['messages'] as List<dynamic>;
      expect(
        (messages.single as Map)['text'],
        contains('6:00 PM (was 7:00 PM)'),
      );
    });

    test("flags Marco's home time as after the guests arrive", () {
      expect(trip()['homeAfterGuestsArrive'], isTrue);
      expect(trip()['notes'], [
        'Home at 6:30–6:45 PM is after the guests arrive at 6:00 PM.',
      ]);
      expect(trip()['leaveBy'], '2026-10-10T16:55:00');
    });
  });

  group('the cake delivery', () {
    setUp(() {
      at('16:36');
      world.planner.moveGuests(shiftMinutes: -60);
      at('16:39');
    });

    test('is pending when asked, with nothing changed yet', () {
      final result = world.bakery.requestDelivery('marco');

      expect(result['action'], 'requested');
      expect((result['order']! as Map)['status'], 'pending');
      expect(stopTimes(), hasLength(3));
    });

    test('is confirmed a minute later with an ETA of 5:45', () {
      world.bakery.requestDelivery('marco');
      at('16:41');

      final order = database.bakeryFor('marco')['orders']! as List<dynamic>;
      expect((order.single as Map)['status'], 'confirmed');
      expect((order.single as Map)['eta'], '2026-10-10T17:45:00');
    });

    test('is pending until the courier leaves, then in progress', () {
      world.bakery.requestDelivery('marco');
      Map<String, dynamic> order() =>
          (database.bakeryFor('marco')['orders']! as List<dynamic>).single
              as Map<String, dynamic>;

      at('17:00');
      expect(order()['status'], 'confirmed');
      expect(order()['progressPercent'], 0);
      expect(
        order()['statusLabel'],
        'Pending · courier leaves the bakery at 5:20 PM',
      );

      at('17:30');
      expect(order()['status'], 'out_for_delivery');
      expect(order()['progressPercent'], 40);
      expect(
        order()['statusLabel'],
        'In progress · 15 min left, arrives 5:45 PM',
      );

      at('17:45');
      expect(order()['status'], 'delivered');
      expect(order()['progressPercent'], 100);
      expect(order()['statusLabel'], 'Delivered · 5:45 PM');
    });

    test('drops the bakery stop: home by 5:30–5:45, enough for the trip', () {
      world.bakery.requestDelivery('marco');
      at('16:41');

      expect(stopTimes(), ['Piano lesson pickup 5:15 PM', 'Home 5:30 PM']);
      expect(
        (trip()['rangeCheck'] as Map)['summary'],
        'Enough range for the trip',
      );
      expect(trip()['homeArrivalRange'], '5:30–5:45 PM');
      expect(trip()['homeAfterGuestsArrive'], isFalse);
      expect(
        database.calendarEvents
            .where((e) => e['status'] != 'cancelled')
            .map((e) => e['id'])
            .toSet(),
        {
          'cal_piano',
          'cal_cake_delivery',
          'cal_dinner',
          'cal_market',
          'cal_standup',
          'cal_florist',
          'cal_table',
          'cal_ice',
          'cal_chairs',
          'cal_dessert',
          'cal_wind_down',
          'cal_cleanup',
          'cal_breakfast',
          'cal_yoga',
          'cal_run',
          'cal_reading',
          'cal_course',
          'cal_lunch',
          'cal_walk',
          'cal_garage',
          'cal_prep_cook',
          'cal_shower',
        },
      );
    });

    test('is delivered at 5:45 and the doorbell sees the courier', () {
      world.bakery.requestDelivery('marco');
      at('17:45');

      final order = database.bakeryFor('marco')['orders']! as List<dynamic>;
      expect((order.single as Map)['status'], 'delivered');
      expect(trait('doorbell', 'DoorbellEvent'), {
        'kind': 'delivery',
        'label': 'Delivery · cake',
        'at': '2026-10-10T17:45:00',
        'handledBy': 'marco',
      });
    });

    test('rewinding before the request puts everything back', () {
      world.bakery.requestDelivery('marco');
      at('17:40');
      at('16:30');

      expect(database.bakeryFor('marco')['orders'], isEmpty);
      expect(event('cal_cake')['status'], 'confirmed');
      expect(stopTimes(), hasLength(3));
    });

    test('asking again returns the order that exists', () {
      world.bakery.requestDelivery('marco');

      expect(
        world.bakery.requestDelivery('marco')['action'],
        'already_requested',
      );
    });

    test('asking after a rewind makes a fresh order', () {
      world.bakery.requestDelivery('marco');
      at('17:40');
      at('16:30');

      expect(world.bakery.requestDelivery('marco')['action'], 'requested');
      expect(
        (database.bakery['orders']! as List<dynamic>).length,
        1,
      );
    });
  });

  group('time passing', () {
    setUp(() {
      at('16:36');
      world.planner.moveGuests(shiftMinutes: -60);
      at('16:39');
      world.bakery.requestDelivery('marco');
    });

    test('prep is done by 5:30', () {
      at('17:30');
      expect(plan().first, '17:00 prep ✓');
    });

    test('the oven climbs from 5:30 and is ready at 400 °F at 5:44', () {
      at('17:35');
      expect(trait('oven', 'OperationalState')['state'], 'preheating');
      expect(
        trait('oven', 'TemperatureControl')['currentTemperatureF'],
        inInclusiveRange(150, 230),
      );

      at('17:40');
      expect(
        trait('oven', 'TemperatureControl')['currentTemperatureF'],
        inInclusiveRange(280, 330),
      );

      at('17:44');
      expect(trait('oven', 'OperationalState')['state'], 'ready');
      expect(
        trait('oven', 'OperationalState')['statusLabel'],
        'Ready · 400 °F',
      );
    });

    test('the roast goes in at 5:45 and is done at 6:10', () {
      at('17:45');
      expect(trait('oven', 'OperationalState')['state'], 'roasting');
      expect(
        trait('oven', 'OperationalState')['statusLabel'],
        'Roasting · done 6:10 PM',
      );
      expect(plan(), contains('17:45 roast_in ✓'));

      at('18:00');
      expect(trait('oven', 'CookSchedule')['remainingMinutes'], 10);

      at('18:10');
      expect(trait('oven', 'OperationalState')['state'], 'done');
    });

    test('Ana starts the dining scene at 5:42, ahead of the plan', () {
      at('17:42');
      machine.runScene('dinner_party');

      expect(trait('table_lights', 'LevelControl')['currentLevel'], 40);
      expect(trait('dining_speaker', 'MediaPlayback')['state'], 'playing');
      expect(trait('thermostat', 'Thermostat')['heatSetpointF'], 70);
      expect(plan(), contains('17:45 scene ✓'));
    });

    test('the guests ring at 6:00 and the courier is no longer current', () {
      at('17:56');
      expect(trait('doorbell', 'DoorbellEvent')['kind'], 'delivery');
      expect(
        trait('doorbell', 'DoorbellPress')['lastPressAt'],
        '2026-10-10T17:45:00',
      );

      at('18:00');
      expect(trait('doorbell', 'DoorbellEvent')['kind'], 'guests');
      expect(
        trait('doorbell', 'DoorbellEvent')['label'],
        'Guests at the front door',
      );
    });

    test('before any ring the doorbell is quiet', () {
      at('16:30');
      expect(trait('doorbell', 'DoorbellPress')['lastPressAt'], isNull);
    });

    test('a courier for someone with no trip is handled by nobody', () {
      world.reset();
      world.calendar.event('cal_cake')['userId'] = 'ana';
      at('16:36');
      world.bakery.requestDelivery('ana');
      at('17:45');

      expect(trait('doorbell', 'DoorbellEvent')['kind'], 'delivery');
      expect(trait('doorbell', 'DoorbellEvent')['handledBy'], isNull);
    });
  });

  group('the oven', () {
    test(
      'starting it preheats from now and stopping it clears the schedule',
      () {
        at('16:45');
        machine.execute('oven', DeviceCommand.on);
        expect(trait('oven', 'TemperatureControl')['scheduledStart'], '16:45');
        expect(trait('oven', 'OperationalState')['state'], 'preheating');

        machine.execute('oven', DeviceCommand.off);
        expect(trait('oven', 'TemperatureControl')['scheduledStart'], isNull);
        expect(trait('oven', 'OperationalState')['statusLabel'], 'Off');
      },
    );

    test('without a roast-in time it stays ready after preheating', () {
      world.oven.schedule(preheatStart: '16:30');
      trait('oven', 'CookSchedule')['roastInAt'] = null;
      at('16:50');

      expect(trait('oven', 'OperationalState')['state'], 'ready');
      expect(trait('oven', 'CookSchedule')['doneAt'], isNull);
    });

    test('a roast-in before it is hot waits for the oven', () {
      world.oven.schedule(preheatStart: '16:30', roastIn: '16:35');
      at('16:44');
      expect(trait('oven', 'OperationalState')['state'], 'roasting');
      expect(trait('oven', 'CookSchedule')['doneAt'], '17:09');
    });
  });

  group('reset', () {
    test('puts the data, the clock and the undo stack back', () {
      at('16:36');
      world.planner.moveGuests(shiftMinutes: -60);
      at('16:39');
      world.bakery.requestDelivery('marco');
      machine.toggleTodo(itemId: 'thyme', checked: true);
      at('17:50');

      world.reset();
      machine.reset();

      expect(database.clock.nowIso, '2026-10-10T07:30:00');
      expect(event('cal_dinner')['start'], '2026-10-10T19:00:00');
      expect(database.bakeryFor('marco')['orders'], isEmpty);
      expect(database.bakery['messages'], isEmpty);
      expect(trait('oven', 'TemperatureControl')['scheduledStart'], '18:30');
      expect(trait('oven', 'OperationalState')['state'], 'stopped');
      expect(stopTimes(), hasLength(3));
      expect(machine.undoLast().changed, isFalse);
      final items = database.todoLists.single['items'] as List<dynamic>;
      final thyme = items.cast<Map<String, dynamic>>().firstWhere(
        (i) => i['id'] == 'thyme',
      );
      expect(thyme['checked'], isFalse);
    });
  });

  test('rewinding is as right as going forward', () {
    at('17:50');
    at('16:30');

    expect(trait('oven', 'OperationalState')['state'], 'stopped');
    expect(plan().every((s) => !s.endsWith('✓')), isTrue);
  });
}
