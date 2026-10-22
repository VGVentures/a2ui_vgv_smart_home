import 'dart:convert';
import 'dart:io';

import 'package:home_timeline/home_timeline.dart';

/// Reads the text of the file at a path. Injected so tests need no real files.
typedef TextLoader = Future<String> Function(String path);

/// {@template mock_data_not_found}
/// Thrown when a lookup matches nothing. The message names what is available
/// so a model calling a tool can recover.
/// {@endtemplate}
class MockDataNotFound implements Exception {
  /// {@macro mock_data_not_found}
  ///
  /// Creates a [MockDataNotFound] with a human-readable [message].
  const MockDataNotFound(this.message);

  /// What was not found and what exists instead.
  final String message;

  @override
  String toString() => message;
}

/// {@template mock_database}
/// The demo's mock database: the household's users, its Google Home data
/// model, and the Calendar and Maps data around it, loaded once
/// from JSON files and served from memory.
/// {@endtemplate}
///
/// Each source is its own document, matching the system that owns it in the
/// real world. Only the home document is Google Home data.
///
/// The documents are the demo's whole mutable state. A snapshot of them is
/// taken when the database is built, and [reset] restores it together with the
/// scenario [clock], so the demo can always return to its first state.
class MockDatabase {
  /// {@macro mock_database}
  ///
  /// Creates a database from already decoded documents.
  ///
  /// `users` and `home` are required. The others default to empty documents so
  /// a test only supplies the sources it exercises.
  MockDatabase({
    required Map<String, dynamic> users,
    required this._home,
    this._calendar = const {'events': <Object?>[]},
    this._recipeTimeline = const {'steps': <Object?>[]},
    this._trips = const {'trips': <Object?>[]},
    this._todos = const {'lists': <Object?>[]},
    this._bakery = const {'orders': <Object?>[], 'messages': <Object?>[]},
    this._photos = const {},
    Map<String, dynamic>? inbox,
    ScenarioClock? clock,
  }) : _users = (users['users'] as List<dynamic>).cast<Map<String, dynamic>>(),
       _inbox = inbox ?? {'items': <Object?>[]},
       clock =
           clock ??
           ScenarioClock(
             _startOf(_home),
           ) {
    _pristine = jsonEncode(_documents());
  }

  /// Reads `users.json`, `google_home.json`, `calendar.json`,
  /// `recipe_timeline.json`, `trips.json`, `bakery.json`, `inbox.json`,
  /// and `todos.json` from [directory].
  ///
  /// Throws when a file is missing or is not valid JSON so the server fails at
  /// boot rather than on the first request.
  ///
  /// A user's profile photo is the optional `<id>.jpg` in [photoDirectory].
  static Future<MockDatabase> load({
    String directory = 'data',
    String photoDirectory = 'assets/photos',
    TextLoader? loader,
  }) async {
    final read = loader ?? (path) => File(path).readAsString();
    Future<Map<String, dynamic>> decode(String name) async =>
        jsonDecode(await read('$directory/$name')) as Map<String, dynamic>;
    final users = await decode('users.json');
    final photos = <String, String>{};
    for (final user in users['users'] as List<dynamic>) {
      final id = (user as Map<String, dynamic>)['id'] as String;
      final file = File('$photoDirectory/$id.jpg');
      if (file.existsSync()) photos[id] = base64Encode(file.readAsBytesSync());
    }
    return MockDatabase(
      users: users,
      photos: photos,
      home: await decode('google_home.json'),
      calendar: await decode('calendar.json'),
      recipeTimeline: await decode('recipe_timeline.json'),
      trips: await decode('trips.json'),
      todos: await decode('todos.json'),
      bakery: await decode('bakery.json'),
      inbox: await decode('inbox.json'),
    );
  }

  /// The scenario clock. Everything time dependent reads it.
  final ScenarioClock clock;

  List<Map<String, dynamic>> _users;
  Map<String, dynamic> _home;
  Map<String, dynamic> _calendar;
  Map<String, dynamic> _recipeTimeline;
  Map<String, dynamic> _trips;
  Map<String, dynamic> _todos;
  Map<String, dynamic> _bakery;
  Map<String, dynamic> _inbox;
  final Map<String, String> _photos;
  late final String _pristine;

  Map<String, Object?> _documents() => {
    'users': _users,
    'home': _home,
    'calendar': _calendar,
    'recipeTimeline': _recipeTimeline,
    'trips': _trips,
    'todos': _todos,
    'bakery': _bakery,
    'inbox': _inbox,
  };

