// Wall-clock helpers for the scenario.
//
// The scenario runs on naive local times such as `2026-10-10T16:30:00` (the
// household's time zone). They are held as UTC-flagged [DateTime]s so that
// arithmetic never crosses a daylight saving change of the host machine.

/// Parses a naive ISO 8601 local time such as `2026-10-10T16:30:00`.
DateTime parseWall(String iso) =>
    DateTime.parse(iso.endsWith('Z') ? iso : '${iso}Z');

/// Formats [time] as a naive ISO 8601 local time, to the second.
String wallIso(DateTime time) {
  final iso = time.toUtc().toIso8601String();
  return iso.substring(0, 19);
}

/// Formats [time] as `HH:mm` (24 hour), the form schedules are stored in.
String hhmm(DateTime time) => '${_two(time.hour)}:${_two(time.minute)}';

/// The moment on the day of [day] that [hhmm] names, for example `18:30`.
DateTime atHhmm(DateTime day, String hhmm) {
  final parts = hhmm.split(':');
  return DateTime.utc(
    day.year,
    day.month,
    day.day,
    int.parse(parts[0]),
    int.parse(parts[1]),
  );
}

/// Formats [time] for people, for example `5:30 PM`.
String clock12(DateTime time) {
  final hour = time.hour % 12 == 0 ? 12 : time.hour % 12;
  final suffix = time.hour < 12 ? 'AM' : 'PM';
  return '$hour:${_two(time.minute)} $suffix';
}

String _two(int value) => value.toString().padLeft(2, '0');
