import 'dart:io';

import 'package:dart_frog/dart_frog.dart';
import 'package:home_backend/api_error.dart';
import 'package:home_backend/generate/generate_handler.dart';
import 'package:home_backend/generate/generate_request.dart';

/// `POST /generate`: runs the model on the conversation in the body.
///
/// Answers `405` to any other method and `400` for a body that is not a valid
/// [GenerateRequest]; the generation itself is [runGeneration].
Future<Response> onRequest(RequestContext context) async {
  if (context.request.method != HttpMethod.post) {
    return Response(statusCode: HttpStatus.methodNotAllowed);
  }

  final GenerateRequest request;
  try {
    final body = await context.request.json() as Map<String, dynamic>;
    request = GenerateRequest.fromJson(body);
  } on FormatException catch (error) {
    return ApiError.badRequest(message: error.message).toResponse();
  } catch (_) {
    return const ApiError.badRequest(message: 'Invalid JSON body').toResponse();
  }

  return runGeneration(context, routeName: 'generate', request: request);
}
