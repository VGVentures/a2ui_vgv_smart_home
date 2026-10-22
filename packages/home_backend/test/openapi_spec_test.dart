import 'dart:convert';
import 'dart:io';

import 'package:home_backend/action/action_command.dart';
import 'package:home_backend/action/action_request.dart';
import 'package:home_backend/api_error.dart';
import 'package:home_backend/data/mock_database.dart';
import 'package:home_backend/generate/generate_request.dart';
import 'package:home_backend/live/live_session.dart';
import 'package:home_backend/transcribe/transcribe_relay.dart';
import 'package:test/test.dart';

void main() {
  late Map<String, dynamic> document;

  setUpAll(() async {
    final source = await File('openapi.json').readAsString();
    document = jsonDecode(source) as Map<String, dynamic>;
  });

  Map<String, dynamic> schema(String name) =>
      ((document['components'] as Map<String, dynamic>)['schemas']
              as Map<String, dynamic>)[name]
          as Map<String, dynamic>;

  Set<String> schemaProperties(String name) =>
      (schema(name)['properties'] as Map<String, dynamic>).keys.toSet();

  test('is an OpenAPI 3.1 document with the public health operation', () {
    expect(document['openapi'], '3.1.0');

    final paths = document['paths'] as Map<String, dynamic>;
    expect(paths['/health'] as Map<String, dynamic>, contains('get'));
    // The document is a static file, not an HTTP endpoint, so it does not
    // describe a path for itself.
    expect(paths, isNot(contains('/openapi.json')));

    final health =
        (paths['/health'] as Map<String, dynamic>)['get']
            as Map<String, dynamic>;
    expect(health['security'], isEmpty);
  });

  test('describes the authenticated generate contract', () {
    final paths = document['paths'] as Map<String, dynamic>;
    final generate =
        (paths['/generate'] as Map<String, dynamic>)['post']
            as Map<String, dynamic>;

    expect(generate['operationId'], 'generateResponse');
    expect(generate['security'], [
      {'geminiKey': <dynamic>[]},
    ]);
    expect(
      (generate['requestBody'] as Map<String, dynamic>)['required'],
      isTrue,
    );
    expect(
      (generate['responses'] as Map<String, dynamic>).keys,
      containsAll(['200', '400', '401', '422', '500', '502']),
    );
  });

  test('describes the authenticated action contract', () {
    final paths = document['paths'] as Map<String, dynamic>;
    final action =
        (paths['/action'] as Map<String, dynamic>)['post']
            as Map<String, dynamic>;

    expect(action['operationId'], 'applyAction');
    expect(action['security'], [
      {'geminiKey': <dynamic>[]},
    ]);
    expect(
      (action['responses'] as Map<String, dynamic>).keys,
      containsAll(['200', '400', '401', '404', '409', '422', '500', '502']),
    );
    expect(
      ((action['requestBody'] as Map<String, dynamic>)['content']
          as Map<String, dynamic>)['application/json'],
      {
        'schema': {r'$ref': '#/components/schemas/ActionRequest'},
      },
    );
    final responses =
        (document['components'] as Map<String, dynamic>)['responses']
            as Map<String, dynamic>;
    expect(responses.keys, containsAll(['NotFound', 'Conflict']));
  });

  test('describes the transcribe WebSocket as the relay speaks it', () {
    final paths = document['paths'] as Map<String, dynamic>;
    final transcribe =
        (paths['/transcribe'] as Map<String, dynamic>)['get']
            as Map<String, dynamic>;

    expect(transcribe['operationId'], 'transcribe');
    expect(transcribe['security'], [
      {'webSocketGeminiKey': <dynamic>[]},
    ]);
    expect(
      (transcribe['responses'] as Map<String, dynamic>).keys,
      containsAll(['101', '401', '403', '404']),
    );
    expect(
      transcribe['description'] as String,
      allOf(
        contains('`$transcribeProtocol`'),
        contains('`$transcribeUnsupportedMessageCode`'),
        contains('`$transcribeProviderFailedCode`'),
      ),
    );

    final schemes =
        (document['components'] as Map<String, dynamic>)['securitySchemes']
            as Map<String, dynamic>;
    expect(schemes['webSocketGeminiKey'], containsPair('in', 'header'));
    expect(
      schemes['webSocketGeminiKey'],
      containsPair('name', 'Sec-WebSocket-Protocol'),
    );
  });

  test('describes the live WebSocket as the session speaks it', () {
    final paths = document['paths'] as Map<String, dynamic>;
    final live =
        (paths['/live'] as Map<String, dynamic>)['get'] as Map<String, dynamic>;

    expect(live['operationId'], 'live');
    expect(live['security'], isEmpty);
    expect(
      (live['responses'] as Map<String, dynamic>).keys,
      containsAll(['101', '403', '404']),
    );
    expect(
      live['description'] as String,
      allOf(
        contains('`$liveProtocol`'),
        contains('"type": "clock"'),
        contains('"type": "a2ui"'),
        contains('"type": "inbox"'),
        contains('"type": "changed"'),
        contains('"type": "error"'),
      ),
    );
  });

  test('describes the users operations', () {
    final paths = document['paths'] as Map<String, dynamic>;
    final list =
        (paths['/users'] as Map<String, dynamic>)['get']
            as Map<String, dynamic>;
    expect(list['operationId'], 'listUsers');
    expect(list['security'], isEmpty);

    final one =
        (paths['/users/{id}'] as Map<String, dynamic>)['get']
            as Map<String, dynamic>;
    expect(one['operationId'], 'getUser');
    expect(
      (one['responses'] as Map<String, dynamic>).keys,
      containsAll(['200', '404']),
    );
  });

  test('users schemas match what the database serves', () async {
    final database = await MockDatabase.load();
    final summary = database.listProfiles().first;
    expect(schemaProperties('UserSummary'), summary.keys.toSet());
    expect(
      schemaProperties('User'),
      containsAll(database.findUser('ana')!.keys),
    );
  });

  test('defines all request, success, and error schemas', () {
    final components = document['components'] as Map<String, dynamic>;
    final schemas = components['schemas'] as Map<String, dynamic>;
    expect(
      schemas.keys,
      containsAll([
        'GenerateMessage',
        'GenerateRequest',
        'GenerateResponse',
        'ApiError',
      ]),
    );

    final schemes = components['securitySchemes'] as Map<String, dynamic>;
    expect(schemes['geminiKey'], containsPair('scheme', 'bearer'));

    final message = schemas['GenerateMessage'] as Map<String, dynamic>;
    expect(message['type'], 'object');
    expect(message['required'], containsAll(['role', 'content']));
    final messageProperties = message['properties'] as Map<String, dynamic>;
    expect((messageProperties['role'] as Map<String, dynamic>)['enum'], [
      'user',
      'assistant',
    ]);

    final request = schemas['GenerateRequest'] as Map<String, dynamic>;
    expect(request['required'], ['messages']);
    final requestProperties = request['properties'] as Map<String, dynamic>;
    final messages = requestProperties['messages'] as Map<String, dynamic>;
    expect(messages['type'], 'array');
    expect(messages['minItems'], 1);
    expect(messages['items'], {
      r'$ref': '#/components/schemas/GenerateMessage',
    });

    final response = schemas['GenerateResponse'] as Map<String, dynamic>;
    expect(response['required'], ['text']);
    final responseProperties = response['properties'] as Map<String, dynamic>;
    expect(
      (responseProperties['text'] as Map<String, dynamic>)['type'],
      'string',
    );

    final error = schemas['ApiError'] as Map<String, dynamic>;
    expect(error['required'], ['message']);
    final errorProperties = error['properties'] as Map<String, dynamic>;
    expect(
      (errorProperties['message'] as Map<String, dynamic>)['type'],
      'string',
    );
  });

  // These tests exercise the real model classes so the schemas cannot silently
  // drift from the code that produces and parses the wire format. A shape-only
  // check passes even after a field is added to a model; these fail.
  group('stays in sync with the Dart models it documents', () {
    test(
      'Action schema lists exactly the action names the backend accepts',
      () {
        final name =
            (schema('Action')['properties'] as Map<String, dynamic>)['name']
                as Map<String, dynamic>;
        expect(name['enum'], ActionCommand.names);
        expect(schemaProperties('Action'), {'name', 'context'});
        expect(schema('Action')['required'], ['name', 'context']);
      },
    );

    test('ActionRequest schema is what ActionRequest parses', () {
      expect(schemaProperties('ActionRequest'), {'messages', 'action'});
      expect(schema('ActionRequest')['required'], ['messages', 'action']);
      final parsed = ActionRequest.fromJson({
        'messages': [
          {'role': 'user', 'content': 'x'},
        ],
        'action': {
          'name': 'share_list',
          'context': {'listId': 'shopping'},
        },
      });
      expect(parsed.command, isA<ShareList>());
    });

    test('ApiError schema lists exactly the serialized keys', () {
      expect(
        schemaProperties('ApiError'),
        const ApiError.internalServerError().toJson().keys.toSet(),
      );
    });

    test('GenerateResponse schema lists exactly the success body keys', () {
      // Mirrors the body built in routes/generate.dart.
      final body = <String, dynamic>{'text': 'x'};
      expect(schemaProperties('GenerateResponse'), body.keys.toSet());
    });

    test('GenerateMessage role enum matches what the parser accepts', () {
      final roles =
          ((schema('GenerateMessage')['properties']
                      as Map<String, dynamic>)['role']
                  as Map<String, dynamic>)['enum']
              as List;

      // Every role the schema advertises must parse.
      for (final role in roles) {
        expect(
          () => GenerateMessage.fromJson(<String, dynamic>{
            'role': role,
            'content': 'hi',
          }),
          returnsNormally,
        );
      }

      // A role outside the schema's enum must be rejected.
      expect(
        () => GenerateMessage.fromJson(<String, dynamic>{
          'role': 'system',
          'content': 'hi',
        }),
        throwsFormatException,
      );
    });

    test('GenerateMessage content rules match the parser', () {
      final content =
          (schema('GenerateMessage')['properties']
                  as Map<String, dynamic>)['content']
              as Map<String, dynamic>;
      expect(content['minLength'], 1);

      // The schema requires a non-empty string; the parser rejects the empty
      // one.
      expect(
        () => GenerateMessage.fromJson(<String, dynamic>{
          'role': 'user',
          'content': '',
        }),
        throwsFormatException,
      );
    });

    test('GenerateRequest messages rules match the parser', () {
      final request = schema('GenerateRequest');
      expect(request['required'], ['messages']);
      final messages =
          (request['properties'] as Map<String, dynamic>)['messages']
              as Map<String, dynamic>;
      expect(messages['minItems'], 1);

      // The schema requires a non-empty list; the parser rejects the empty one.
      expect(
        () => GenerateRequest.fromJson(<String, dynamic>{
          'messages': <dynamic>[],
        }),
        throwsFormatException,
      );
    });
  });
}
