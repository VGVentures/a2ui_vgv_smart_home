import 'package:home_backend/data/mock_database.dart';
import 'package:home_backend/scenario/scenario_world.dart';
import 'package:home_timeline/home_timeline.dart';
import 'package:test/test.dart';

void main() {
  late MockDatabase database;
  late ScenarioWorld world;

  setUp(() async {
    database = await MockDatabase.load();
    // The evening these tests walk starts at 4:30 PM, where the demo's Day is.
    world = ScenarioWorld(database)..moveTo(DateTime.utc(2026, 10, 10, 16, 30));
  });

  Matcher notFound(String text) => throwsA(
    isA<MockDataNotFound>().having(
      (e) => e.message,
      'message',
      contains(text),
    ),
  );

  group('CalendarService', () {
    test('finds an event, or names the ones there are', () {
      expect(world.calendar.event('cal_piano')['title'], 'Piano lesson pickup');
      expect(
        () => world.calendar.event('nope'),
        notFound('cal_dinner, cal_piano, cal_cake'),
      );
    });

    test('finds the event where the guests arrive', () {
      expect(world.calendar.guestsEvent()['id'], 'cal_dinner');
      database.calendarEvents.removeWhere((e) => e['kind'] == 'guests_arrive');
      expect(world.calendar.guestsEvent, notFound('No event where guests'));
    });

    test('moves an event and keeps its length', () {
      final result = world.calendar.moveEvent(
        'cal_piano',
        DateTime.utc(2026, 10, 10, 17, 30),
      );

      expect(result['from'], '2026-10-10T17:15:00');
      expect(result['to'], '2026-10-10T17:30:00');
      expect(world.calendar.event('cal_piano')['end'], '2026-10-10T17:45:00');
    });

    test('adds an event once and removes it', () {
      final added = world.calendar.ensureEvent({'id': 'x', 'title': 'A'});
      final again = world.calendar.ensureEvent({'id': 'x', 'title': 'B'});

      expect(again, same(added));
      world.calendar.removeEvent('x');
      expect(() => world.calendar.event('x'), throwsA(isA<MockDataNotFound>()));
    });
  });

  group('OvenService', () {
    test('schedules the preheat and remembers the one it had', () {
      final result = world.oven.schedule(preheatStart: '17:30');

      expect(result['preheatStart'], '17:30');
      expect(result['previousPreheatStart'], '18:30');
      expect(result['confirmed'], isTrue);
    });

    test('leaves what it is not told and a repeated time alone', () {
      world.oven.schedule(preheatStart: '17:30');
      final result = world.oven.schedule(
        preheatStart: '17:30',
        roastIn: '17:50',
      );

      expect(result['previousPreheatStart'], '18:30');
      expect(result['roastInAt'], '17:50');
      expect(world.oven.schedule()['preheatStart'], '17:30');
    });

    test('rejects a time that is not HH:mm', () {
      expect(() => world.oven.schedule(preheatStart: '6pm'), notFound('HH:mm'));
      expect(() => world.oven.schedule(roastIn: '25:00'), notFound('HH:mm'));
    });

    test('shifts the whole programme, with a missing roast-in', () {
      final shifted = world.oven.shift(const Duration(minutes: -60));
      expect(shifted['preheatStart'], '17:30');
      expect(shifted['roastInAt'], '17:45');

      final oven =
          (database.deviceOrNull('oven')!['traits']
                  as Map<String, dynamic>)['CookSchedule']
              as Map<String, dynamic>;
      oven['roastInAt'] = null;
      expect(
        world.oven.shift(const Duration(minutes: 30))['roastInAt'],
        isNull,
      );
    });

    test('says so when there is no oven', () {
      database.homeDevices.removeWhere((d) => d['id'] == 'oven');

      expect(world.oven.schedule, notFound('no oven'));
    });
  });

  group('what the model reads is ready to show', () {
    test('a trip has labels and the whole itinerary, not only ISO times', () {
      final trip = database.tripRows.single;

      expect(trip['leaveByLabel'], '4:55 PM');
      expect(
        (trip['stops'] as List<dynamic>).map(
          (s) => (s as Map)['arriveByLabel'],
        ),
        ['5:15 PM', '5:45 PM', '6:30–6:45 PM'],
      );
      expect(
        (trip['itinerary'] as List<dynamic>).map((e) => (e as Map)['time']),
        ['4:55 PM', '5:15 PM', '5:45 PM', '6:30–6:45 PM', '7:00 PM'],
      );
    });

    test('a delivery has labels too', () {
      world.bakery.requestDelivery('marco');
      world.moveTo(atHhmm(database.clock.start, '16:41'));
      final order =
          (database.bakeryFor('marco')['orders']! as List<dynamic>).single
              as Map;
      expect(order['departsAtLabel'], '5:20 PM');
      expect(order['etaLabel'], '5:45 PM');
    });
  });

  group('BakeryService', () {
    test('needs a user and a pickup to replace', () {
      expect(() => world.bakery.requestDelivery('nobody'), notFound('nobody'));
      world.calendar.removeEvent('cal_cake');
      expect(() => world.bakery.requestDelivery('marco'), notFound('cal_cake'));
    });

    test('a late request leaves as soon as the bakery confirms', () {
      world.moveTo(atHhmm(database.clock.start, '17:20'));

      final order = world.bakery.requestDelivery('marco')['order']! as Map;

      expect(order['slot'], '17:21');
      expect(order['status'], 'pending');
    });

    test('offers fixed slots and a fixed duration', () {
      final options = world.bakery.deliveryOptions();

      expect(options['durationMinutes'], 25);
      expect(options['defaultSlot'], '17:20');
      expect(
        (options['slots']! as List<Object?>).cast<Map<String, Object?>>().map(
          (o) => '${o['departsAt']} → ${o['arrivesAt']}',
        ),
        ['5:20 PM → 5:45 PM'],
      );
    });

    test('books the slot asked for and refuses one it does not offer', () {
      database.bakery['deliverySlots'] = ['17:10', '17:20', '17:40'];
      final order =
          world.bakery.requestDelivery('marco', slot: '17:40')['order']! as Map;

      expect(order['departsAt'], '2026-10-10T17:40:00');
      expect(order['eta'], '2026-10-10T18:05:00');
      expect(order['durationMinutes'], 25);
    });

    test('a slot the bakery does not have lists the ones it has', () {
      expect(
        () => world.bakery.requestDelivery('marco', slot: '17:30'),
        notFound('Available: 17:20'),
      );
    });

    test('notes the guests arrival in its messages', () {
      final result = world.bakery.notifyGuestsArrival(
        DateTime.utc(2026, 10, 10, 18),
        DateTime.utc(2026, 10, 10, 19),
      );

      expect(result['message'], 'Guests now arrive at 6:00 PM (was 7:00 PM).');
      expect(database.bakeryFor('marco')['messages'], hasLength(1));
    });
  });

  group('RecipeService', () {
    test('shifts every step and reports each', () {
      final result = world.recipe.shift(const Duration(minutes: 30));

      expect((result['steps']! as List<dynamic>).first, {
        'id': 'prep',
        'from': '18:00',
        'to': '18:30',
      });
    });
  });

  group('DinnerPlanner', () {
    Matcher rejects(String text) => notFound(text);

    test('needs exactly one of a shift or an arrival', () {
      expect(world.planner.moveGuests, rejects('exactly one'));
      expect(
        () => world.planner.moveGuests(arrival: '18:00', shiftMinutes: -5),
        rejects('exactly one'),
      );
    });

    test('moves to an arrival time', () {
      final result = world.planner.moveGuests(arrival: '18:00');

      expect(result['changed'], isTrue);
      expect(result['summary'], contains('6:00 PM (was 7:00 PM)'));
      expect((result['effects']! as List<dynamic>).length, 5);
      expect(
        ((result['trips']! as List<dynamic>).single as Map)['userId'],
        'marco',
      );
    });

    test('says so when nothing moves', () {
      final result = world.planner.moveGuests(shiftMinutes: 0);

      expect(result['changed'], isFalse);
      expect(result['effects'], isEmpty);
    });

    test('rejects a time that is not HH:mm or is already past', () {
      expect(() => world.planner.moveGuests(arrival: 'six'), rejects('HH:mm'));
      world.moveTo(atHhmm(database.clock.start, '17:00'));
      expect(
        () => world.planner.moveGuests(arrival: '16:00'),
        rejects('Guests cannot arrive at 4:00 PM, it is 5:00 PM now'),
      );
    });
  });

  group('TripService', () {
    test('says there is not enough range when the car cannot make it', () {
      final car =
          database.deviceOrNull('car')!['traits'] as Map<String, dynamic>;
      (car['Battery'] as Map<String, dynamic>)['rangeMiles'] = 10;
      world.reconcile();

      expect(
        (database.tripRows.single['rangeCheck'] as Map)['summary'],
        'Not enough range for the trip',
      );
    });

    test('says there is no range when the car is missing', () {
      database.homeDevices.removeWhere((d) => d['id'] == 'car');
      world.reconcile();

      expect(
        (database.tripRows.single['rangeCheck'] as Map)['enough'],
        isFalse,
      );
    });

    test('fails when a stop points at a missing event', () {
      world.calendar.removeEvent('cal_piano');

      expect(world.reconcile, notFound('cal_piano'));
    });

    test('leaves a trip with no planned stops alone', () {
      database.tripRows.add({'id': 'bare'});
      world.reconcile();

      expect(database.tripRows.last, {'id': 'bare'});
    });

    test('a trip whose stops are all dropped is left alone', () {
      final trip = database.tripRows.single;
      (trip['plannedStops'] as List<dynamic>).removeAt(0);
      world.bakery.requestDelivery('marco');
      world.moveTo(atHhmm(database.clock.start, '16:45'));

      expect((trip['stops'] as List<dynamic>).length, 3);
    });
  });

  group('ScenarioWorld', () {
    test('answers the clock', () {
      expect(world.clockJson()['timeZone'], 'America/Chicago');
    });
  });
}
