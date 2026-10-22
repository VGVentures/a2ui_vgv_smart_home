import 'dart:async';

import 'package:bloc/bloc.dart';
import 'package:equatable/equatable.dart';
import 'package:home_repository/home_repository.dart';

/// {@template timeline_status}
/// Whether the scenario clock is loading, ready or failed.
/// {@endtemplate}
enum TimelineStatus {
  /// The clock is being fetched or reset.
  loading,

  /// The clock is ready to be moved.
  ready,

  /// The backend could not be reached.
  failure,
}

/// {@template timeline_state}
/// Where the scenario clock stands: the time on screen, the span it can run
/// over, whether it is moving, and counters of its settled moves and resets.
/// {@endtemplate}
class TimelineState extends Equatable {
  /// {@macro timeline_state}
  TimelineState({
    this.status = TimelineStatus.loading,
    DateTime? now,
    DateTime? start,
    DateTime? end,
    this.moving = false,
    this.revision = 0,
    this.resets = 0,
  }) : start = start ?? _saturdayStart,
       now = now ?? start ?? _saturdayStart,
       end = end ?? _saturdayEnd;

  /// Saturday 7:30 AM, where the demo always begins.
  static final _saturdayStart = DateTime.utc(2026, 10, 10, 7, 30);
  static final _saturdayEnd = DateTime.utc(2026, 10, 10, 23, 59);

  /// Whether the clock is loading, ready or failed.
  final TimelineStatus status;

  /// The scenario time on screen. While the time moves it passes through every
  /// moment between where it was and where it is going.
  final DateTime now;

  /// Where the scenario starts, and where a reset returns to.
  final DateTime start;

  /// The last moment the scenario can show.
  final DateTime end;

  /// Whether the time is moving.
  final bool moving;

  /// Counts the times the scenario settled on a new time or was reset. The
  /// dashboard builds again from the backend's data when it changes.
  final int revision;

  /// Counts the resets, so the dashboard can start over on the first user.
  final int resets;

  /// A copy of this state with the given fields replaced.
  TimelineState copyWith({
    TimelineStatus? status,
    DateTime? now,
    DateTime? start,
    DateTime? end,
    bool? moving,
    int? revision,
    int? resets,
  }) => TimelineState(
    status: status ?? this.status,
    now: now ?? this.now,
    start: start ?? this.start,
    end: end ?? this.end,
    moving: moving ?? this.moving,
    revision: revision ?? this.revision,
    resets: resets ?? this.resets,
  );

  @override
  List<Object?> get props => [
    status,
    now,
    start,
    end,
    moving,
    revision,
    resets,
  ];
}

/// How many real seconds one minute of the scenario takes while the time passes
/// on its own. Tune this to make the demo's clock faster or slower: the oven
/// preheats in about 14 scenario minutes, so at 10 it takes a little over two
/// real minutes.
const secondsPerScenarioMinute = 10;

/// {@template timeline_cubit}
/// The demo's time: it passes on its own, and a person can move it by hand.
///
/// The backend owns the clock. This cubit asks it to move and shows the new
/// time at once: a move jumps instead of passing through the minutes in
/// between, and the dashboard shows a skeleton until the backend has the clock
/// there and the new dashboard is drawn.
/// {@endtemplate}
class TimelineCubit extends Cubit<TimelineState> {
  /// {@macro timeline_cubit}
  TimelineCubit({
    required this._repository,
    required this._live,
    this._settleTimeout = const Duration(seconds: 3),
    this._autoPlay = false,
  }) : super(TimelineState());

  /// How often the time that passes on its own moves.
  static const _playTick = Duration(seconds: 1);

  /// How much scenario time one [_playTick] is, from
  /// [secondsPerScenarioMinute].
  static const _playStep = Duration(
    milliseconds: 60 * 1000 ~/ secondsPerScenarioMinute,
  );

  final ScenarioRepository _repository;
  final LiveRepository _live;

  /// How long to wait for the backend to confirm the clock before asking again
  /// over HTTP.
  final Duration _settleTimeout;

