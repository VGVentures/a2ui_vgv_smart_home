import 'package:home_timeline/src/feed_rules.dart';
import 'package:home_timeline/src/feed_source.dart';
import 'package:home_timeline/src/wall_time.dart';

/// {@template activity_feed}
/// What just happened and what comes next, for the model to rank a screen by.
///
/// It is derived, never stored: every moment is read from the schedules and
/// states the demo already holds (the oven programme, the bakery order, the
/// plan, the calendar, the doorbell) and compared with the scenario clock. So
/// it is right after a rewind, and a rescheduled preheat moves in it too.
///
/// A moment before now is `recent`, newest first, and only the ones from the
/// last `recentMinutes` count. A moment after is `next`, soonest first, within
/// `nextMinutes`. What each moment says is declared in `feed_rules.json`.
///
/// It reads `source`, with `rules` or the ones this package ships.
/// {@endtemplate}
class ActivityFeed {
  /// {@macro activity_feed}
  ActivityFeed(this._source, {FeedRules? rules})
    : _rules = rules ?? FeedRules.bundled();

  /// How long a courier at the door stays something to act on, as long as the
  /// doorbell keeps showing it.
  static const arrivalWindow = Duration(minutes: 15);

  final FeedSource _source;
  final FeedRules _rules;

  /// The feed as of the scenario clock, for [userId].
  ///
  /// A moment names the device, plan step, order or event it is about, so a
  /// screen can point at it. `subject` is the user it concerns, or `household`.
  Map<String, Object?> forUser(String userId) {
    _source.userName(userId);
    final now = _source.now;
    final facts = _facts(now);
    final moments =
        <Map<String, Object?>>[
            for (final rule in _rules.rules)
              for (final fact
                  in facts[rule.source] ?? const <Map<String, Object?>>[])
                ?rule.moment(fact),
          ]
          ..removeWhere((m) {
            final subject = m['subject'];
            // What someone did only counts once the clock has reached it.
            if (m['pastOnly']! as bool && (m['at']! as DateTime).isAfter(now)) {
              return true;
            }
            return subject != 'household' && subject != userId;
          })
          ..sort(
            (a, b) => (a['at']! as DateTime).compareTo(b['at']! as DateTime),
          );
    final recent = moments
        .where((m) {
          final at = m['at']! as DateTime;
          return !at.isAfter(now) && now.difference(at) <= _rules.recentWindow;
        })
        .toList()
        .reversed;
    final next = moments.where((m) {
      final at = m['at']! as DateTime;
      // An unfinished list is on the screen however far off its deadline is.
      if (m['alwaysNext']! as bool) return at.isAfter(now);
      return at.isAfter(now) && at.difference(now) <= _rules.nextWindow;
    });
    return {
      'now': wallIso(now),
      'nowLabel': clock12(now),
      'recent': _render(recent, now),
      'next': _render(next, now),
    };
  }

  List<Map<String, Object?>> _render(
    Iterable<Map<String, Object?>> moments,
    DateTime now,
  ) => [
    for (final m in moments)
      {
        'at': wallIso(m['at']! as DateTime),
        'time': clock12(m['at']! as DateTime),
        if (m['at']! as DateTime case final at
            when at.isBefore(now) || at == now)
          'minutesAgo': now.difference(at).inMinutes
        else
          'inMinutes': (m['at']! as DateTime).difference(now).inMinutes,
        'kind': m['kind'],
        'summary': m['summary'],
        if (m['deviceId'] != null) 'deviceId': m['deviceId'],
        if (m['stepId'] != null) 'stepId': m['stepId'],
        if (m['listId'] != null) 'listId': m['listId'],
        if (m['tripId'] != null) 'tripId': m['tripId'],
        if (m['itinerary'] != null) 'itinerary': m['itinerary'],
        if (m['urgent']! as bool) 'urgent': true,
        if (m['by'] != null) 'by': m['by'],
      },
  ];

