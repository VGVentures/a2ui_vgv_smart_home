import 'dart:convert';
import 'dart:io';

import 'package:dart_frog/dart_frog.dart';
import 'package:genkit/genkit.dart' show Message, MessageExtension, Role;
import 'package:home_backend/data/mock_database.dart';
import 'package:home_backend/devices/device_state_machine.dart';
import 'package:home_backend/gemini_key/gemini_api_key.dart';
import 'package:home_backend/llm/llm.dart';
import 'package:home_backend/prompt/system_prompt.dart';
import 'package:home_backend/validation/llm_response_validator.dart';
import 'package:mocktail/mocktail.dart';
import 'package:test/test.dart';

import '../../routes/action.dart' as route;
import '../fixtures/fixture_database.dart';

class _MockRequestContext extends Mock implements RequestContext {}

class _MockRequest extends Mock implements Request {}

class _FixedValidator implements LlmResponseValidator {
  @override
  List<String>? validate(String response) => ['bad'];
}

const _interaction =
    '{"action":{"name":"toggle_device","context":{"deviceId":"oven"}}}';

Map<String, dynamic> _body(
  String name,
  Map<String, dynamic> context, {
  String? last,
}) => {
  'messages': [
    {'role': 'user', 'content': 'earlier'},
    {'role': 'assistant', 'content': 'a surface'},
    {'role': 'user', 'content': last ?? _interaction},
  ],
  'action': {'name': name, 'context': context},
};