  /// Restores every document to how it was when the database was built, and
  /// puts the [clock] back at the start.
  ///
  /// The restored maps are new objects, so nothing may hold a map from before
  /// the reset: read through the getters again.
  void reset() {
    final docs = jsonDecode(_pristine) as Map<String, dynamic>;
    Map<String, dynamic> doc(String key) => docs[key] as Map<String, dynamic>;
    _users = (docs['users'] as List<dynamic>).cast<Map<String, dynamic>>();
    _home = doc('home');
    _calendar = doc('calendar');
    _recipeTimeline = doc('recipeTimeline');
    _trips = doc('trips');
    _todos = doc('todos');
    _bakery = doc('bakery');
    _inbox = doc('inbox');
    clock.reset();
  }

  /// Every user as `{id, name, role}`, in file order.
  List<Map<String, Object?>> listUsers() => [
    for (final user in _users)
      {'id': user['id'], 'name': user['name'], 'role': user['role']},
  ];

  /// Every user as [listUsers] does, plus the base64 `photo` of those who have
  /// one.
  ///
  /// For the client's profile toggle only. The photo stays out of [listUsers]
  /// and [findUser], which feed the model's tools.
  List<Map<String, Object?>> listProfiles() => [
    for (final user in listUsers())
      {
        ...user,
        if (_photos[user['id']] case final photo?) 'photo': photo,
      },
  ];

  /// The full record of the user with [id], or `null` when there is none.
  Map<String, dynamic>? findUser(String id) {
    for (final user in _users) {
      if (user['id'] == id) return user;
    }
    return null;
  }

  /// The full record of the user with [id].
  ///
  /// Throws [MockDataNotFound] when there is none.
  Map<String, dynamic> requireUser(String id) =>
      findUser(id) ?? (throw MockDataNotFound(_unknownUser(id)));

  /// The Google Home data model as one user sees it.
  ///
  /// Devices, rooms and groups are household wide. Automations are narrowed to
  /// the ones [userId] owns. [room] and [deviceType] narrow the devices,
  /// matched without regard to case against a room id or name and a Home APIs
  /// device type.
  ///
  /// Throws [MockDataNotFound] for an unknown user, room or device type.
  Map<String, Object?> homeFor(
    String userId, {
    String? room,
    String? deviceType,
  }) {
    requireUser(userId);
    final rooms = _list('rooms');
    final roomId = room == null ? null : _resolveRoom(rooms, room);
    final types = {for (final d in _list('devices')) d['type'] as String};
    if (deviceType != null &&
        !types.any((t) => t.toLowerCase() == deviceType.toLowerCase())) {
      throw MockDataNotFound(
        'No device type "$deviceType". Available: ${types.join(', ')}.',
      );
    }

    final devices = [
      for (final device in _list('devices'))
        if ((roomId == null || device['room'] == roomId) &&
            (deviceType == null ||
                (device['type'] as String).toLowerCase() ==
                    deviceType.toLowerCase()))
          device,
    ];
    if (devices.isEmpty) {
      throw MockDataNotFound(
        'No devices in room "$room" with device type "$deviceType".',
      );
    }

    return {
      'now': clock.nowIso,
      'timeZone': _home['timeZone'],
      'structure': _home['structure'],
      'rooms': rooms,
      'devices': devices,
      'groups': _list('groups'),
      'automations': [
        for (final automation in _list('automations'))
          if ((automation['owners'] as List<dynamic>).contains(userId))
            automation,
      ],
    };
  }

  /// The people [event] is assigned to: its owner first, then `assignedTo`.
  List<String> assigneesOf(Map<String, dynamic> event) => [
    event['userId']! as String,
    for (final id in (event['assignedTo'] as List<dynamic>? ?? const []))
      if (id != event['userId']) id as String,
  ];

  bool _assignedTo(Map<String, dynamic> event, String userId) =>
      assigneesOf(event).contains(userId);

  /// Every calendar event of every user, as the live maps, cancelled ones
  /// included. The calendar service is their only writer.
  List<Map<String, dynamic>> get calendarEvents =>
      ((_calendar['events'] as List<dynamic>?) ?? const <Object?>[])
          .cast<Map<String, dynamic>>();

  /// Every recipe step of every user, as the live maps.
  List<Map<String, dynamic>> get recipeSteps =>
      ((_recipeTimeline['steps'] as List<dynamic>?) ?? const <Object?>[])
          .cast<Map<String, dynamic>>();

  /// Every trip of every user, as the live maps.
  List<Map<String, dynamic>> get tripRows =>
      ((_trips['trips'] as List<dynamic>?) ?? const <Object?>[])
          .cast<Map<String, dynamic>>();

  /// The bakery document, as the live map: its settings, `orders` and
  /// `messages`.
  Map<String, dynamic> get bakery => _bakery;