  /// The facts the rules read, by the source each belongs to.
  Map<String, List<Map<String, Object?>>> _facts(DateTime now) => {
    'oven': _oven(now),
    'planStep': _planSteps(now),
    'todoList': _todoLists(now),
    'bakeryOrder': _bakeryOrders(now),
    'trip': _trips(now),
    'calendarEvent': _calendarEvents(),
    'doorbell': _doorbell(),
    'change': _changes(),
    'inboxItem': _inboxItems(),
  };

  List<Map<String, Object?>> _oven(DateTime now) {
    final traits = _source.device('oven')?['traits'] as Map<String, dynamic>?;
    final cook = traits?['CookSchedule'] as Map<String, dynamic>?;
    final control = traits?['TemperatureControl'] as Map<String, dynamic>?;
    final start = control?['scheduledStart'] as String?;
    if (cook == null || start == null) return const [];
    final roastIn = cook['roastInAt'] as String?;
    final done = cook['doneAt'] as String?;
    return [
      {
        'target': control!['temperatureSetpointF'],
        'preheat': atHhmm(now, start),
        'ready': atHhmm(now, cook['readyAt'] as String? ?? start),
        'roastIn': roastIn == null ? null : atHhmm(now, roastIn),
        'done': done == null ? null : atHhmm(now, done),
      },
    ];
  }

  /// The plan is what is still to do: a step that is done is history, and it
  /// never reaches a card that lists the plan.
  List<Map<String, Object?>> _planSteps(DateTime now) => [
    for (final step in _source.recipeSteps)
      if (step['done'] != true)
        {
          'at': atHhmm(now, step['at'] as String),
          'step': step['step'],
          'userId': step['userId'],
          'stepId': step['id'],
        },
  ];

  /// A to-do list with items left is a deadline, not background: it is due
  /// before the plan step it names (`dueBeforeStep`, the cooking starting), so
  /// it shows up as an urgent moment at that time, with the items still to
  /// get, once for each of its owners. Once everything is ticked it is gone.
  List<Map<String, Object?>> _todoLists(DateTime now) {
    final facts = <Map<String, Object?>>[];
    for (final list in _source.todoLists) {
      final stepId = list['dueBeforeStep'] as String?;
      final step = _source.recipeSteps
          .where((s) => s['id'] == stepId)
          .firstOrNull;
      final items = list['items'] as List<dynamic>? ?? const <Object?>[];
      final left = [
        for (final item in items.cast<Map<String, dynamic>>())
          if (item['checked'] != true) item['label'] as String,
      ];
      if (step == null || left.isEmpty) continue;
      final deadline = atHhmm(now, step['at'] as String);
      for (final owner in (list['owners'] as List<dynamic>).cast<String>()) {
        facts.add({
          // Past its deadline the list is due now, not history.
          'dueAt': deadline.isAfter(now)
              ? deadline
              : now.add(const Duration(minutes: 1)),
          'title': list['title'],
          'stepName': (step['step']! as String).toLowerCase(),
          'left': left.length,
          'total': items.length,
          'itemsLeft': left.join(', '),
          'owner': owner,
          'listId': list['id'],
          'stepId': stepId,
        });
      }
    }
    return facts;
  }

  /// An order is the household's business, not only the person who placed
  /// it: the one at home tracks the cake too. Only the request itself is the
  /// requester's.
  List<Map<String, Object?>> _bakeryOrders(DateTime now) => [
    for (final order in _source.orders)
      {
        'userId': order['userId'],
        'item': (order['item'] as String).toLowerCase(),
        'itemName': order['item'],
        'bakeryName': order['bakeryName'],
        'requestedAt': parseWall(order['requestedAt'] as String),
        'confirmsAt': parseWall(order['confirmsAt'] as String),
        'departsAt': parseWall(order['departsAt'] as String),
        'eta': parseWall(order['eta'] as String),
        'now': now,
        'minutes': order['durationMinutes'],
        'status': order['status'],
        'statusLabel': order['statusLabel'],
        'progress': order['progressPercent'],
        'departsAtLabel': order['departsAtLabel'],
        'etaLabel': order['etaLabel'],
        'minutesLeft': parseWall(
          order['eta'] as String,
        ).difference(now).inMinutes,
        // The courier is at the door for as long as the doorbell shows it.
        'atTheDoor':
            !now.isBefore(parseWall(order['eta'] as String)) &&
            now.difference(parseWall(order['eta'] as String)) < arrivalWindow,
        // From the request until the courier leaves, the order is tracked too,
        // by everyone it concerns, at the start of its bar.
        'waiting':
            order['status'] == 'pending' || order['status'] == 'confirmed',
        'onTheRoad': order['status'] == 'out_for_delivery',
      },
  ];

