import 'dart:async';

import 'package:home_repository/home_repository.dart';

/// Saturday 7:30 AM, where the demo starts.
final saturdayStart = DateTime.utc(2026, 10, 10, 7, 30);

/// The end of that Saturday.
final saturdayEnd = DateTime.utc(2026, 10, 10, 23, 59);

class FakeScenarioRepository implements ScenarioRepository {
  FakeScenarioRepository({this.failures = 0, this.gate});

  /// How many calls throw before one succeeds.
  int failures;

  /// Holds each call open until completed.
  Completer<void>? gate;

  /// Every time the clock was moved to, in order.
  final moves = <DateTime>[];

  /// How many times the demo was reset.
  int resets = 0;

  ScenarioReading _reading(DateTime now) =>
      ScenarioReading(now: now, start: saturdayStart, end: saturdayEnd);

  @override
  Future<ScenarioReading> moveTo(DateTime time) async {
    await gate?.future;
    if (failures > 0) {
      failures--;
      throw const ScenarioRequestFailed('boom');
    }
    moves.add(time);
    return _reading(time);
  }

  @override
  Future<ScenarioReading> reset() async {
    await gate?.future;
    if (failures > 0) {
      failures--;
      throw const ScenarioRequestFailed('boom');
    }
    resets++;
    return _reading(saturdayStart);
  }
}
