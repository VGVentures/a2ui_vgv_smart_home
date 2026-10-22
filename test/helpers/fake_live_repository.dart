import 'dart:async';

import 'package:home_repository/home_repository.dart';

import 'fake_scenario_repository.dart';

/// A backend that answers every clock move at once, like the real one.
class FakeLiveRepository implements LiveRepository {
  FakeLiveRepository({this.connected = true, this.answers = true});

  /// Whether a connection is open. A move answers false when it is not.
  bool connected;

  /// Whether a move is answered with a [ClockUpdated].
  bool answers;

  /// Every time the clock was moved to, in order.
  final moves = <DateTime>[];

  /// How many times [connect] was called, and [close].
  int connects = 0;
  int closes = 0;

  final _events = StreamController<LiveEvent>.broadcast();

  @override
  Stream<LiveEvent> get events => _events.stream;

  @override
  bool get isConnected => connected;

  /// Pushes [event] as the backend would.
  void emit(LiveEvent event) => _events.add(event);

  @override
  Future<void> connect() async => connects++;

  @override
  bool moveTo(DateTime time) {
    if (!connected) return false;
    moves.add(time);
    if (answers) {
      emit(
        ClockUpdated(
          ScenarioReading(now: time, start: saturdayStart, end: saturdayEnd),
        ),
      );
    }
    return true;
  }

  @override
  Future<void> close() async => closes++;
}
