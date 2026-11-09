import 'package:home_backend/data/mock_database.dart';
import 'package:home_timeline/home_timeline.dart';

/// {@template calendar_service}
/// The mocked Google Calendar write side.
/// {@endtemplate}
///
/// A tool that moves something in the day goes through here, so the calendar
/// changes in one place and in one way. The read side is
/// `MockDatabase.calendarFor`.
class CalendarService {
  /// {@macro calendar_service}
  ///
  /// Creates a calendar service over the mock database.
  CalendarService(this._database);

  final MockDatabase _database;

  /// The event with [id], as the live map.
  ///
  /// Throws [MockDataNotFound] when there is none.
  Map<String, dynamic> event(String id) {
    for (final event in _database.calendarEvents) {
      if (event['id'] == id) return event;
    }
    throw MockDataNotFound(
      'No calendar event "$id". Available: '
      '${_database.calendarEvents.map((e) => e['id']).join(', ')}.',
    );
  }

  /// The event where the guests arrive, the dinner party.
  ///
  /// Throws [MockDataNotFound] when the calendar has none.
  Map<String, dynamic> guestsEvent() {
    for (final event in _database.calendarEvents) {
      if (event['kind'] == 'guests_arrive') return event;
    }
    throw const MockDataNotFound('No event where guests arrive.');
  }

  /// Moves the event [id] to start at [start], keeping its length, and returns
  /// what changed.
  Map<String, Object?> moveEvent(String id, DateTime start) {
    final event = this.event(id);
    final from = parseWall(event['start'] as String);
    final length = parseWall(event['end'] as String).difference(from);
    event['start'] = wallIso(start);
    event['end'] = wallIso(start.add(length));
    return {
      'service': 'calendar',
      'action': 'move_event',
      'eventId': id,
      'title': event['title'],
      'from': wallIso(from),
      'to': wallIso(start),
    };
  }

  /// Adds the event [event] unless one with its id exists, and returns it.
  Map<String, dynamic> ensureEvent(Map<String, dynamic> event) {
    for (final existing in _database.calendarEvents) {
      if (existing['id'] == event['id']) return existing;
    }
    _database.calendarEvents.add(event);
    return event;
  }

  /// Removes the event [id] when there is one.
  void removeEvent(String id) =>
      _database.calendarEvents.removeWhere((event) => event['id'] == id);
}
