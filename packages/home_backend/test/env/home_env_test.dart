import 'package:home_backend/env/home_env.dart';
import 'package:home_backend/env/home_var.dart';
import 'package:test/test.dart';

void main() {
  group('HomeEnv', () {
    group('requireNonEmpty', () {
      test('returns the value when set', () {
        final env = HomeEnv(const {'HOME_LLM_MODEL': 'gemini-x'});
        expect(env.requireNonEmpty(HomeVar.llmModel), 'gemini-x');
      });

      test('throws when the variable is missing', () {
        final env = HomeEnv(const {});
        expect(
          () => env.requireNonEmpty(HomeVar.llmModel),
          throwsA(
            isA<HomeEnvException>().having(
              (e) => e.message,
              'message',
              contains('HOME_LLM_MODEL'),
            ),
          ),
        );
      });

      test('throws when the variable is set to an empty string', () {
        final env = HomeEnv(const {'HOME_LLM_MODEL': ''});
        expect(
          () => env.requireNonEmpty(HomeVar.llmModel),
          throwsA(isA<HomeEnvException>()),
        );
      });
    });

    group('optional', () {
      test('returns the value when set', () {
        final env = HomeEnv(const {'HOME_LLM_MODEL': 'gemini-x'});
        expect(env.optional(HomeVar.llmModel), 'gemini-x');
      });

      test('returns null when the variable is missing', () {
        final env = HomeEnv(const {});
        expect(env.optional(HomeVar.llmModel), isNull);
      });

      test('returns null when the variable is set to an empty string', () {
        final env = HomeEnv(const {'HOME_LLM_MODEL': ''});
        expect(env.optional(HomeVar.llmModel), isNull);
      });
    });
  });
}
