import 'package:home_timeline/src/wall_time.dart';

/// {@template scenario_clock}
/// The demo's clock: a scenario that starts at a fixed moment and only moves
/// when something moves it.
///
/// Everything time dependent in the backend reads this clock, never the host's.
/// The timeline control on the client sets it, and [reset] puts it back at the
/// start. It cannot go before [start] or after [end].
/// {@endtemplate}
class ScenarioClock {
  /// {@macro scenario_clock}
  ///
  /// It starts at [start].
  ///
  /// [end] defaults to the end of the day of [start]. [utcOffset] is the
  /// household's offset from UTC, used only to answer in UTC.
  ScenarioClock(
    this.start, {
    DateTime? end,
    this.utcOffset = const Duration(hours: -5),
  }) : end = end ?? DateTime.utc(start.year, start.month, start.day, 23, 59),
       _now = start;

  /// Where the scenario begins, and where [reset] returns to.
  final DateTime start;

  /// The last moment the clock can show.
  final DateTime end;

  /// The household's offset from UTC.
  final Duration utcOffset;

  DateTime _now;

  /// The current scenario time, as a naive local time.
  DateTime get now => _now;

  /// [now] as a naive ISO 8601 string, for example `2026-10-10T16:30:00`.
  String get nowIso => wallIso(_now);

  /// [now] expressed in UTC.
  DateTime get nowUtc => _now.subtract(utcOffset);

  /// Moves the clock to [target], held within [start] and [end], and returns
  /// where it ended up.
  DateTime moveTo(DateTime target) {
    if (target.isBefore(start)) return _now = start;
    if (target.isAfter(end)) return _now = end;
    return _now = target;
  }

  /// Moves the clock by [delta], held within [start] and [end].
  DateTime moveBy(Duration delta) => moveTo(_now.add(delta));

  /// Puts the clock back at [start].
  void reset() => _now = start;
}
