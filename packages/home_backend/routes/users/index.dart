import 'dart:io';

import 'package:dart_frog/dart_frog.dart';
import 'package:home_backend/data/mock_database.dart';

/// `GET /users`: the household's users and their photos, for the frontend's user toggle.
Response onRequest(RequestContext context) {
  if (context.request.method != HttpMethod.get) {
    return Response(statusCode: HttpStatus.methodNotAllowed);
  }
  final database = context.read<MockDatabase>();
  return Response.json(body: {'users': database.listProfiles()});
}
