import 'dart:io';

import 'package:dart_frog/dart_frog.dart';
import 'package:mocktail/mocktail.dart';
import 'package:test/test.dart';

import '../../routes/health.dart' as route;

class _MockRequestContext extends Mock implements RequestContext {}

void main() {
  group('GET /health', () {
    test('responds with a 200 and {"status": "ok"}.', () async {
      final context = _MockRequestContext();
      final response = route.onRequest(context);
      expect(response.statusCode, equals(HttpStatus.ok));
      await expectLater(response.body(), completion(equals('{"status":"ok"}')));
    });
  });
}
