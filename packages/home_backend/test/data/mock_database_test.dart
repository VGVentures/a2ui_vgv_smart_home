import 'dart:convert';
import 'dart:io';

import 'package:home_backend/data/mock_database.dart';
import 'package:test/test.dart';

const _users = {
  'users': [
    {'id': 'ana', 'name': 'Ana', 'role': 'Host'},
    {'id': 'marco', 'name': 'Marco', 'role': 'Logistics'},
  ],
};

const _home = {
  'now': '2026-10-10T16:30:00',
  'timeZone': 'America/Chicago',
  'structure': {'id': 's', 'name': 'Rivera Home'},
  'rooms': [
    {'id': 'kitchen', 'name': 'Kitchen'},
    {'id': 'garage', 'name': 'Garage'},
  ],
  'devices': [
    {'id': 'oven', 'room': 'kitchen', 'type': 'OvenDevice'},
    {'id': 'fridge', 'room': 'kitchen', 'type': 'RefrigeratorDevice'},
    {'id': 'car', 'room': 'garage', 'type': 'GoogleAutoDevice'},
  ],
  'groups': [
    {'id': 'g'},
  ],
  'automations': [
    {
      'id': 'dinner',
      'owners': ['ana'],
    },
    {
      'id': 'charge',
      'owners': ['marco'],
    },
  ],
};

const _calendar = {
  'source': 'Google Calendar',
  'timeZone': 'America/Chicago',
  'events': [
    {'id': 'c1', 'userId': 'ana', 'start': '2026-10-10T19:00:00'},
    {'id': 'c2', 'userId': 'marco', 'start': '2026-10-10T17:15:00'},
  ],
};

const _trips = {
  'source': 'Google Maps',
  'timeZone': 'America/Chicago',
  'trips': [
    {'id': 't1', 'userId': 'marco'},
  ],
};

const _recipeTimeline = {
  'timeZone': 'America/Chicago',
  'steps': [
    {'userId': 'ana', 'step': 'Preheat'},
  ],
};

const _todos = {
  'source': 'Synthetic',
  'lists': [
    {
      'id': 'shopping',
      'owners': ['ana'],
      'sharedWith': ['marco'],
      'items': <Object?>[],
    },
    {
      'id': 'chores',
      'owners': ['marco'],
      'sharedWith': <String>[],
      'items': <Object?>[],
    },
  ],
};

const _bakery = {
  'name': 'Bakery',
  'orders': [
    {'id': 'o1', 'userId': 'marco'},
  ],
  'messages': <Object?>[],
};

const _files = {
  'users.json': _users,
  'google_home.json': _home,
  'calendar.json': _calendar,
  'recipe_timeline.json': _recipeTimeline,
  'trips.json': _trips,
  'bakery.json': _bakery,
  'inbox.json': {'items': <Object?>[]},
  'todos.json': _todos,
};

List<String> _ids(Object? rows) => [
  for (final row in rows! as List<dynamic>) (row as Map)['id'] as String,
];

