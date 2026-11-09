import 'package:flutter_test/flutter_test.dart';
import 'package:home_frontend/src/agent/generate_response.dart';

void main() {
  group(GenerateResponse, () {
    group('fromJson', () {
      test('reads the messages and the reply', () {
        final response = GenerateResponse.fromJson(const {
          'messages': [
            {
              'version': '1.0',
              'deleteSurface': {'surfaceId': 'dashboard'},
            },
          ],
          'reply': 'hello',
        });

        expect(response.reply, 'hello');
        expect(response.messages, [
          {
            'version': '1.0',
            'deleteSurface': {'surfaceId': 'dashboard'},
          },
        ]);
      });

      test('defaults missing fields to empty', () {
        final response = GenerateResponse.fromJson(const {});

        expect(response.reply, '');
        expect(response.messages, isEmpty);
      });

      test('throws when reply is present but not a string', () {
        expect(
          () => GenerateResponse.fromJson(const {'reply': 42}),
          throwsFormatException,
        );
      });

      test('throws when messages is not a list', () {
        expect(
          () => GenerateResponse.fromJson(const {'messages': 'nope'}),
          throwsFormatException,
        );
      });

      test('throws when a message is not an object', () {
        expect(
          () => GenerateResponse.fromJson(const {
            'messages': [1],
          }),
          throwsFormatException,
        );
      });
    });

    group('fromBody', () {
      test('decodes a JSON object body', () {
        final response = GenerateResponse.fromBody(
          '{"messages":[],"reply":"hi"}',
        );

        expect(response.reply, 'hi');
      });

      test('throws when the body is not valid JSON', () {
        expect(
          () => GenerateResponse.fromBody('<html>oops</html>'),
          throwsFormatException,
        );
      });

      test('throws when the body is a JSON array', () {
        expect(
          () => GenerateResponse.fromBody('[1,2,3]'),
          throwsFormatException,
        );
      });
    });
  });
}
