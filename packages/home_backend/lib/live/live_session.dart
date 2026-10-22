import 'dart:async';
import 'dart:convert';

import 'package:home_backend/live/live_hub.dart';
import 'package:home_backend/scenario/scenario_world.dart';
import 'package:home_timeline/home_timeline.dart';
import 'package:web_socket_channel/web_socket_channel.dart';

/// The WebSocket subprotocol `/live` clients offer and the server selects.
///
/// `/live` needs no key, so clients offer this name alone.
const liveProtocol = 'genui.live.v1';

/// {@template live_session}
/// One `/live` connection: the panel's line to the scenario.
/// {@endtemplate}
///
/// The client sends `{"type": "clock", "to": "2026-10-10T16:45:00"}` to move
/// the scenario clock, one frame per minute as the time dial turns. The server
/// sends, to every connection and as it happens:
///
/// - `clock`: `{now, start, end, timeZone}`, on connect and after the clock
///   moves or the demo resets.
/// - `a2ui`: `{message}`, an A2UI message for the dashboard on screen: the
///   `updateDataModel` that moves the values of a device the cards are bound
///   to, as the device changes.
/// - `inbox`: `{userId, unread, item}`, when a notification lands for a user.
/// - `changed`: `{users, reason}`, when household data changed for those users
///   outside the clock, so their screens should refresh.
///
/// A frame the server cannot read is answered with
/// `{"type": "error", "message": ...}` and the connection stays open: one bad
/// minute never ends the dial's line to the backend.
class LiveSession {
  /// {@macro live_session}
  ///
  /// Creates a session between a client socket and the scenario world.
  LiveSession({
    required this._client,
    required this._world,
    required this._hub,
  });

  final WebSocketChannel _client;
  final ScenarioWorld _world;
  final LiveHub _hub;

  /// Serves the connection until the client goes away.
  Future<void> run() async {
    final stop = _hub.listen(_send);
    try {
      _send(_world.clockFrame());
      await for (final message in _client.stream) {
        _handle(message);
      }
    } finally {
      stop();
    }
  }

  void _handle(Object? message) {
    final frame = _decode(message);
    if (frame == null || frame['type'] != 'clock' || frame['to'] is! String) {
      _send(_error('Send {"type": "clock", "to": "<ISO 8601 wall time>"}.'));
      return;
    }
    final DateTime target;
    try {
      target = parseWall(frame['to']! as String);
    } on FormatException {
      _send(_error('"to" is not a time.'));
      return;
    }
    _world.moveTo(target);
  }

  Map<String, Object?> _error(String message) => {
    'type': 'error',
    'message': message,
  };

  Map<String, dynamic>? _decode(Object? message) {
    if (message is! String) return null;
    try {
      final decoded = jsonDecode(message);
      return decoded is Map<String, dynamic> ? decoded : null;
    } on FormatException {
      return null;
    }
  }

  void _send(Map<String, Object?> frame) => _client.sink.add(jsonEncode(frame));
}
