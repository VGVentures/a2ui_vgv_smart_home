import 'package:dart_frog/dart_frog.dart';
import 'package:home_backend/api_error.dart';
import 'package:home_backend/data/mock_database.dart';
import 'package:home_backend/devices/device_state_machine.dart';
import 'package:home_backend/live/live_hub.dart';
import 'package:home_backend/live/live_session.dart';
import 'package:home_backend/llm/llm.dart';
import 'package:home_backend/scenario/scenario_world.dart';
import 'package:home_backend/session/demo_session.dart';
import 'package:home_backend/session/session_store.dart';

/// The header that names the visitor's demo world.
const sessionHeader = 'x-session-id';

/// Paths that touch no demo world.
const _worldlessPaths = {'/health', '/transcribe'};

final _validId = RegExp(r'^[A-Za-z0-9_-]{16,64}$');

/// Builds the middleware that gives each request the demo world of the visitor
/// who sent it, so every route reads and writes that visitor's copy.
///
/// A request with no valid session id gets a `400`. A new visitor when every
/// slot is held gets a `503`.
Middleware provideSession(SessionStore store) {
  return (handler) {
    return (context) async {
      if (_worldlessPaths.contains(context.request.uri.path)) {
        return handler(context);
      }
      final id = _sessionId(context.request);
      if (id == null || !_validId.hasMatch(id)) {
        return const ApiError.badRequest(
          message: 'Missing session id',
        ).toResponse();
      }
      final DemoSession session;
      try {
        session = await store.obtain(id);
      } on SessionLimitReached {
        return const ApiError.serviceUnavailable().toResponse();
      }
      return handler(
        context
            .provide<MockDatabase>(() => session.database)
            .provide<DeviceStateMachine>(() => session.machine)
            .provide<ScenarioWorld>(() => session.world)
            .provide<LiveHub>(() => session.hub)
            .provide<Generate>(() => session.generate),
      );
    };
  };
}

/// The id [request] carries: the `X-Session-Id` header, or on `/live`, where a
/// browser can't set headers, the `Sec-WebSocket-Protocol` entry that isn't the
/// protocol name.
String? _sessionId(Request request) {
  if (request.uri.path == '/live') {
    final entries = (request.headers['sec-websocket-protocol'] ?? '')
        .split(',')
        .map((entry) => entry.trim())
        .where((entry) => entry.isNotEmpty && entry != liveProtocol)
        .toList();
    return entries.length == 1 ? entries.single : null;
  }
  return request.headers[sessionHeader];
}