  /// Whether the time passes on its own once the demo is ready.
  final bool _autoPlay;

  /// Moves the time on while nothing else is moving it.
  Timer? _playTimer;

  /// Counts the moves and resets, so one that was cut short can tell.
  int _run = 0;

  /// Starts the demo over: the backend restores its data and clock, and the
  /// time goes back to Saturday 7:30 AM. Stops a move still settling.
  Future<void> reset() async {
    final run = _cancel();
    emit(state.copyWith(status: TimelineStatus.loading, moving: false));
    try {
      final reading = await _repository.reset();
      if (run != _run) return;
      emit(
        TimelineState(
          status: TimelineStatus.ready,
          now: reading.now,
          start: reading.start,
          end: reading.end,
          revision: state.revision + 1,
          resets: state.resets + 1,
        ),
      );
      _play();
    } on Object {
      if (run != _run) return;
      emit(state.copyWith(status: TimelineStatus.failure));
    }
  }

  /// Moves the time by [delta]. See [seekTo].
  Future<void> step(Duration delta) => seekTo(state.now.add(delta));

  /// Moves the time to [time] at once, and tells the backend. Does nothing
  /// while a move is still settling or when it would not move. A time outside
  /// the scenario goes to its nearest end.
  Future<void> seekTo(DateTime time) async {
    if (state.status != TimelineStatus.ready || state.moving) return;
    final target = _clamp(time);
    if (target == state.now) return;
    final run = _cancel();
    emit(state.copyWith(now: target, moving: true));
    final reading = await _settle(target);
    if (run != _run) return;
    if (reading == null) {
      emit(state.copyWith(status: TimelineStatus.failure, moving: false));
      return;
    }
    emit(
      state.copyWith(
        now: reading.now,
        moving: false,
        revision: state.revision + 1,
      ),
    );
    _play();
  }

  /// Asks the backend for [target] and waits for it to say the clock is there.
  /// When the connection is down, or silent for [_settleTimeout], asks over
  /// HTTP instead. Answers `null` when neither works.
  Future<ScenarioReading?> _settle(DateTime target) async {
    final live = await _awaitClock(target);
    if (live != null) return live;
    try {
      return await _repository.moveTo(target);
    } on Object {
      return null;
    }
  }

  /// Lets the time pass on its own: every [_playTick] the scenario moves on by
  /// [_playStep], and the backend is told each minute as it goes by. Waits for
  /// anything that is moving the time by hand.
  void _play() {
    if (!_autoPlay || _playTimer != null) return;
    _playTimer = Timer.periodic(_playTick, (_) {
      if (state.status != TimelineStatus.ready || state.moving) return;
      final before = _minuteOf(state.now);
      final next = _clamp(state.now.add(_playStep));
      if (next == state.now) return;
      emit(state.copyWith(now: next));
      final minute = _minuteOf(next);
      if (minute != before) _live.moveTo(minute);
    });
  }

  static DateTime _minuteOf(DateTime time) =>
      DateTime.utc(time.year, time.month, time.day, time.hour, time.minute);

  Future<ScenarioReading?> _awaitClock(DateTime target) {
    final done = Completer<ScenarioReading?>();
    final subscription = _live.events.listen((event) {
      if (event is ClockUpdated &&
          event.reading.now == target &&
          !done.isCompleted) {
        done.complete(event.reading);
      }
    });
    final timer = Timer(_settleTimeout, () {
      if (!done.isCompleted) done.complete();
    });
    if (!_live.moveTo(target)) done.complete();
    return done.future.whenComplete(() {
      unawaited(subscription.cancel());
      timer.cancel();
    });
  }

  DateTime _clamp(DateTime time) {
    if (time.isBefore(state.start)) return state.start;
    if (time.isAfter(state.end)) return state.end;
    return time;
  }

  int _cancel() => ++_run;

  @override
  Future<void> close() {
    _cancel();
    _playTimer?.cancel();
    return super.close();
  }
}
