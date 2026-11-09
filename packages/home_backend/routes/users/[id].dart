import 'dart:io';

import 'package:dart_frog/dart_frog.dart';
import 'package:home_backend/api_error.dart';
import 'package:home_backend/data/mock_database.dart';

/// `GET /users/<id>`: one user's full profile.
Response onRequest(RequestContext context, String id) {
  if (context.request.method != HttpMethod.get) {
    return Response(statusCode: HttpStatus.methodNotAllowed);
  }
  final user = context.read<MockDatabase>().findUser(id);
  if (user == null) {
    return const ApiError.notFound(message: 'User not found').toResponse();
  }
  return Response.json(body: user);
}
