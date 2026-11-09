import 'package:home_backend/data/mock_database.dart';
import 'package:home_backend/scenario/database_feed_source.dart';
import 'package:home_backend/scenario/inbox_service.dart';
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

  List<Map<String, dynamic>> inboxOf(String userId) =>
      (database.inboxFor(userId)['items']! as List<dynamic>)
          .cast<Map<String, dynamic>>();

  group('InboxService', () {
    test('writes an unread item for the person it is for', () {
      final effect = world.inbox.post(
        to: 'marco',
        from: 'ana',
        kind: 'note',
        title: 'Hello',
        body: 'Hi Marco.',
      );

      expect(effect, {
        'service': 'inbox',
        'action': 'notify',
        'to': 'marco',
        'itemId': 'inbox_1',
        'title': 'Hello',
      });
      expect(inboxOf('ana'), isEmpty);
      expect(inboxOf('marco').single, {
        'id': 'inbox_1',
        'userId': 'marco',
        'from': 'ana',
        'at': '2026-10-10T16:30:00',
        'kind': 'note',
        'title': 'Hello',
        'body': 'Hi Marco.',
        'read': false,
      });
      expect(database.inboxFor('marco')['unread'], 1);
    });

    test('keeps the suggestion it was given', () {
      world.inbox.post(
        to: 'marco',
        from: 'ana',
        kind: 'note',
        title: 'Hello',
        body: 'Hi.',
        suggestion: {'tool': 'request_bakery_delivery'},
      );

      expect(inboxOf('marco').single['suggestion'], {
        'tool': 'request_bakery_delivery',
      });
    });

    test('tells its listener about the item', () {
      final seen = <Map<String, Object?>>[];
      InboxService(database, onPosted: seen.add).post(
        to: 'marco',
        from: 'ana',
        kind: 'note',
        title: 'Hello',
        body: 'Hi.',
      );

      expect(seen.single['title'], 'Hello');
    });

    test('knows both people', () {
      expect(
        () => world.inbox.post(
          to: 'nobody',
          from: 'ana',
          kind: 'k',
          title: 't',
          body: 'b',
        ),
        notFound('nobody'),
      );
      expect(
        () => world.inbox.post(
          to: 'ana',
          from: 'nobody',
          kind: 'k',
          title: 't',
          body: 'b',
        ),
        notFound('nobody'),
      );
    });

    group('markRead', () {
      setUp(() {
        for (final title in ['One', 'Two']) {
          world.inbox.post(
            to: 'marco',
            from: 'ana',
            kind: 'note',
            title: title,
            body: title,
          );
        }
      });

      test('marks everything unread', () {
        final result = world.inbox.markRead('marco');

        expect(result, {'userId': 'marco', 'markedRead': 2});
        expect(database.inboxFor('marco')['unread'], 0);
        expect(world.inbox.markRead('marco')['markedRead'], 0);
      });

      test('marks one item', () {
        final result = world.inbox.markRead('marco', itemId: 'inbox_1');

        expect(result['markedRead'], 1);
        expect(database.inboxFor('marco')['unread'], 1);
      });

      test('names the items there are for one that is missing', () {
        expect(
          () => world.inbox.markRead('marco', itemId: 'nope'),
          notFound('inbox_1, inbox_2'),
        );
        expect(() => world.inbox.markRead('nobody'), notFound('nobody'));
      });
    });
  });

  group('the inbox in the database', () {
    test('lists the newest first and hides what the clock has not reached', () {
      world.moveTo(atHhmm(database.clock.start, '17:00'));
      world.inbox.post(
        to: 'marco',
        from: 'ana',
        kind: 'note',
        title: 'Later',
        body: 'b',
      );
      world.moveTo(atHhmm(database.clock.start, '16:45'));

      expect(inboxOf('marco'), isEmpty);

      world.moveTo(atHhmm(database.clock.start, '17:10'));
      world.inbox.post(
        to: 'marco',
        from: 'ana',
        kind: 'note',
        title: 'Newest',
        body: 'b',
      );

      expect(inboxOf('marco').map((item) => item['title']), [
        'Newest',
        'Later',
      ]);
    });

    test('is empty for a database built without one', () {
      final bare = MockDatabase(
        users: {
          'users': [
            {'id': 'ana'},
          ],
        },
        home: <String, dynamic>{},
      );

      expect(bare.inboxFor('ana')['items'], isEmpty);
      expect(bare.inbox['items'], isEmpty);
      expect(() => bare.inboxFor('nobody'), notFound('nobody'));
    });

    test('goes back to empty on a reset', () {
      world.inbox.post(
        to: 'marco',
        from: 'ana',
        kind: 'note',
        title: 'Hello',
        body: 'Hi.',
      );

      world.reset();

      expect(inboxOf('marco'), isEmpty);
    });

    test('has no items when the document has none', () {
      database.inbox.remove('items');

      expect(database.inboxItems, isEmpty);
    });
  });

  group('DinnerPlanner tells the people it concerns', () {
    test('Marco hears Ana moved the dinner, and what to do about it', () {
      final result = world.planner.moveGuests(
        shiftMinutes: -60,
        requestedBy: 'ana',
      );

      expect(
        (result['effects']! as List<dynamic>).last,
        containsPair('to', 'marco'),
      );
      expect(inboxOf('ana'), isEmpty);
      final item = inboxOf('marco').single;
      expect(item['from'], 'ana');
      expect(item['title'], 'Dinner moved to 6:00 PM');
      expect(
        item['body'],
        'Ana moved the dinner party from 7:00 PM to 6:00 PM. Your route now '
        'gets you home at 6:30–6:45 PM, after the guests arrive.',
      );
      expect(
        item['suggestion'],
        containsPair('tool', 'request_bakery_delivery'),
      );
    });

    test('defaults to the owner of the dinner as the one who asked', () {
      world.planner.moveGuests(arrival: '18:00');

      expect(inboxOf('marco'), hasLength(1));
      expect(inboxOf('ana'), isEmpty);
    });

    test('Ana hears when Marco moves it, with nothing to fix', () {
      world.planner.moveGuests(shiftMinutes: -60, requestedBy: 'marco');

      expect(inboxOf('marco'), isEmpty);
      final item = inboxOf('ana').single;
      expect(
        item['body'],
        'Marco moved the dinner party from 7:00 PM to 6:00 PM.',
      );
      expect(item.containsKey('suggestion'), isFalse);
    });

    test('says what moved but offers nothing when the route still works', () {
      world.planner.moveGuests(shiftMinutes: 60);

      final item = inboxOf('marco').single;
      expect(item['title'], 'Dinner moved to 8:00 PM');
      expect(
        item['body'],
        'Ana moved the dinner party from 7:00 PM to 8:00 PM.',
      );
      expect(item.containsKey('suggestion'), isFalse);
    });

    test('does not offer a delivery that was already asked for', () {
      world.bakery.requestDelivery('marco');

      world.planner.moveGuests(shiftMinutes: -60);

      final item = inboxOf('marco').single;
      expect(item['body'], contains('after the guests arrive'));
      expect(item.containsKey('suggestion'), isFalse);
    });

    test('does not tell anyone when nothing moved', () {
      world.planner.moveGuests(shiftMinutes: 0);

      expect(inboxOf('marco'), isEmpty);
    });

    test('knows who asked', () {
      expect(
        () => world.planner.moveGuests(shiftMinutes: -60, requestedBy: 'x'),
        notFound('x'),
      );
    });
  });

  group('BakeryService', () {
    test(
      'only the person the pickup is assigned to can ask for a delivery',
      () {
        expect(
          () => world.bakery.requestDelivery('ana'),
          notFound('assigned to marco'),
        );
        expect(world.bakery.requestDelivery('marco')['action'], 'requested');
      },
    );
  });

  group('ActivityFeed', () {
    late ActivityFeed feed;

    setUp(() => feed = ActivityFeed(DatabaseFeedSource(database)));

    List<String> summaries(Object? moments) => [
      for (final m in (moments! as List<dynamic>).cast<Map<String, Object?>>())
        m['summary']! as String,
    ];

    test("puts the pickup in Marco's next and the dinner in both", () {
      world.moveTo(atHhmm(database.clock.start, '17:00'));

      expect(summaries(feed.forUser('marco')['next']), [
        'Piano lesson pickup',
        'Bakery cake pickup',
        'Guests arrive',
      ]);
      expect(summaries(feed.forUser('ana')['next']), contains('Guests arrive'));
    });

    test('shows a notification as what just happened to its person', () {
      world.planner.moveGuests(shiftMinutes: -60);

      final marco = feed.forUser('marco');

      expect(summaries(marco['recent']), contains('Dinner moved to 6:00 PM'));
      expect(
        (marco['recent']! as List<dynamic>)
            .cast<Map<String, dynamic>>()
            .firstWhere(
              (m) => m['kind'] == 'inbox',
            ),
        containsPair('by', 'ana'),
      );
      expect(
        summaries(feed.forUser('ana')['recent']),
        isNot(contains('Dinner moved to 6:00 PM')),
      );
    });
  });
}
