import 'package:home_backend/data/mock_database.dart';
import 'package:home_backend/tools/user_data_tool.dart';
import 'package:test/test.dart';

void main() {
  group('userDataTool', () {
    final database = MockDatabase(
      users: {
        'users': [
          {'id': 'ana', 'name': 'Ana', 'role': 'Host', 'age': 41},
        ],
      },
      home: <String, dynamic>{},
    );
    final tool = userDataTool(database);

    test('is named and described for the model', () {
      expect(tool.name, 'get_user_data');
      expect(tool.description, isNotEmpty);
      expect(tool.inputSchema, containsPair('type', 'object'));
    });

    test('returns the full profile for a user id', () async {
      final result = await tool.call({'user_id': 'ana'});

      expect(result, containsPair('age', 41));
    });

    test('lists every user when no id is given', () async {
      final result = await tool.call(<String, dynamic>{});

      expect(result, {
        'users': [
          {'id': 'ana', 'name': 'Ana', 'role': 'Host'},
        ],
      });
    });

    test('lists every user when the id is empty', () async {
      final result = await tool.call({'user_id': ''});

      expect(result, containsPair('users', isNotEmpty));
    });

    test('throws a recoverable exception for an unknown user', () {
      expect(
        () => tool.call({'user_id': 'nobody'}),
        throwsA(isA<MockDataNotFound>()),
      );
    });
  });
}
