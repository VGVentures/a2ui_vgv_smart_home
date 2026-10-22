import 'dart:async';

import 'package:bloc/bloc.dart';
import 'package:equatable/equatable.dart';
import 'package:home_repository/home_repository.dart';

/// {@template live_state}
/// What the backend pushed: how many times each user's data changed, and how
/// many notifications each has not read.
/// {@endtemplate}
class LiveState extends Equatable {
  /// {@macro live_state}
  const LiveState({
    this.refreshes = const {},
    this.unread = const {},
  });

  /// How many times each user's data changed behind their back. A dashboard
  /// builds again from the backend when its user's count grows.
  final Map<String, int> refreshes;

  /// How many notifications each user has not read.
  final Map<String, int> unread;

  @override
  List<Object?> get props => [refreshes, unread];
}

/// {@template live_cubit}
/// What the backend pushes, as state: which users' data changed so their
/// dashboards refresh by themselves, and their unread counts.
/// {@endtemplate}
class LiveCubit extends Cubit<LiveState> {
  /// {@macro live_cubit}
  LiveCubit({required this._repository}) : super(const LiveState()) {
    _subscription = _repository.events.listen(_onEvent);
  }

  final LiveRepository _repository;
  late final StreamSubscription<LiveEvent> _subscription;
  final _surfaceMessages = StreamController<Map<String, Object?>>.broadcast(
    sync: true,
  );

  /// The A2UI messages the backend sends to the dashboard on screen, such as
  /// the new values of a device. They are not state: each is applied once, to
  /// the surface that is open when it arrives.
  Stream<Map<String, Object?>> get surfaceMessages => _surfaceMessages.stream;

  /// Opens the connection. Safe to call again.
  Future<void> connect() => _repository.connect();

  /// Closes the connection, for example on sign out.
  Future<void> disconnect() => _repository.close();

  void _onEvent(LiveEvent event) {
    switch (event) {
      case ClockUpdated():
        break;
      case SurfaceMessageReceived(:final message):
        _surfaceMessages.add(message);
      case InboxReceived(:final userId, :final unread):
        emit(
          LiveState(
            refreshes: _bumped([userId]),
            unread: {...state.unread, userId: unread},
          ),
        );
      case DataChanged(:final users):
        emit(
          LiveState(
            refreshes: _bumped(users),
            unread: state.unread,
          ),
        );
    }
  }

  Map<String, int> _bumped(List<String> users) => {
    ...state.refreshes,
    for (final user in users) user: (state.refreshes[user] ?? 0) + 1,
  };

  @override
  Future<void> close() async {
    await _subscription.cancel();
    await _surfaceMessages.close();
    await _repository.close();
    return super.close();
  }
}
