import 'dart:convert';

import 'package:home_api_client/home_api_client.dart';
import 'package:home_repository/home_repository.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:test/test.dart';

const ana = HomeUser(id: 'ana', name: 'Ana', role: 'host');
const marco = HomeUser(id: 'marco', name: 'Marco', role: 'logistics');

HttpUsersRepository _repository(http.Client client) => HttpUsersRepository(
  client: HomeApiClient(
    sessionId: 'visitor-0123456789abcdef',
    baseUri: Uri.parse('http://localhost:8080'),
    httpClient: client,
  ),
);

void main() {
  group(HttpUsersRepository, () {
    test('parses the list the backend answers', () async {
      final repository = _repository(
        MockClient(
          (_) async => http.Response(
            jsonEncode({
              'users': [
                {'id': 'ana', 'name': 'Ana', 'role': 'host'},
                {'id': 'marco', 'name': 'Marco', 'role': 'logistics'},
              ],
            }),
            200,
          ),
        ),
      );

      expect(await repository.fetchUsers(), [ana, marco]);
    });

    test('throws on a non 200 status', () async {
      final repository = _repository(
        MockClient((_) async => http.Response('nope', 401)),
      );

      await expectLater(
        repository.fetchUsers(),
        throwsA(
          isA<UsersRequestFailed>().having(
            (e) => e.toString(),
            'message',
            contains('401'),
          ),
        ),
      );
    });
  });
}
