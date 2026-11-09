import 'package:home_backend/gemini_key/gemini_api_key.dart';
import 'package:test/test.dart';

void main() {
  group('GeminiApiKey', () {
    const key = GeminiApiKey('AIza-secret');

    test('holds the key it was given', () {
      expect(key.value, 'AIza-secret');
    });

    test('hides the key when printed', () {
      expect('$key', isNot(contains('AIza-secret')));
    });

    test('redacts every occurrence of the key in a text', () {
      final text = key.redact('bad AIza-secret and again AIza-secret');

      expect(text, 'bad [redacted] and again [redacted]');
    });
  });
}
