import 'dart:async';

import 'package:dart_frog/dart_frog.dart';
import 'package:dart_frog_web_socket/dart_frog_web_socket.dart';
import 'package:home_backend/cors/cors_config.dart';
import 'package:home_backend/live/live_hub.dart';
import 'package:home_backend/live/live_session.dart';
import 'package:home_backend/scenario/scenario_world.dart';

/// `GET /live`: a WebSocket that carries the scenario to the panel as it
/// happens.
///
/// The panel sends the clock a minute at a time as its time dial turns, and
/// the server pushes the clock, the devices' live values and every inbox item
/// back. It needs no key. Browsers from origins outside the CORS
/// allowlist get a `403`. `LiveSession` describes the protocol.
Future<Response> onRequest(RequestContext context) async {
  final world = context.read<ScenarioWorld>();
  final hub = context.read<LiveHub>();
  final cors = context.read<CorsConfig>();

  final handler = webSocketHandler(
    (channel, _) => unawaited(
      LiveSession(client: channel, world: world, hub: hub).run(),
    ),
    protocols: const [liveProtocol],
    // The WebSocket handler lowercases the Origin header before comparing.
    allowedOrigins: {
      for (final origin in cors.allowedOrigins) origin.toLowerCase(),
    },
  );
  return handler(context);
}
