import 'package:home_backend/data/mock_database.dart';
import 'package:home_backend/tools/tool_args.dart';
import 'package:test/test.dart';

void main() {
  group('requiredUserId', () {
    test('returns the user id', () {
      expect(requiredUserId({'user_id': 'ana'}), 'ana');
    });

    test('throws a recoverable exception when it is missing or empty', () {
      expect(
        () => requiredUserId(<String, dynamic>{}),
        throwsA(isA<MockDataNotFound>()),
      );
      expect(
        () => requiredUserId({'user_id': ''}),
        throwsA(isA<MockDataNotFound>()),
      );
      expect(
        () => requiredUserId({'user_id': 7}),
        throwsA(isA<MockDataNotFound>()),
      );
    });
  });

  test('userIdInputSchema requires user_id', () {
    expect(userIdInputSchema['required'], ['user_id']);
  });
}
