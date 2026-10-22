import 'package:home_backend/data/mock_database.dart';
import 'package:home_backend/tools/google_home_tool.dart';
import 'package:test/test.dart';

void main() {
  group('googleHomeTool', () {
    final database = MockDatabase(
      users: {
        'users': [
          {'id': 'ana', 'name': 'Ana', 'role': 'Host'},
        ],
      },
      home: {
        'now': 'now',
        'timeZone': 'tz',
        'structure': {'name': 'Rivera Home'},
        'rooms': [
          {'id': 'kitchen', 'name': 'Kitchen'},
        ],
        'devices': [
          {'id': 'oven', 'room': 'kitchen', 'type': 'OvenDevice'},
        ],
        'groups': <Map<String, dynamic>>[],
        'automations': <Map<String, dynamic>>[],
      },
    );
    final tool = googleHomeTool(database);

    test('is named and requires a user id', () {
      expect(tool.name, 'get_google_home_data');
      expect(tool.description, isNotEmpty);
      expect(tool.inputSchema, containsPair('required', ['user_id']));
    });

    test('returns the home model for a user', () async {
      final result = (await tool.call({'user_id': 'ana'}))! as Map;

      expect(result['structure'], {'name': 'Rivera Home'});
      expect(result['devices'], hasLength(1));
    });

    test('passes the room and device type filters through', () async {
      final result =
          (await tool.call({
                'user_id': 'ana',
                'room': 'Kitchen',
                'device_type': 'OvenDevice',
              }))!
              as Map;

      expect(result['devices'], hasLength(1));
    });

    test('throws a recoverable exception when a filter matches nothing', () {
      expect(
        () => tool.call({'user_id': 'ana', 'room': 'Attic'}),
        throwsA(isA<MockDataNotFound>()),
      );
    });

    test('throws a recoverable exception without a user id', () {
      expect(
        () => tool.call(<String, dynamic>{}),
        throwsA(isA<MockDataNotFound>()),
      );
      expect(
        () => tool.call({'user_id': ''}),
        throwsA(isA<MockDataNotFound>()),
      );
    });
  });
}
