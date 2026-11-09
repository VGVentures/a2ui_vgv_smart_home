import 'package:home_backend/data/mock_database.dart';
import 'package:home_timeline/home_timeline.dart';

/// {@template trip_service}
/// The mocked Maps route planner.
/// {@endtemplate}
///
/// A trip's stops, leave-by time and mileage are not stored by hand: they are
/// planned from the calendar events the stops point at, from whether the bakery
/// delivers, and from the car's range. [replan] recomputes them, so the route
/// is right after any change to the day.
class TripService {
  /// {@macro trip_service}
  ///
  /// Creates a trip service over the mock database.
  TripService(this._database);

  final MockDatabase _database;

  /// Recomputes every trip. [bakeryDelivers] says whether the bakery brings
  /// the cake, which drops the stops marked `droppedWhenDelivered`.
  void replan({required bool bakeryDelivers}) {
    for (final trip in _database.tripRows) {
      _replanOne(trip, bakeryDelivers: bakeryDelivers);
    }
  }

  void _replanOne(Map<String, dynamic> trip, {required bool bakeryDelivers}) {
    final plannedStops = trip['plannedStops'];
    if (plannedStops is! List<dynamic>) return;
    final planned = plannedStops.cast<Map<String, dynamic>>();
    final stops = <Map<String, Object?>>[];
    var miles = 0;
    int? earliestHome;
    int? latestHome;
    for (final stop in planned) {
      if (bakeryDelivers && stop['droppedWhenDelivered'] == true) continue;
      stops.add({
        'name': stop['name'],
        'arriveBy': _eventStart(stop['calendarEventId'] as String),
        'driveMinutes': stop['driveMinutes'],
        'miles': stop['miles'],
      });
      miles += stop['miles'] as int;
      // Only the last stop sets how long the way home takes: its wait, if
      // any, and the drive, soonest and latest.
      earliestHome = stop['homeAfterMinutes'] as int?;
      latestHome = stop['homeAfterMaxMinutes'] as int? ?? earliestHome;
    }
    if (stops.isEmpty) return;
    final home = trip['home'] as Map<String, dynamic>;
    final first = stops.first;
    final last = stops.last;
    final lastArrival = parseWall(last['arriveBy']! as String);
    final driveHome = home['driveMinutes'] as int;
    final homeArrival = lastArrival.add(
      Duration(minutes: earliestHome ?? driveHome),
    );
    final homeLatest = lastArrival.add(
      Duration(minutes: latestHome ?? driveHome),
    );
    miles += home['miles'] as int;
    stops.add({
      'name': 'Home',
      'arriveBy': wallIso(homeArrival),
      'arriveByRange': homeRange(homeArrival, homeLatest),
      'driveMinutes': home['driveMinutes'],
      'miles': home['miles'],
    });
    for (final stop in stops) {
      stop['arriveByLabel'] =
          stop['arriveByRange'] ??
          clock12(parseWall(stop['arriveBy']! as String));
    }
    trip['stops'] = stops;
    final leaveBy = parseWall(
      first['arriveBy']! as String,
    ).subtract(Duration(minutes: first['driveMinutes']! as int));
    trip['leaveBy'] = wallIso(leaveBy);
    trip['leaveByLabel'] = clock12(leaveBy);
    trip['homeArrivalAt'] = wallIso(homeArrival);
    trip['homeArrivalLatestAt'] = wallIso(homeLatest);
    trip['homeArrivalRange'] = homeRange(homeArrival, homeLatest);
    trip['title'] = bakeryDelivers
        ? trip['deliveredTitle'] ?? trip['title']
        : trip['plannedTitle'] ?? trip['title'];
    trip['totalMiles'] = miles;
    trip['itinerary'] = _itinerary(trip, leaveBy);
    trip['rangeCheck'] = _rangeCheck(miles, stops.length - 1);
    _noteGuests(trip, homeArrival, homeLatest);
  }

