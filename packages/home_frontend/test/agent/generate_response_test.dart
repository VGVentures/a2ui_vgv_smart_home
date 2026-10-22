import 'package:flutter_test/flutter_test.dart';
import 'package:home_frontend/src/agent/generate_response.dart';

void main() {
  group(GenerateResponse, () {
    group('fromJson', () {
      test('reads the text', () {
        final response = GenerateResponse.fromJson(const {'text': 'hello'});

        expect(response.text, 'hello');
      });

      test('defaults missing text to the empty string', () {
        final response = GenerateResponse.fromJson(const {});

        expect(response.text, '');
      });

      test('throws when text is present but not a string', () {
        expect(
          () => GenerateResponse.fromJson(const {'text': 42}),
          throwsFormatException,
        );
      });
    });

    group('fromBody', () {
      test('decodes a JSON object body', () {
        final response = GenerateResponse.fromBody('{"text":"hi"}');

        expect(response.text, 'hi');
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
