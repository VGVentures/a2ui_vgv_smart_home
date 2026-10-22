import 'package:home_backend/data/mock_database.dart';
import 'package:home_backend/scenario/bakery_service.dart';
import 'package:home_backend/scenario/calendar_service.dart';
import 'package:home_backend/scenario/inbox_service.dart';
import 'package:home_backend/scenario/oven_service.dart';
import 'package:home_backend/scenario/recipe_service.dart';
import 'package:home_timeline/home_timeline.dart';

/// {@template dinner_planner}
/// Moves the dinner when the guests come earlier or later.
/// {@endtemplate}
///
/// This is the demo's one place where a single request fans out over several
/// services. Moving the guests is not one write: it changes the calendar, the
/// recipe plan and the oven programme, tells the bakery, and, through the
/// engine, changes what Marco's route looks like. It also tells the people the
/// move concerns, through the inbox. [moveGuests] does each step in order and
/// returns them all as `effects`, so a model (and a reader of the log) can see
/// exactly what a request touched.
class DinnerPlanner {
  /// {@macro dinner_planner}
  ///
  /// Creates a planner over the services it fans out to.
  DinnerPlanner(
    this._database,
    this._calendar,
    this._recipe,
    this._oven,
    this._bakery,
    this._inbox,
    this._reconcile,
  );

  final MockDatabase _database;
  final CalendarService _calendar;
  final RecipeService _recipe;
  final OvenService _oven;
  final BakeryService _bakery;
  final InboxService _inbox;

  /// Brings derived state up to date after the writes.
  final void Function() _reconcile;

  /// Moves the guests' arrival to [arrival] (`HH:mm`) or by [shiftMinutes]
  /// (negative for earlier), and moves everything that hangs off it by the
  /// same amount.
  ///
  /// [requestedBy] is who asked, and defaults to whoever owns the dinner. The
  /// other people the dinner is assigned to are told in their inbox what moved
  /// and what it means for their day.
  ///
  /// Throws [MockDataNotFound] when neither or both are given, for a time that
  /// is not `HH:mm`, for an unknown [requestedBy], or for an arrival that is
  /// not after the scenario's now.
  Map<String, Object?> moveGuests({
    String? arrival,
    int? shiftMinutes,
    String? requestedBy,
  }) {
    if ((arrival == null) == (shiftMinutes == null)) {
      throw const MockDataNotFound(
        'Give exactly one of new_arrival (HH:mm) or shift_minutes.',
      );
    }
    final event = _calendar.guestsEvent();
    final requester = requestedBy ?? event['userId']! as String;
    _database.requireUser(requester);
    final before = parseWall(event['start'] as String);
    final now = _database.clock.now;
    final after = shiftMinutes != null
        ? before.add(Duration(minutes: shiftMinutes))
        : _parseArrival(arrival!, now);
    if (!after.isAfter(now)) {
      throw MockDataNotFound(
        'Guests cannot arrive at ${clock12(after)}, it is ${clock12(now)} '
        'now.',
      );
    }
    final delta = after.difference(before);
    if (delta == Duration.zero) {
      return {
        'summary': 'The guests already arrive at ${clock12(after)}.',
        'changed': false,
        'effects': <Object?>[],
      };
    }
    final effects = [
      _calendar.moveEvent(event['id'] as String, after),
      _recipe.shift(delta),
      _oven.shift(delta),
      _bakery.notifyGuestsArrival(after, before),
    ];
    _reconcile();
    effects.addAll([
      for (final person in _database.assigneesOf(event))
        if (person != requester)
          _notify(person, requester, before: before, after: after),
    ]);
    return {
      'summary':
          'Guests now arrive at ${clock12(after)} (was ${clock12(before)}). '
          'The calendar, the recipe plan and the oven were moved by '
          '${delta.inMinutes} minutes.',
      'changed': true,
      'effects': effects,
      'trips': [
        for (final trip in _database.tripRows)
          {
            'id': trip['id'],
            'userId': trip['userId'],
            'leaveBy': trip['leaveBy'],
            'homeArrivalAt': trip['homeArrivalAt'],
            'homeAfterGuestsArrive': trip['homeAfterGuestsArrive'],
            'notes': trip['notes'],
          },
      ],
    };
  }

  /// Writes what the move means for [person] in their inbox.
  ///
  /// When it leaves their route home after the guests, and the bakery can
  /// bring the cake instead, the item carries that as its `suggestion`.
  Map<String, Object?> _notify(
    String person,
    String requester, {
    required DateTime before,
    required DateTime after,
  }) {
    final name = _database.requireUser(requester)['name'] as String;
    final moved =
        '$name moved the dinner party from ${clock12(before)} to '
        '${clock12(after)}.';
    final trip = _lateTrip(person);
    final canDeliver = trip != null && _canDeliver(person, trip);
    final options = _bakery.deliveryOptions();
    final slots = (options['slots']! as List<Object?>)
        .cast<Map<String, Object?>>();
    final arrival = trip == null ? null : trip['homeArrivalRange'] as String;
    return _inbox.post(
      to: person,
      from: requester,
      kind: 'plan_change',
      title: 'Dinner moved to ${clock12(after)}',
      body: trip == null
          ? moved
          : '$moved Your route now gets you home at $arrival, after the '
                'guests arrive.',
      suggestion: canDeliver && slots.isNotEmpty
          ? {
              'tool': 'request_bakery_delivery',
              'label': 'Have the bakery deliver the cake',
              'reason':
                  'The pickup would put you home at $arrival, after the '
                  'guests. A delivery drops the bakery stop from your route.',
              'deliveryMinutes': options['durationMinutes'],
              'defaultSlot': options['defaultSlot'],
              'slots': slots,
            }
          : null,
    );
  }

  /// [person]'s trip when it now gets them home after the guests arrive.
  Map<String, dynamic>? _lateTrip(String person) {
    for (final trip in _database.tripRows) {
      if (trip['userId'] == person && trip['homeAfterGuestsArrive'] == true) {
        return trip;
      }
    }
    return null;
  }

  /// Whether the bakery can still take [person]'s cake pickup off their trip.
  bool _canDeliver(String person, Map<String, dynamic> trip) {
    final planned = (trip['plannedStops'] as List<dynamic>)
        .cast<Map<String, dynamic>>();
    final orders = (_database.bakery['orders'] as List<dynamic>)
        .cast<Map<String, dynamic>>();
    return planned.any((stop) => stop['droppedWhenDelivered'] == true) &&
        !orders.any((order) => order['userId'] == person);
  }

  DateTime _parseArrival(String arrival, DateTime now) {
    if (!RegExp(r'^([01]\d|2[0-3]):[0-5]\d$').hasMatch(arrival)) {
      throw MockDataNotFound('"$arrival" is not a time. Use HH:mm, 24 hour.');
    }
    return atHhmm(now, arrival);
  }
}
