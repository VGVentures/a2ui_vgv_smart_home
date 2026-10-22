import 'dart:io';

import 'package:home_backend/env/dotenv_loader.dart';
import 'package:test/test.dart';

void main() {
  group('loadDotEnv', () {
    late Directory tempDir;

    setUp(() {
      tempDir = Directory.systemTemp.createTempSync('home_dotenv_test_');
    });

    tearDown(() {
      tempDir.deleteSync(recursive: true);
    });

    File writeEnv(String contents) {
      final file = File('${tempDir.path}/.env')..writeAsStringSync(contents);
      return file;
    }

    test('returns an empty map when the file does not exist', () {
      final file = File('${tempDir.path}/.env');
      expect(file.existsSync(), isFalse);
      expect(loadDotEnv(file: file), isEmpty);
    });

    test('parses declared HOME_* values', () {
      final file = writeEnv('''
HOME_LLM_MODEL=gemini-x
HOME_CORS_ALLOWED_ORIGINS=http://localhost:3000
''');

      expect(loadDotEnv(file: file), {
        'HOME_LLM_MODEL': 'gemini-x',
        'HOME_CORS_ALLOWED_ORIGINS': 'http://localhost:3000',
      });
    });

    test('ignores keys that are not declared in HomeVar', () {
      final file = writeEnv('''
HOME_LLM_MODEL=gemini-x
HOME_GOOGLE_API_KEY=a-key-the-server-must-not-read
HOME_MYSTERY=hello
RANDOM_OTHER=ignored
''');

      expect(loadDotEnv(file: file), {'HOME_LLM_MODEL': 'gemini-x'});
    });

    test('skips declared variables that are empty', () {
      final file = writeEnv('''
HOME_CORS_ALLOWED_ORIGINS=http://localhost:3000
HOME_LLM_MODEL=
''');

      expect(loadDotEnv(file: file), {
        'HOME_CORS_ALLOWED_ORIGINS': 'http://localhost:3000',
      });
    });

    test('strips surrounding double quotes from values', () {
      final file = writeEnv('HOME_LLM_MODEL="gemini-x"\n');

      expect(loadDotEnv(file: file), {
        'HOME_LLM_MODEL': 'gemini-x',
      });
    });

    test('ignores comment lines and blank lines', () {
      final file = writeEnv('''
# this is a comment

HOME_LLM_MODEL=gemini-x
# another comment
''');

      expect(loadDotEnv(file: file), {'HOME_LLM_MODEL': 'gemini-x'});
    });
  });
}
