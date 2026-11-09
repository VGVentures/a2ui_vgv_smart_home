import 'dart:io';

import 'package:home_backend/api_error.dart';
import 'package:test/test.dart';

void main() {
  group('ApiError', () {
    test('badRequest carries a 400 status and the given message', () {
      const error = ApiError.badRequest(message: 'bad input');
      expect(error.statusCode, HttpStatus.badRequest);
      expect(error.toJson(), {'message': 'bad input'});
    });

    test('notFound carries a 404 status and the given message', () {
      const error = ApiError.notFound(message: 'missing');
      expect(error.statusCode, HttpStatus.notFound);
      expect(error.toJson(), {'message': 'missing'});
    });

    test('conflict carries a 409 status and the given message', () {
      const error = ApiError.conflict(message: 'busy');
      expect(error.statusCode, HttpStatus.conflict);
      expect(error.toJson(), {'message': 'busy'});
    });

    test('internalServerError defaults to a generic message and 500', () {
      const error = ApiError.internalServerError();
      expect(error.statusCode, HttpStatus.internalServerError);
      expect(error.toJson(), {'message': 'Internal server error'});
    });

    test(
      'toResponse builds a JSON response with the status and body',
      () async {
        final response = const ApiError.badRequest(
          message: 'nope',
        ).toResponse();
        expect(response.statusCode, HttpStatus.badRequest);
        expect(
          response.headers[HttpHeaders.contentTypeHeader],
          contains('application/json'),
        );
        expect(await response.json(), {'message': 'nope'});
      },
    );
  });
}
