import 'dart:convert';
import 'dart:io';

import 'package:dart_frog/dart_frog.dart';
import 'package:home_backend/data/mock_database.dart';
import 'package:mocktail/mocktail.dart';
import 'package:test/test.dart';

import '../../../routes/users/index.dart' as route;

class _MockRequestContext extends Mock implements RequestContext {}

void main() {
  group('GET /users', () {
    late MockDatabase database;

    setUp(() {
      database = MockDatabase(
        users: {
          'users': [
            {'id': 'ana', 'name': 'Ana', 'role': 'Host', 'age': 41},
          ],
        },
        home: <String, dynamic>{},
        photos: {'ana': 'abc'},
      );
    });

    RequestContext contextFor(HttpMethod method) {
      final context = _MockRequestContext();
      when(() => context.request).thenReturn(
        Request(method.value, Uri.parse('http://localhost/users')),
      );
      when(() => context.read<MockDatabase>()).thenReturn(database);
      return context;
    }

    test('lists id, name, role and photo of every user', () async {
      final response = route.onRequest(contextFor(HttpMethod.get));

      expect(response.statusCode, HttpStatus.ok);
      expect(jsonDecode(await response.body()), {
        'users': [
          {'id': 'ana', 'name': 'Ana', 'role': 'Host', 'photo': 'abc'},
        ],
      });
    });

    test('rejects other methods with 405', () {
      final response = route.onRequest(contextFor(HttpMethod.post));

      expect(response.statusCode, HttpStatus.methodNotAllowed);
    });
  });
}
