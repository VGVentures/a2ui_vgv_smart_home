import 'dart:async';
import 'dart:convert';

import 'package:equatable/equatable.dart';
import 'package:home_api_client/home_api_client.dart';
import 'package:home_repository/src/scenario_repository.dart';
import 'package:web_socket_channel/web_socket_channel.dart';

/// {@template live_event}
/// Something the backend pushed.
/// {@endtemplate}
sealed class LiveEvent extends Equatable {
  /// {@macro live_event}
  const LiveEvent();
}

/// {@template clock_updated}
/// The scenario clock, after it moved, was reset, or on connect.
/// {@endtemplate}
class ClockUpdated extends LiveEvent {
  /// {@macro clock_updated}
  const ClockUpdated(this.reading);

  /// Where the clock stands now.
  final ScenarioReading reading;

  @override
  List<Object?> get props => [reading];
}

/// {@template inbox_received}
/// A notification landed in a user's inbox.
/// {@endtemplate}
class InboxReceived extends LiveEvent {
  /// {@macro inbox_received}
  const InboxReceived({
    required this.userId,
    required this.unread,
    this.title,
    this.body,
  });

  /// The user whose inbox it landed in.
  final String userId;

  /// How many notifications the user has not read.
  final int unread;

  /// The title of the notification, when it has one.
  final String? title;

  /// The text of the notification, when it has one.
  final String? body;

  @override
  List<Object?> get props => [userId, unread, title, body];
}

/// {@template data_changed}
/// Household data changed outside the clock, so these users' dashboards are
/// out of date.
/// {@endtemplate}
class DataChanged extends LiveEvent {
  /// {@macro data_changed}
  const DataChanged({required this.users, this.reason});

  /// The ids of the users whose dashboards are out of date.
  final List<String> users;

  /// Why the data changed, when the backend said.
  final String? reason;

  @override
  List<Object?> get props => [users, reason];
}

/// {@template surface_message_received}
/// A message for the dashboard on screen: an `updateDataModel` that moves the
/// values of a device the cards are bound to, as the device changes.
/// {@endtemplate}
class SurfaceMessageReceived extends LiveEvent {
  /// {@macro surface_message_received}
  const SurfaceMessageReceived(this.message);

  /// The A2UI message, as the backend wrote it.
  final Map<String, Object?> message;

  @override
  List<Object?> get props => [message];
}

/// {@template live_repository}
/// The backend's live connection: it moves the clock and pushes what changes.
///
/// {@macro repository_seam}
/// {@endtemplate}
abstract interface class LiveRepository {
  /// What the backend pushes. Broadcast, and quiet while not connected.
  Stream<LiveEvent> get events;

  /// Whether a connection is open, or being opened.
  bool get isConnected;

  /// Opens the connection and keeps it open, retrying when it drops. Does
  /// nothing when it is already wanted.
  Future<void> connect();

  /// Asks the backend to move the clock to [time]. Answers false when there is
  /// no connection to ask on; the answer comes back as a [ClockUpdated].
  bool moveTo(DateTime time);

  /// Closes the connection and stops retrying.
  Future<void> close();
}

/// A second at first, doubling up to ten.
Duration defaultRetryDelay(int attempt) =>
    Duration(seconds: (1 << attempt.clamp(0, 4)).clamp(1, 10));

/// {@template web_socket_live_repository}
/// Talks to the backend's `/live` WebSocket. The frames are JSON text; the
/// backend README describes them.
///
/// It is made over `client`. `retryDelay` says how long to wait before the
/// next attempt, by how many have failed in a row.
/// {@endtemplate}
class WebSocketLiveRepository implements LiveRepository {
  /// {@macro web_socket_live_repository}
  WebSocketLiveRepository({
    required this._client,
    this._retryDelay = defaultRetryDelay,
  });

  final HomeApiClient _client;

  final Duration Function(int attempt) _retryDelay;
  final _events = StreamController<LiveEvent>.broadcast();

  WebSocketChannel? _channel;
  Timer? _retry;
  var _wanted = false;
  var _attempts = 0;

  @override
  Stream<LiveEvent> get events => _events.stream;

  @override
  bool get isConnected => _channel != null;

  @override
  Future<void> connect() async {
    if (_wanted) return;
    _wanted = true;
    _open();
  }

  void _open() {
    if (!_wanted) return;
    final channel = _client.connectLive();
    _channel = channel;
    // A failed connection also arrives on the stream, which retries.
    channel.ready.ignore();
    channel.stream.listen(
      (message) {
        _attempts = 0;
        _onMessage(message);
      },
      onError: (Object _) {},
      onDone: () {
        if (_channel != channel) return;
        _channel = null;
        _scheduleRetry();
      },
    );
  }

  void _scheduleRetry() {
    if (!_wanted) return;
    _retry = Timer(_retryDelay(_attempts++), _open);
  }

  @override
  bool moveTo(DateTime time) {
    final channel = _channel;
    if (channel == null) return false;
    channel.sink.add(
      jsonEncode({'type': 'clock', 'to': formatWallTime(time)}),
    );
    return true;
  }

  @override
  Future<void> close() async {
    _wanted = false;
    _retry?.cancel();
    final channel = _channel;
    _channel = null;
    // Not awaited: on a connection that never opened, the close never
    // completes.
    if (channel != null) unawaited(channel.sink.close());
  }

  void _onMessage(Object? message) {
    if (message is! String) return;
    final Object? decoded;
    try {
      decoded = jsonDecode(message);
    } on FormatException {
      return;
    }
    if (decoded is! Map<String, dynamic>) return;
    final event = _parse(decoded);
    if (event != null) _events.add(event);
  }

  static LiveEvent? _parse(Map<String, dynamic> frame) {
    try {
      return switch (frame['type']) {
        'clock' => ClockUpdated(ScenarioReading.fromJson(frame)),
        'a2ui' => SurfaceMessageReceived(
          (frame['message'] as Map<String, dynamic>).cast<String, Object?>(),
        ),
        'inbox' => _inbox(frame),
        'changed' => DataChanged(
          users: (frame['users'] as List<dynamic>).cast<String>(),
          reason: frame['reason'] as String?,
        ),
        _ => null,
      };
    } on Object {
      // A frame that does not read is skipped, like an unknown one.
      return null;
    }
  }

  static InboxReceived _inbox(Map<String, dynamic> frame) {
    final item = frame['item'] as Map<String, dynamic>?;
    return InboxReceived(
      userId: frame['userId'] as String,
      unread: (frame['unread'] as num).toInt(),
      title: item?['title'] as String?,
      body: item?['body'] as String?,
    );
  }
}
