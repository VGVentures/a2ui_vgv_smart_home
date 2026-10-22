import 'dart:convert';
import 'dart:io';

import 'package:dart_frog/dart_frog.dart';
import 'package:home_backend/data/mock_database.dart';
import 'package:mocktail/mocktail.dart';
import 'package:test/test.dart';

import '../../../routes/users/[id].dart' as route;

class _MockRequestContext extends Mock implements RequestContext {}

void main() {
  group('GET /users/<id>', () {
    late MockDatabase database;

    setUp(() {
      database = MockDatabase(
        users: {
          'users': [
            {'id': 'ana', 'name': 'Ana', 'role': 'Host', 'age': 41},
          ],
        },
        home: <String, dynamic>{},
      );
    });

    RequestContext contextFor(HttpMethod method) {
      final context = _MockRequestContext();
      when(() => context.request).thenReturn(
        Request(method.value, Uri.parse('http://localhost/users/ana')),
      );
      when(() => context.read<MockDatabase>()).thenReturn(database);
      return context;
    }

    test('returns the full profile', () async {
      final response = route.onRequest(contextFor(HttpMethod.get), 'ana');

      expect(response.statusCode, HttpStatus.ok);
      expect(
        jsonDecode(await response.body()),
        containsPair('age', 41),
      );
    });

    test('returns 404 for an unknown user', () async {
      final response = route.onRequest(contextFor(HttpMethod.get), 'nobody');

      expect(response.statusCode, HttpStatus.notFound);
      expect(jsonDecode(await response.body()), {'message': 'User not found'});
    });

    test('rejects other methods with 405', () {
      final response = route.onRequest(contextFor(HttpMethod.delete), 'ana');

      expect(response.statusCode, HttpStatus.methodNotAllowed);
    });
  });
}