  /// A trip is the itinerary of the person driving it: when to leave and every
  /// stop. When it gets them home after the guests, that is an urgent moment,
  /// right now, for the person driving it only: they are the one affected, and
  /// whoever moved the guests sees just their own change summary.
  List<Map<String, Object?>> _trips(DateTime now) {
    final facts = <Map<String, Object?>>[];
    for (final trip in _source.trips) {
      final userId = trip['userId'] as String;
      final stops = (trip['stops'] as List<dynamic>)
          .cast<Map<String, dynamic>>();
      final leaveBy = trip['leaveBy'] as String?;
      if (stops.isEmpty || leaveBy == null) continue;
      final route = stops
          .map((stop) {
            final time = stop['name'] == 'Home'
                ? trip['homeArrivalRange']
                : clock12(parseWall(stop['arriveBy']! as String));
            return '${stop['name']} $time';
          })
          .join(' → ');
      final dropped = [
        for (final stop in trip['plannedStops'] as List<dynamic>)
          if ((stop as Map<String, dynamic>)['droppedWhenDelivered'] == true)
            stop['name'],
      ];
      // The itinerary stays in front of the person until they are home, not
      // only until they leave.
      final leaves = parseWall(leaveBy);
      final home = parseWall(trip['homeArrivalAt']! as String);
      facts.add({
        'userId': userId,
        'tripId': trip['id'],
        'name': _source.userName(userId),
        'leaveBy': leaves,
        'route': route,
        'itinerary': trip['itinerary'],
        'itineraryAt': now.isBefore(leaves) || !now.isBefore(home)
            ? leaves
            : now,
        'now': now,
        'homeAfterGuests': trip['homeAfterGuestsArrive'] == true,
        'notes': (trip['notes'] as List<dynamic>).join(' '),
        'droppedStops': dropped.isEmpty
            ? ''
            : ' The ${dropped.join(', ')} stop is the cause: the bakery can '
                  'deliver the cake instead.',
      });
    }
    return facts;
  }

  /// Each calendar event, once for everyone it is assigned to, so the next
  /// pickup shows up in the feed of the person who has to make it.
  List<Map<String, Object?>> _calendarEvents() => [
    for (final event in _source.calendarEvents)
      if (event['status'] != 'cancelled')
        for (final person in _source.assigneesOf(event))
          {
            'start': parseWall(event['start'] as String),
            'person': person,
            'text': event['kind'] == 'guests_arrive'
                ? 'Guests arrive'
                : event['detail'] == null
                ? event['title']
                : '${event['title']}: ${event['detail']}',
          },
  ];

  List<Map<String, Object?>> _doorbell() {
    final traits =
        _source.device('doorbell')?['traits'] as Map<String, dynamic>?;
    final press = traits?['DoorbellPress'] as Map<String, dynamic>?;
    final pressedAt = press?['lastPressAt'] as String?;
    if (pressedAt == null) return const [];
    final event = traits!['DoorbellEvent'] as Map<String, dynamic>;
    return [
      {
        'pressedAt': parseWall(pressedAt),
        'label': event['label'] ?? 'The doorbell rang',
      },
    ];
  }

  /// The changes people asked for, kept in the bakery's message log.
  List<Map<String, Object?>> _changes() => [
    for (final message in _source.bakeryMessages)
      {'at': parseWall(message['at'] as String), 'text': message['text']},
  ];

  /// The notifications other people sent, as what just happened to the person
  /// they are for. An unread item stays in the inbox long after this window.
  List<Map<String, Object?>> _inboxItems() => [
    for (final item in _source.inboxItems)
      {
        'at': parseWall(item['at'] as String),
        'title': item['title'],
        'userId': item['userId'],
        'from': item['from'],
      },
  ];
}