  /// The whole stretch of a person's day the trip touches, in time order: when
  /// to leave, each stop, getting home, and every other event of theirs after
  /// they leave (the guests, a delivery). At most [_itineraryLimit] entries,
  /// the earliest dropped first.
  List<Map<String, Object?>> _itinerary(
    Map<String, dynamic> trip,
    DateTime leaves,
  ) {
    final entries = <(DateTime, Map<String, Object?>)>[
      (
        leaves,
        {'time': clock12(leaves), 'title': 'Leave home', 'detail': null},
      ),
    ];
    final stops = (trip['stops'] as List<dynamic>).cast<Map<String, dynamic>>();
    final planned = {
      for (final stop in (trip['plannedStops'] as List<dynamic>))
        (stop as Map<String, dynamic>)['name']: stop,
    };
    for (final stop in stops) {
      final at = parseWall(stop['arriveBy']! as String);
      final home = stop['name'] == 'Home';
      final queue = planned[stop['name']]?['note'];
      entries.add((
        at,
        {
          'time': home ? stop['arriveByRange'] : clock12(at),
          'title': stop['name'],
          'detail': home
              ? '${stop['driveMinutes']} min drive'
              : [
                  '${stop['driveMinutes']} min drive',
                  ?queue,
                ].join(' · '),
        },
      ));
    }
    final stopEvents = {
      for (final stop in planned.values) stop['calendarEventId'],
    };
    for (final event in _database.calendarEvents) {
      final start = parseWall(event['start'] as String);
      if (event['status'] == 'cancelled' ||
          stopEvents.contains(event['id']) ||
          start.isBefore(leaves) ||
          !_database.assigneesOf(event).contains(trip['userId'])) {
        continue;
      }
      entries.add((
        start,
        {
          'time': event['detail'] == null
              ? clock12(start)
              : homeRange(start, parseWall(event['end'] as String)),
          'title': event['kind'] == 'guests_arrive'
              ? 'Guests arrive'
              : event['title'],
          'detail': event['detail'],
        },
      ));
    }
    // What is already over is history, not part of the itinerary.
    final now = _database.clock.now;
    entries
      ..removeWhere((entry) => entry.$1.isBefore(now))
      ..sort((a, b) => a.$1.compareTo(b.$1));
    final kept = entries.length > _itineraryLimit
        ? entries.sublist(entries.length - _itineraryLimit)
        : entries;
    return [for (final entry in kept) entry.$2];
  }

  static const _itineraryLimit = 5;

  Map<String, Object?> _rangeCheck(int miles, int stopCount) {
    final battery =
        (_database.deviceOrNull('car')?['traits']
                as Map<String, dynamic>?)?['Battery']
            as Map<String, dynamic>?;
    final range = battery?['rangeMiles'] as num? ?? 0;
    final enough = range >= miles;
    return {
      'carRangeMiles': range,
      'neededMiles': miles,
      'enough': enough,
      'summary': enough
          ? (stopCount > 1
                ? 'Enough range for both stops'
                : 'Enough range for the trip')
          : 'Not enough range for the trip',
    };
  }

  void _noteGuests(
    Map<String, dynamic> trip,
    DateTime homeArrival,
    DateTime homeLatest,
  ) {
    DateTime? guests;
    for (final event in _database.calendarEvents) {
      if (event['kind'] == 'guests_arrive') {
        guests = parseWall(event['start'] as String);
      }
    }
    final late = guests != null && homeArrival.isAfter(guests);
    trip['homeAfterGuestsArrive'] = late;
    trip['notes'] = <String>[
      if (late) _lateNote(homeArrival, homeLatest, guests),
    ];
  }

  String _lateNote(
    DateTime homeArrival,
    DateTime homeLatest,
    DateTime guests,
  ) =>
      'Home at ${homeRange(homeArrival, homeLatest)} is after the guests '
      'arrive at ${clock12(guests)}.';

  /// "6:30–6:45 PM" for a window, or "6:30 PM" when there is none.
  static String homeRange(DateTime earliest, DateTime latest) {
    if (earliest == latest) return clock12(earliest);
    final first = clock12(earliest);
    return '${first.substring(0, first.length - 3)}–${clock12(latest)}';
  }

  String _eventStart(String eventId) {
    for (final event in _database.calendarEvents) {
      if (event['id'] == eventId) return event['start'] as String;
    }
    throw MockDataNotFound('A trip stop points at a missing event $eventId.');
  }
}
