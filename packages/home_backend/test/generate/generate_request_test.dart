import 'package:home_backend/generate/generate_request.dart';
import 'package:test/test.dart';

void main() {
  group('GenerateRequest.fromJson', () {
    test('parses a single user message', () {
      final request = GenerateRequest.fromJson(const {
        'messages': [
          {'role': 'user', 'content': 'hi'},
        ],
      });
      expect(request.prompt, 'hi');
      expect(request.history, isEmpty);
    });

    test('splits messages into history and prompt', () {
      final request = GenerateRequest.fromJson(const {
        'messages': [
          {'role': 'user', 'content': 'a'},
          {'role': 'assistant', 'content': 'b'},
          {'role': 'user', 'content': 'c'},
        ],
      });
      expect(request.prompt, 'c');
      expect(request.history.map((m) => m.content), ['a', 'b']);
      expect(request.history.map((m) => m.role), [
        GenerateMessageRole.user,
        GenerateMessageRole.assistant,
      ]);
    });

    test('rejects empty messages list', () {
      expect(
        () => GenerateRequest.fromJson(const {'messages': <dynamic>[]}),
        throwsFormatException,
      );
    });

    test('rejects missing messages key', () {
      expect(() => GenerateRequest.fromJson(const {}), throwsFormatException);
    });

    test('rejects when the last message is not from the user', () {
      expect(
        () => GenerateRequest.fromJson(const {
          'messages': [
            {'role': 'user', 'content': 'a'},
            {'role': 'assistant', 'content': 'b'},
          ],
        }),
        throwsFormatException,
      );
    });

    test('rejects empty content', () {
      expect(
        () => GenerateRequest.fromJson(const {
          'messages': [
            {'role': 'user', 'content': ''},
          ],
        }),
        throwsFormatException,
      );
    });

    test('rejects unknown role', () {
      expect(
        () => GenerateRequest.fromJson(const {
          'messages': [
            {'role': 'system', 'content': 'nope'},
          ],
        }),
        throwsFormatException,
      );
    });

    test('rejects non-list messages', () {
      expect(
        () => GenerateRequest.fromJson(const {'messages': 'nope'}),
        throwsFormatException,
      );
    });
  });
}
