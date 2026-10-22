import 'dart:io';

import 'package:dart_frog/dart_frog.dart';

/// {@template api_error}
/// A JSON error response: an HTTP status code paired with a message.
/// {@endtemplate}
///
/// Serializes to `{"message": "..."}`. Named constructors bake in the status
/// code. Call [toResponse] to build the dart_frog [Response].
class ApiError {
  /// {@macro api_error}
  ///
  /// A `400 Bad Request` error with the given [message].
  const ApiError.badRequest({required this.message})
    : statusCode = HttpStatus.badRequest;

  /// {@macro api_error}
  ///
  /// A `401 Unauthorized` error. Defaults to a generic [message] so verifier
  /// details are never leaked to clients.
  const ApiError.unauthorized({this.message = 'Unauthorized'})
    : statusCode = HttpStatus.unauthorized;

  /// {@macro api_error}
  ///
  /// A `404 Not Found` error with the given [message].
  const ApiError.notFound({required this.message})
    : statusCode = HttpStatus.notFound;

  /// {@macro api_error}
  ///
  /// A `409 Conflict` error, returned when a command is valid but the target
  /// cannot do it right now.
  const ApiError.conflict({required this.message})
    : statusCode = HttpStatus.conflict;

  /// {@macro api_error}
  ///
  /// A `422 Unprocessable Entity` error, returned when generation succeeds but
  /// the response fails validation. Defaults to a generic [message] so
  /// validator details are never leaked to clients.
  const ApiError.unprocessableEntity({
    this.message = 'Failed to generate a response.',
  }) : statusCode = HttpStatus.unprocessableEntity;

  /// {@macro api_error}
  ///
  /// A `502 Bad Gateway` error, returned when the upstream LLM provider fails.
  /// Defaults to a generic [message] so provider details are never leaked to
  /// clients.
  const ApiError.badGateway({this.message = 'Failed to generate a response.'})
    : statusCode = HttpStatus.badGateway;

  /// {@macro api_error}
  ///
  /// A `503 Service Unavailable` error, returned when every demo slot is taken.
  const ApiError.serviceUnavailable({
    this.message = 'The demo is full. Try again in a few minutes.',
  }) : statusCode = HttpStatus.serviceUnavailable;

  /// {@macro api_error}
  ///
  /// A `500 Internal Server Error`. Defaults to a generic [message] so internal
  /// details are never leaked to clients.
  const ApiError.internalServerError({this.message = 'Internal server error'})
    : statusCode = HttpStatus.internalServerError;

  /// The HTTP status code of this error.
  final int statusCode;

  /// A human-readable description of the failure.
  final String message;

  /// The JSON body for this error.
  Map<String, dynamic> toJson() => {'message': message};

  /// Builds the dart_frog [Response] with [statusCode] and the JSON body.
  Response toResponse() =>
      Response.json(statusCode: statusCode, body: toJson());
}
