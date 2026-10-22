import 'dart:convert';
import 'dart:io';

import 'package:dart_frog/dart_frog.dart';
import 'package:genkit/genkit.dart' show Message, MessageExtension, Role;
import 'package:home_backend/gemini_key/gemini_api_key.dart';
import 'package:home_backend/llm/llm.dart';
import 'package:home_backend/prompt/system_prompt.dart';
import 'package:home_backend/validation/llm_response_validator.dart';
import 'package:mocktail/mocktail.dart';
import 'package:test/test.dart';

import '../../routes/generate.dart' as route;

class _MockRequestContext extends Mock implements RequestContext {}

class _MockRequest extends Mock implements Request {}

/// Rejects every reply that is not `good`.
class _WantsGood implements LlmResponseValidator {
  @override
  List<String>? validate(String response) =>
      response == 'good' ? null : ['Reply must be good.'];
}

/// Wants `good`, and mends `fixable` into it without asking the model again.
class _MendsToGood implements LlmResponseValidator, LlmResponseRepairer {
  @override
  List<String>? validate(String response) =>
      response == 'good' ? null : ['Reply must be good.'];

  @override
  String repair(String response) => response == 'fixable' ? 'good' : response;
}

void main() {
  group('POST /generate', () {
    late _MockRequestContext context;
    late _MockRequest request;
    late List<List<Message>> calls;
    late List<String> keys;
    late List<String> replies;
    late List<LlmResponseValidator> validators;

    void send(Object? body) {
      when(() => request.method).thenReturn(HttpMethod.post);
      when(request.json).thenAnswer((_) async => body);
    }

    Map<String, dynamic> conversation() => {
      'messages': [
        {'role': 'user', 'content': 'earlier'},
        {'role': 'assistant', 'content': 'a surface'},
        {'role': 'user', 'content': 'hello'},
      ],
    };

    setUp(() {
      context = _MockRequestContext();
      request = _MockRequest();
      calls = [];
      keys = [];
      replies = ['  surface  '];
      validators = [];
      when(() => context.request).thenReturn(request);
      when(
        () => context.read<GeminiApiKey>(),
      ).thenReturn(const GeminiApiKey('caller-key'));
      when(
        () => context.read<SystemPrompt>(),
      ).thenReturn(const SystemPrompt('SYSTEM'));
      when(
        () => context.read<List<LlmResponseValidator>>(),
      ).thenAnswer((_) => validators);
      when(() => context.read<Generate>()).thenReturn((key, messages) async {
        keys.add(key);
        calls.add([...messages]);
        return replies[(calls.length - 1).clamp(0, replies.length - 1)];
      });
    });

    test('responds 405 for non-POST requests', () async {
      when(() => request.method).thenReturn(HttpMethod.get);

      final response = await route.onRequest(context);

      expect(response.statusCode, HttpStatus.methodNotAllowed);
      expect(calls, isEmpty);
    });

    test('responds 400 when the JSON body is malformed', () async {
      send('not a map');

      final response = await route.onRequest(context);

      expect(response.statusCode, HttpStatus.badRequest);
      expect(calls, isEmpty);
    });

    test('responds 400 when messages is missing', () async {
      send(<String, dynamic>{});

      final response = await route.onRequest(context);

      expect(response.statusCode, HttpStatus.badRequest);
      final body = jsonDecode(await response.body()) as Map<String, dynamic>;
      expect(body['message'], contains('messages'));
    });

    test('responds 400 when the last message is not from the user', () async {
      send({
        'messages': [
          {'role': 'user', 'content': 'a'},
          {'role': 'assistant', 'content': 'b'},
        ],
      });

      final response = await route.onRequest(context);

      expect(response.statusCode, HttpStatus.badRequest);
      final body = jsonDecode(await response.body()) as Map<String, dynamic>;
      expect(body['message'], contains('user'));
    });

    test('returns the trimmed reply as JSON', () async {
      send(conversation());

      final response = await route.onRequest(context);

      expect(response.statusCode, HttpStatus.ok);
      expect(jsonDecode(await response.body()), {'text': 'surface'});
    });

    test(
      'sends one system message, then the history, then the prompt',
      () async {
        send(conversation());

        await route.onRequest(context);

        final messages = calls.single;
        expect(messages.map((m) => m.role), [
          Role.system,
          Role.user,
          Role.model,
          Role.user,
        ]);
        expect(messages.map((m) => m.text), [
          'SYSTEM',
          'earlier',
          'a surface',
          'hello',
        ]);
      },
    );

    test('retries once with the errors fed back, then succeeds', () async {
      validators = [_WantsGood()];
      replies = ['bad', 'good'];
      send(conversation());

      final response = await route.onRequest(context);

      expect(response.statusCode, HttpStatus.ok);
      expect(jsonDecode(await response.body()), {'text': 'good'});
      expect(calls, hasLength(2));
      final retry = calls.last;
      expect(retry[retry.length - 2].role, Role.model);
      expect(retry[retry.length - 2].text, 'bad');
      expect(retry.last.role, Role.user);
      expect(retry.last.text, contains('Reply must be good.'));
    });

    test('mends what a validator can mend without a retry', () async {
      validators = [_MendsToGood()];
      replies = ['  fixable  ', 'never asked for'];
      send(conversation());

      final response = await route.onRequest(context);

      expect(response.statusCode, HttpStatus.ok);
      expect(jsonDecode(await response.body()), {'text': 'good'});
      expect(calls, hasLength(1));
    });

    test('mends the retry too, and retries what it cannot mend', () async {
      validators = [_MendsToGood()];
      replies = ['bad', 'fixable'];
      send(conversation());

      final response = await route.onRequest(context);

      expect(response.statusCode, HttpStatus.ok);
      expect(jsonDecode(await response.body()), {'text': 'good'});
      expect(calls, hasLength(2));
    });

    test("calls the model with the caller's key", () async {
      send(conversation());

      await route.onRequest(context);

      expect(keys, ['caller-key']);
    });

    test('responds 422 when the retry fails validation too', () async {
      validators = [_WantsGood()];
      replies = ['bad', 'still bad'];
      send(conversation());

      final response = await route.onRequest(context);

      expect(response.statusCode, HttpStatus.unprocessableEntity);
      expect(calls, hasLength(2));
    });

    test(
      'responds 502 without leaking the cause when the model fails',
      () async {
        when(
          () => context.read<Generate>(),
        ).thenReturn((_, _) async => throw Exception('SECRET'));
        send(conversation());

        final response = await route.onRequest(context);

        expect(response.statusCode, HttpStatus.badGateway);
        expect(await response.body(), isNot(contains('SECRET')));
      },
    );
  });
}
