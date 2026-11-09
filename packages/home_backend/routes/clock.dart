import 'dart:io';

import 'package:dart_frog/dart_frog.dart';
import 'package:home_backend/api_error.dart';
import 'package:home_backend/scenario/scenario_world.dart';
import 'package:home_timeline/home_timeline.dart';

/// `/clock`: the scenario clock.
///
/// `GET` answers `{now, start, end, timeZone}`. `POST` moves the clock and
/// answers the same, after everything that follows from the time (the oven, the
/// bakery order, the doorbell) has been brought up to date. The body is exactly
/// one of `{"to": "2026-10-10T17:00:00"}` or `{"minutes": 15}` (negative goes
/// back). The clock stays between the scenario's start and end.
Future<Response> onRequest(RequestContext context) async {
  final world = context.read<ScenarioWorld>();
  switch (context.request.method) {
    case HttpMethod.get:
      return Response.json(body: world.clockJson());
    case HttpMethod.post:
      final DateTime target;
      try {
        target = _target(
          await context.request.json() as Map<String, dynamic>,
          world.database.clock.now,
        );
      } catch (_) {
        return const ApiError.badRequest(
          message: 'Send exactly one of "to" (ISO 8601) or "minutes".',
        ).toResponse();
      }
      world.moveTo(target);
      return Response.json(body: world.clockJson());
    // ignore: no_default_cases
    default:
      return Response(statusCode: HttpStatus.methodNotAllowed);
  }
}

DateTime _target(Map<String, dynamic> body, DateTime now) {
  final to = body['to'];
  final minutes = body['minutes'];
  if ((to == null) == (minutes == null)) throw const FormatException();
  if (to != null) return parseWall(to as String);
  return now.add(Duration(minutes: (minutes! as num).toInt()));
}