  /// The bakery orders of [userId], as the model's read tool serves them.
  ///
  /// {@template throws_unknown_user}
  /// Throws [MockDataNotFound] for an unknown user.
  /// {@endtemplate}
  Map<String, Object?> bakeryFor(String userId) {
    requireUser(userId);
    return {
      'source': _bakery['source'],
      'bakery': _bakery['name'],
      'deliveryMinutes': _bakery['deliveryMinutes'],
      'deliverySlots': _bakery['deliverySlots'],
      'defaultSlot': _bakery['defaultSlot'],
      'orders': [
        for (final order in _ordersConcerning(userId))
          if (order['status'] != 'future') order,
      ],
      'messages': _bakery['messages'],
    };
  }

  /// The inbox document, as the live map: its `items`. The inbox service is
  /// their only writer.
  Map<String, dynamic> get inbox => _inbox;

  /// Every inbox item of every user, as the live maps.
  List<Map<String, dynamic>> get inboxItems =>
      ((_inbox['items'] as List<dynamic>?) ?? const <Object?>[])
          .cast<Map<String, dynamic>>();

  /// The inbox of [userId]: what other people changed that concerns them,
  /// newest first, with `unread` counting the ones not read yet.
  ///
  /// An item the clock has not reached yet, after a rewind, is not there.
  ///
  /// {@macro throws_unknown_user}
  Map<String, Object?> inboxFor(String userId) {
    requireUser(userId);
    final now = clock.now;
    final items = [
      for (final item in inboxItems)
        if (item['userId'] == userId &&
            !parseWall(item['at'] as String).isAfter(now))
          item,
    ]..sort((a, b) => (b['at'] as String).compareTo(a['at'] as String));
    return {
      'source': _inbox['source'],
      'now': clock.nowIso,
      'unread': items.where((item) => item['read'] != true).length,
      'items': items,
    };
  }

  /// The home device with [id], as the live map, or `null` when there is none.
  Map<String, dynamic>? deviceOrNull(String id) {
    for (final device in homeDevices) {
      if (device['id'] == id) return device;
    }
    return null;
  }

  /// Every home device, as the live maps the read tools serve.
  ///
  /// [homeFor] returns these same maps, so a change made through them is seen
  /// by every read at once. The device state machine is the only writer; keep
  /// it that way.
  List<Map<String, dynamic>> get homeDevices => _list('devices');

  /// Every device group, as the live maps.
  List<Map<String, dynamic>> get homeGroups => _list('groups');

  /// Every scene: the automations marked `"kind": "scene"`, as the live maps.
  /// A scene carries a `state` of `ready` or `running` that the state machine
  /// flips.
  List<Map<String, dynamic>> get scenes => [
    for (final automation in _list('automations'))
      if (automation['kind'] == 'scene') automation,
  ];

  /// Every to-do list, as the live maps the state machine writes to.
  List<Map<String, dynamic>> get todoLists =>
      (_todos['lists'] as List<dynamic>).cast<Map<String, dynamic>>();

  /// The to-do lists [userId] owns or has been shared.
  ///
  /// {@macro throws_unknown_user}
  Map<String, Object?> todosFor(String userId) {
    requireUser(userId);
    return {
      'source': _todos['source'],
      'lists': [
        for (final list in todoLists)
          if ((list['owners'] as List<dynamic>).contains(userId) ||
              (list['sharedWith'] as List<dynamic>).contains(userId))
            list,
      ],
    };
  }

  /// The orders [userId] placed, and the ones whose delivery is on their
  /// calendar: the person at home tracks the cake too.
  List<Map<String, dynamic>> _ordersConcerning(String userId) => [
    for (final order
        in (_bakery['orders']! as List<dynamic>).cast<Map<String, dynamic>>())
      if (order['userId'] == userId ||
          calendarEvents.any(
            (event) =>
                event['id'] == '${order['replacesEventId']}_delivery' &&
                _assignedTo(event, userId),
          ))
        order,
  ];

  List<Map<String, dynamic>> _list(String key) =>
      ((_home[key] as List<dynamic>?) ?? const <Object?>[])
          .cast<Map<String, dynamic>>();

  /// The home document's `now`, where the scenario starts. A document without
  /// a readable one starts on the demo's Saturday at 7:30 AM.
  static DateTime _startOf(Map<String, dynamic> home) {
    final now = home['now'];
    return (now is String ? DateTime.tryParse('${now}Z') : null) ??
        parseWall('2026-10-10T07:30:00');
  }

  String _resolveRoom(List<Map<String, dynamic>> rooms, String room) {
    final wanted = room.toLowerCase();
    for (final candidate in rooms) {
      if ((candidate['id'] as String).toLowerCase() == wanted ||
          (candidate['name'] as String).toLowerCase() == wanted) {
        return candidate['id'] as String;
      }
    }
    throw MockDataNotFound(
      'No room "$room". Available: '
      '${rooms.map((r) => r['name']).join(', ')}.',
    );
  }

  String _unknownUser(String id) =>
      'No user "$id". Available: ${_users.map((u) => u['id']).join(', ')}.';
}