void main() {
  final database = MockDatabase(
    users: _users,
    home: _home,
    calendar: _calendar,
    recipeTimeline: _recipeTimeline,
    trips: _trips,
    todos: _todos,
  );

  group('MockDatabase', () {
    test('lists users as id, name and role', () {
      expect(database.listUsers(), [
        {'id': 'ana', 'name': 'Ana', 'role': 'Host'},
        {'id': 'marco', 'name': 'Marco', 'role': 'Logistics'},
      ]);
    });

    test('finds a user by id and returns null for an unknown one', () {
      expect(database.findUser('marco')?['name'], 'Marco');
      expect(database.findUser('nobody'), isNull);
    });

    test('requireUser throws a not found naming the available ids', () {
      expect(database.requireUser('ana')['role'], 'Host');
      expect(
        () => database.requireUser('nobody'),
        throwsA(
          isA<MockDataNotFound>().having(
            (e) => e.toString(),
            'message',
            'No user "nobody". Available: ana, marco.',
          ),
        ),
      );
    });

    group('homeFor', () {
      test("returns household wide data and the user's automations", () {
        final home = database.homeFor('marco');

        expect(home['now'], '2026-10-10T16:30:00');
        expect(home['timeZone'], 'America/Chicago');
        expect(home['structure'], {'id': 's', 'name': 'Rivera Home'});
        expect(_ids(home['rooms']), ['kitchen', 'garage']);
        expect(_ids(home['devices']), ['oven', 'fridge', 'car']);
        expect(_ids(home['groups']), ['g']);
        expect(_ids(home['automations']), ['charge']);
      });

      test('leaves out data that does not come from Google Home', () {
        final keys = database.homeFor('ana').keys;

        for (final other in ['calendar', 'trips', 'recipeTimeline']) {
          expect(keys, isNot(contains(other)));
        }
      });

      test('narrows automations to another user', () {
        expect(_ids(database.homeFor('ana')['automations']), ['dinner']);
      });

      test('filters devices by room id or name without regard to case', () {
        expect(
          _ids(database.homeFor('ana', room: 'kitchen')['devices']),
          ['oven', 'fridge'],
        );
        expect(
          _ids(database.homeFor('ana', room: 'GARAGE')['devices']),
          ['car'],
        );
      });

      test('filters devices by device type without regard to case', () {
        expect(
          _ids(database.homeFor('ana', deviceType: 'ovendevice')['devices']),
          ['oven'],
        );
      });

      test('combines the room and device type filters', () {
        expect(
          _ids(
            database.homeFor(
              'ana',
              room: 'Kitchen',
              deviceType: 'RefrigeratorDevice',
            )['devices'],
          ),
          ['fridge'],
        );
      });

      test('throws for an unknown user', () {
        expect(
          () => database.homeFor('nobody'),
          throwsA(isA<MockDataNotFound>()),
        );
      });

      test('throws for an unknown room and lists the rooms', () {
        expect(
          () => database.homeFor('ana', room: 'Attic'),
          throwsA(
            isA<MockDataNotFound>().having(
              (e) => e.message,
              'message',
              'No room "Attic". Available: Kitchen, Garage.',
            ),
          ),
        );
      });

      test('throws for an unknown device type and lists the types', () {
        expect(
          () => database.homeFor('ana', deviceType: 'Toaster'),
          throwsA(
            isA<MockDataNotFound>().having(
              (e) => e.message,
              'message',
              contains('Available: OvenDevice, RefrigeratorDevice'),
            ),
          ),
        );
      });

      test('throws when the filters match no device together', () {
        expect(
          () => database.homeFor(
            'ana',
            room: 'Garage',
            deviceType: 'OvenDevice',
          ),
          throwsA(
            isA<MockDataNotFound>().having(
              (e) => e.message,
              'message',
              'No devices in room "Garage" with device type "OvenDevice".',
            ),
          ),
        );
      });
    });
  });

  group('home write access', () {
    test('serves the live device maps, so a write is seen by every read', () {
      final read = database.homeFor('ana')['devices']! as List<Object?>;

      expect(read.first, same(database.homeDevices.first));
      expect(database.homeGroups, hasLength(1));
    });

    test('scenes are the automations marked as scenes', () {
      expect(database.scenes, isEmpty);
    });

    test('serves to-do lists to their owners and recipients', () {
      expect(_ids(database.todoLists), ['shopping', 'chores']);
      expect(_ids(database.todosFor('ana')['lists']), ['shopping']);
      expect(_ids(database.todosFor('marco')['lists']), ['shopping', 'chores']);
      expect(database.todosFor('ana')['source'], 'Synthetic');
      expect(
        () => database.todosFor('nobody'),
        throwsA(isA<MockDataNotFound>()),
      );
    });

    test('has no to-do lists unless told otherwise', () {
      final bare = MockDatabase(
        users: {'users': <Map<String, dynamic>>[]},
        home: <String, dynamic>{},
      );
      expect(bare.todoLists, isEmpty);
    });
  });

  group('MockDatabase.load', () {
    test('reads every file from the directory through the loader', () async {
      final paths = <String>[];
      final loaded = await MockDatabase.load(
        directory: 'somewhere',
        loader: (path) async {
          paths.add(path);
          return jsonEncode(_files[path.split('/').last]);
        },
      );

      expect(paths, [
        'somewhere/users.json',
        'somewhere/google_home.json',
        'somewhere/calendar.json',
        'somewhere/recipe_timeline.json',
        'somewhere/trips.json',
        'somewhere/todos.json',
        'somewhere/bakery.json',
        'somewhere/inbox.json',
      ]);
      expect(loaded.listUsers(), hasLength(2));
    });

    test('reads from disk by default', () async {
      final directory = Directory.systemTemp.createTempSync('mock_db_');
      addTearDown(() => directory.deleteSync(recursive: true));
      _files.forEach((name, document) {
        File('${directory.path}/$name').writeAsStringSync(jsonEncode(document));
      });

      final loaded = await MockDatabase.load(directory: directory.path);

      expect(loaded.findUser('ana'), isNotNull);
    });

    test('reads a profile photo for the users that have one', () async {
      final directory = Directory.systemTemp.createTempSync('mock_db_');
      addTearDown(() => directory.deleteSync(recursive: true));
      File('${directory.path}/ana.jpg').writeAsBytesSync([1, 2, 3]);

      final loaded = await MockDatabase.load(
        directory: 'somewhere',
        photoDirectory: directory.path,
        loader: (path) async => jsonEncode(_files[path.split('/').last]),
      );

      expect(loaded.listProfiles(), [
        {
          'id': 'ana',
          'name': 'Ana',
          'role': 'Host',
          'photo': base64Encode([1, 2, 3]),
        },
        {'id': 'marco', 'name': 'Marco', 'role': 'Logistics'},
      ]);
      expect(loaded.listUsers().first, isNot(contains('photo')));
      expect(loaded.findUser('ana'), isNot(contains('photo')));
    });

    test('fails when a file is missing', () {
      expect(
        MockDatabase.load(directory: 'does_not_exist'),
        throwsA(isA<FileSystemException>()),
      );
    });
  });

  group('the shipped data', () {
    late MockDatabase shipped;

    setUp(() async {
      shipped = await MockDatabase.load();
    });

    test('lists Ana and Marco, the two people in the timeline', () {
      expect(shipped.listUsers().map((u) => u['id']), ['ana', 'marco']);
    });

    test('has a photo for both', () {
      final photos = {
        for (final user in shipped.listProfiles())
          user['id']: user.containsKey('photo'),
      };

      expect(photos, {'ana': true, 'marco': true});
    });

    test('starts on Saturday at 7:30 AM', () {
      expect(shipped.clock.nowIso, '2026-10-10T07:30:00');
      expect(shipped.homeFor('ana')['now'], '2026-10-10T07:30:00');
    });

    test('serves every user a full home model', () {
      for (final user in shipped.listUsers()) {
        final home = shipped.homeFor(user['id']! as String);
        expect(
          (home['structure']! as Map)['name'],
          'Rivera Home',
        );
        expect(home['devices'], isNotEmpty);
      }
    });

    test('keeps only the dinner party scene as an automation', () {
      expect(_ids(shipped.homeFor('ana')['automations']), ['dinner_party']);
      expect(shipped.homeFor('marco')['automations'], isEmpty);
    });

    test('has exactly the devices the timeline uses', () {
      expect(
        shipped.homeDevices.map((d) => d['id']),
        [
          'oven',
          'fridge',
          'table_lights',
          'dining_speaker',
          'thermostat',
          'car',
          'front_door',
          'doorbell',
        ],
      );
    });

    test('has the dinner party scene, ready to start', () {
      expect(shipped.scenes.single, containsPair('state', 'ready'));
      expect(shipped.scenes.single['name'], 'Dinner party scene');
    });

    test(
      'serves the shopping list to its owner and to who it is shared with',
      () {
        final lists = shipped.todosFor('ana')['lists']! as List<Object?>;
        expect((lists.single! as Map)['items'], hasLength(5));
        expect(shipped.todosFor('marco')['lists'], isEmpty);
        shipped.todoLists.single['sharedWith'] = ['marco'];
        expect(shipped.todosFor('marco')['lists'], hasLength(1));
      },
    );
  });
}
