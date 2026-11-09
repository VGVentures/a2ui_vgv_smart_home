import 'dart:convert';
import 'dart:io';

import 'package:dart_frog/dart_frog.dart';
import 'package:genkit/genkit.dart' show Message, MessageExtension, Role;
import 'package:home_backend/a2ui/reply_pipeline.dart';
import 'package:home_backend/data/mock_database.dart';
import 'package:home_backend/gemini_key/gemini_api_key.dart';
import 'package:home_backend/llm/llm.dart';
import 'package:home_backend/prompt/system_prompt.dart';
import 'package:home_backend/scenario/scenario_world.dart';
import 'package:mocktail/mocktail.dart';
import 'package:test/test.dart';

import '../../routes/generate.dart' as route;
import '../helpers/pipeline.dart';
import '../helpers/replies.dart';

class _MockRequestContext extends Mock implements RequestContext {}

class _MockRequest extends Mock implements Request {}

void main() {
  group('POST /generate', () {
    late _MockRequestContext context;
    late _MockRequest request;
    late List<List<Message>> calls;
    late List<String> keys;
    late List<String> replies;

    void send(Object? body) {
      when(() => request.method).thenReturn(HttpMethod.post);
      when(request.json).thenAnswer((_) async => body);
    }

    Map<String, dynamic> conversation({bool surface = false}) => {
      'messages': [
        {'role': 'user', 'content': 'earlier'},
        {'role': 'assistant', 'content': 'a surface'},
        {'role': 'user', 'content': 'hello'},
      ],
      'metadata': rendererMetadata(
        surfaces: [if (surface) 'dashboard'],
      ),
    };

    Future<Map<String, dynamic>> bodyOf(Response response) async =>
        jsonDecode(await response.body()) as Map<String, dynamic>;

    setUp(() async {
      context = _MockRequestContext();
      request = _MockRequest();
      calls = [];
      keys = [];
      replies = [createReply()];
      final database = await MockDatabase.load();
      ScenarioWorld(database);
      when(() => context.request).thenReturn(request);
      when(
        () => context.read<GeminiApiKey>(),
      ).thenReturn(const GeminiApiKey('caller-key'));
      when(
        () => context.read<SystemPrompt>(),
      ).thenReturn(const SystemPrompt('SYSTEM'));
      when(
        () => context.read<ReplyPipeline>(),
      ).thenReturn(buildPipeline(database));
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
      expect((await bodyOf(response))['message'], contains('messages'));
    });

    test('responds 400 when the last message is not from the user', () async {
      send({
        'messages': [
          {'role': 'user', 'content': 'a'},
          {'role': 'assistant', 'content': 'b'},
        ],
        'metadata': rendererMetadata(),
      });

      final response = await route.onRequest(context);

      expect(response.statusCode, HttpStatus.badRequest);
      expect((await bodyOf(response))['message'], contains('user'));
    });

    test('responds 400 when the renderer does not list the catalog', () async {
      send({
        ...conversation(),
        'metadata': {
          'a2uiRendererCapabilities': {
            '1.0': {
              'supportedCatalogIds': ['somebody/else'],
            },
          },
        },
      });

      final response = await route.onRequest(context);

      expect(response.statusCode, HttpStatus.badRequest);
      expect((await bodyOf(response))['message'], contains('catalog'));
      expect(calls, isEmpty);
    });

    test('creates the dashboard when the panel shows none', () async {
      send(conversation());

      final response = await route.onRequest(context);

      expect(response.statusCode, HttpStatus.ok);
      final body = await bodyOf(response);
      final messages = (body['messages'] as List).cast<Json>();
      expect(messages, hasLength(1));
      final create = messages.single['createSurface']! as Json;
      expect(create['surfaceId'], 'dashboard');
      expect(create['sendDataModel'], isTrue);
      expect(create['components'], isNotEmpty);
      expect(create['dataModel'], contains('devices'));
    });

    test('returns the trimmed text of the model as the reply', () async {
      replies = ['  ${createReply()}  '];
      send(conversation());

      final response = await route.onRequest(context);

      expect((await bodyOf(response))['reply'], createReply());
    });

    test('updates the dashboard when the panel already shows it', () async {
      replies = [updateReply()];
      send(conversation(surface: true));

      final response = await route.onRequest(context);

      expect(response.statusCode, HttpStatus.ok);
      final messages = ((await bodyOf(response))['messages'] as List)
          .cast<Json>();
      expect(messages.last, contains('updateComponents'));
      expect(
        messages.take(messages.length - 1),
        everyElement(contains('updateDataModel')),
      );
      expect(messages.any((m) => m.containsKey('createSurface')), isFalse);
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
        expect(messages.map((m) => m.text).take(3), [
          'SYSTEM',
          'earlier',
          'a surface',
        ]);
        expect(messages.last.text, startsWith('hello'));
      },
    );

    test('tells the model to create a surface the panel lacks', () async {
      send(conversation());

      await route.onRequest(context);

      expect(calls.single.last.text, contains('does not exist yet'));
    });

    test('tells the model to update a surface the panel shows', () async {
      replies = [updateReply()];
      send(conversation(surface: true));

      await route.onRequest(context);

      expect(calls.single.last.text, contains('already on screen'));
    });

    test('retries once with the errors fed back, then succeeds', () async {
      replies = ['I am sorry, no.', createReply()];
      send(conversation());

      final response = await route.onRequest(context);

      expect(response.statusCode, HttpStatus.ok);
      expect((await bodyOf(response))['reply'], createReply());
      expect(calls, hasLength(2));
      final retry = calls.last;
      expect(retry[retry.length - 2].role, Role.model);
      expect(retry[retry.length - 2].text, 'I am sorry, no.');
      expect(retry.last.role, Role.user);
      expect(retry.last.text, contains('no A2UI message'));
    });

    test('feeds back a component the catalog does not declare', () async {
      replies = [
        createReply(
          components: [
            {
              'id': 'root',
              'component': 'Column',
              'children': ['x'],
            },
            {'id': 'x', 'component': 'Carousel'},
          ],
        ),
        createReply(),
      ];
      send(conversation());

      final response = await route.onRequest(context);

      expect(response.statusCode, HttpStatus.ok);
      expect(calls.last.last.text, contains('Carousel'));
    });

    test('feeds back a child id that is not defined', () async {
      replies = [
        createReply(
          components: [
            {
              'id': 'root',
              'component': 'Column',
              'children': ['ghost'],
            },
          ],
        ),
        createReply(),
      ];
      send(conversation());

      final response = await route.onRequest(context);

      expect(response.statusCode, HttpStatus.ok);
      expect(calls.last.last.text, contains('ghost'));
    });

    test("calls the model with the caller's key", () async {
      send(conversation());

      await route.onRequest(context);

      expect(keys, ['caller-key']);
    });

    test('responds 422 when the retry fails validation too', () async {
      replies = ['bad', 'still bad'];
      send(conversation());

      final response = await route.onRequest(context);

      expect(response.statusCode, HttpStatus.unprocessableEntity);
      expect(calls, hasLength(2));
    });

    test('retries on the update path with the same surface note', () async {
      replies = ['prose', updateReply()];
      send(conversation(surface: true));

      final response = await route.onRequest(context);

      expect(response.statusCode, HttpStatus.ok);
      expect(calls, hasLength(2));
      expect(calls.first.last.text, contains('already on screen'));
      final messages = ((await bodyOf(response))['messages'] as List)
          .cast<Json>();
      expect(messages.last, contains('updateComponents'));
    });

    test('responds 502 when the retry call itself fails', () async {
      var count = 0;
      when(() => context.read<Generate>()).thenReturn((_, _) async {
        if (count++ == 0) return 'prose';
        throw Exception('down');
      });
      send(conversation());

      final response = await route.onRequest(context);

      expect(response.statusCode, HttpStatus.badGateway);
    });

    test('answers 422 with a generic message', () async {
      replies = ['bad', 'worse'];
      send(conversation());

      final response = await route.onRequest(context);

      expect(
        (await bodyOf(response))['message'],
        'Failed to generate a response.',
      );
    });

    test('never returns the caller key in a failure body', () async {
      when(
        () => context.read<Generate>(),
      ).thenReturn((_, _) async => throw Exception('bad key caller-key'));
      send(conversation());

      final response = await route.onRequest(context);

      expect(await response.body(), isNot(contains('caller-key')));
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