void main() {
  group('POST /action', () {
    late _MockRequestContext context;
    late _MockRequest request;
    late List<List<Message>> calls;
    late Generate generate;
    late MockDatabase database;
    late DeviceStateMachine machine;

    Future<Map<String, dynamic>> json(Response response) async =>
        jsonDecode(await response.body()) as Map<String, dynamic>;

    void send(Object? body) {
      when(() => request.method).thenReturn(HttpMethod.post);
      when(request.json).thenAnswer((_) async => body);
    }

    setUp(() async {
      context = _MockRequestContext();
      request = _MockRequest();
      calls = [];
      generate = (key, messages) async {
        calls.add([...messages]);
        return 'surface';
      };
      database = await loadFixtureDatabase();
      machine = DeviceStateMachine(database);
      when(() => context.request).thenReturn(request);
      when(() => context.read<DeviceStateMachine>()).thenReturn(machine);
      when(
        () => context.read<SystemPrompt>(),
      ).thenReturn(const SystemPrompt('A2UI INSTRUCTIONS'));
      when(
        () => context.read<List<LlmResponseValidator>>(),
      ).thenReturn(const <LlmResponseValidator>[]);
      when(() => context.read<Generate>()).thenAnswer((_) => generate);
      when(
        () => context.read<GeminiApiKey>(),
      ).thenReturn(const GeminiApiKey('caller-key'));
    });

    void verifyNoGeneration() => expect(calls, isEmpty);

    test('responds 405 for non-POST requests', () async {
      when(() => request.method).thenReturn(HttpMethod.get);

      final response = await route.onRequest(context);

      expect(response.statusCode, HttpStatus.methodNotAllowed);
    });

    test('applies the command, then generates with a note', () async {
      send(
        _body('toggle_device', {
          'progressLabel': 'Turn on oven',
          'deviceId': 'oven',
          'on': true,
        }),
      );

      final response = await route.onRequest(context);

      expect(response.statusCode, HttpStatus.ok);
      final body = await json(response);
      expect(body['text'], 'surface');
      // The state changed before the model ran.
      final oven = database.homeDevices.firstWhere((d) => d['id'] == 'oven');
      final traits = oven['traits'] as Map<String, dynamic>;
      expect(
        (traits['OperationalState'] as Map<String, dynamic>)['state'],
        'running',
      );
      final messages = calls.single;
      final prompt = messages.last.text;
      expect(prompt, startsWith(_interaction));
      expect(
        prompt,
        contains(
          'The backend already applied this command: '
          'oven state: stopped -> running.',
        ),
      );
      expect(prompt, contains('do not claim anything the data does not show'));
      // The history keeps the earlier turns and the layered system message.
      expect(messages.first.role, Role.system);
      expect(messages.first.text, contains('A2UI INSTRUCTIONS'));
      expect(
        messages.map((m) => m.text),
        containsAll(['earlier', 'a surface']),
      );
    });

    test('undo_change reverts the last change and still generates', () async {
      send(_body('toggle_device', {'deviceId': 'oven', 'on': true}));
      await route.onRequest(context);
      send(_body('undo_change', {}));

      final response = await route.onRequest(context);

      expect(response.statusCode, HttpStatus.ok);
      final oven = database.homeDevices.firstWhere((d) => d['id'] == 'oven');
      expect(
        ((oven['traits'] as Map)['OperationalState'] as Map)['state'],
        'stopped',
      );
    });

    test('a press that changes nothing says so and still generates', () async {
      send(_body('undo_change', {}));

      final response = await route.onRequest(context);

      expect(response.statusCode, HttpStatus.ok);
      expect(calls.single.last.text, contains('no device state changed'));
    });

    test('responds 400 for a body that is not an object', () async {
      send('not a map');

      final response = await route.onRequest(context);

      expect(response.statusCode, HttpStatus.badRequest);
      expect(
        (await json(response))['message'],
        "That action couldn't be understood.",
      );
      verifyNoGeneration();
    });

    test('responds 400 for an unknown action name, including ask', () async {
      for (final name in ['launch_rocket', 'ask', 'suggestion_selected']) {
        send(_body(name, {'text': 'hello'}));

        final response = await route.onRequest(context);

        expect(response.statusCode, HttpStatus.badRequest);
        expect(
          (await json(response))['message'],
          "That action isn't supported.",
        );
      }
      verifyNoGeneration();
    });

    test('responds 400 for a missing or mistyped field', () async {
      send(_body('toggle_device', {'deviceId': 'oven', 'on': 'true'}));

      final response = await route.onRequest(context);

      expect(response.statusCode, HttpStatus.badRequest);
      expect(
        (await json(response))['message'],
        "That action couldn't be understood.",
      );
      verifyNoGeneration();
    });

    test(
      'responds 400 for missing action, context fields or messages',
      () async {
        for (final body in <Object?>[
          {
            'messages': [
              {'role': 'user', 'content': 'x'},
            ],
          },
          {
            'messages': [
              {'role': 'user', 'content': 'x'},
            ],
            'action': 'toggle_device',
          },
        ]) {
          send(body);
          final response = await route.onRequest(context);
          expect(response.statusCode, HttpStatus.badRequest);
          expect(
            (await json(response))['message'],
            "That action couldn't be understood.",
          );
        }
        verifyNoGeneration();
      },
    );

    test('responds 404 for an unknown device and does not generate', () async {
      send(_body('toggle_device', {'deviceId': 'ovenn', 'on': true}));

      final response = await route.onRequest(context);

      expect(response.statusCode, HttpStatus.notFound);
      expect((await json(response))['message'], "Couldn't find the ovenn.");
      verifyNoGeneration();
    });

    test('responds 409 when the device rejects the command', () async {
      database.homeDevices.firstWhere((d) => d['id'] == 'oven')['online'] =
          false;
      send(_body('toggle_device', {'deviceId': 'oven', 'on': true}));

      final response = await route.onRequest(context);

      expect(response.statusCode, HttpStatus.conflict);
      expect((await json(response))['message'], 'The oven is offline.');
      verifyNoGeneration();
    });

    test('maps generation failures like /generate', () async {
      generate = (_, _) async => throw Exception('SECRET');
      send(_body('share_list', {'listId': 'shopping'}));

      final response = await route.onRequest(context);

      expect(response.statusCode, HttpStatus.badGateway);
      expect(await response.body(), isNot(contains('SECRET')));
    });

    test('maps exhausted validation to 422', () async {
      when(
        () => context.read<List<LlmResponseValidator>>(),
      ).thenReturn([_FixedValidator()]);
      send(
        _body('toggle_todo', {
          'listId': 'shopping',
          'itemId': 'ribs',
          'checked': true,
        }),
      );

      final response = await route.onRequest(context);

      expect(response.statusCode, HttpStatus.unprocessableEntity);
    });
  });
}
