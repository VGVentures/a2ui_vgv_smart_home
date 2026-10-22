import 'dart:io';

import 'package:dart_frog/dart_frog.dart';
import 'package:home_backend/devices/device_state_machine.dart';
import 'package:home_backend/scenario/scenario_world.dart';

/// `POST /reset`: puts the demo back in its first state.
///
/// Every document (devices, calendar, recipe plan, trips, bakery, to-do lists)
/// is restored and the scenario clock goes back to Saturday 7:30 AM. Answers
/// the clock, like `/clock`.
Response onRequest(RequestContext context) {
  if (context.request.method != HttpMethod.post) {
    return Response(statusCode: HttpStatus.methodNotAllowed);
  }
  final world = context.read<ScenarioWorld>()..reset();
  context.read<DeviceStateMachine>().reset();
  return Response.json(body: world.clockJson());
}
