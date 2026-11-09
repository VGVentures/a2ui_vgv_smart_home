import 'package:a2ui_core/a2ui_core.dart';
import 'package:home_backend/generate/generate_request.dart';
import 'package:test/test.dart';

import '../helpers/pipeline.dart';

void main() {
  group('GenerateRequest.fromJson', () {
    Map<String, Object?> body({
      Object? messages,
      Object? metadata = const _Default(),
    }) => {
      'messages':
          messages ??
          [
            {'role': 'user', 'content': 'hi'},
          ],
      'metadata': metadata is _Default ? rendererMetadata() : metadata,
    };

    Map<String, dynamic> parseable(Map<String, Object?> json) =>
        Map<String, dynamic>.of(json);

    test('parses a single user message', () {
      final request = GenerateRequest.fromJson(parseable(body()));

      expect(request.prompt, 'hi');
      expect(request.history, isEmpty);
    });

    test('splits messages into history and prompt', () {
      final request = GenerateRequest.fromJson(
        parseable(
          body(
            messages: [
              {'role': 'user', 'content': 'a'},
              {'role': 'assistant', 'content': 'b'},
              {'role': 'user', 'content': 'c'},
            ],
          ),
        ),
      );

      expect(request.prompt, 'c');
      expect(request.history.map((m) => m.content), ['a', 'b']);
      expect(request.history.map((m) => m.role), [
        GenerateMessageRole.user,
        GenerateMessageRole.assistant,
      ]);
    });

    test('rejects empty messages list', () {
      expect(
        () => GenerateRequest.fromJson(parseable(body(messages: <dynamic>[]))),
        throwsFormatException,
      );
    });

    test('rejects missing messages key', () {
      expect(
        () => GenerateRequest.fromJson({'metadata': rendererMetadata()}),
        throwsFormatException,
      );
    });

    test('rejects a non-object message entry', () {
      expect(
        () => GenerateRequest.fromJson(parseable(body(messages: ['hi']))),
        throwsFormatException,
      );
    });

    test('rejects a last message that is not from the user', () {
      expect(
        () => GenerateRequest.fromJson(
          parseable(
            body(
              messages: [
                {'role': 'assistant', 'content': 'a'},
              ],
            ),
          ),
        ),
        throwsFormatException,
      );
    });

    group('metadata', () {
      test('reports no surface when the renderer shows none', () {
        final request = GenerateRequest.fromJson(parseable(body()));

        expect(request.surfaceIds, isEmpty);
      });

      test('reports the surfaces whose data model the renderer sends', () {
        final request = GenerateRequest.fromJson(
          parseable(
            body(metadata: rendererMetadata(surfaces: ['dashboard', 'other'])),
          ),
        );

        expect(request.surfaceIds, {'dashboard', 'other'});
      });

      test('is required', () {
        expect(
          () => GenerateRequest.fromJson({
            'messages': [
              {'role': 'user', 'content': 'hi'},
            ],
          }),
          throwsFormatException,
        );
      });

      test('must be an object', () {
        expect(
          () => GenerateRequest.fromJson(parseable(body(metadata: 'x'))),
          throwsFormatException,
        );
      });

      test('must carry the renderer capabilities', () {
        expect(
          () => GenerateRequest.fromJson(parseable(body(metadata: {}))),
          throwsFormatException,
        );
      });

      test('rejects capabilities that name no supported version', () {
        expect(
          () => GenerateRequest.fromJson(
            parseable(
              body(
                metadata: {
                  'a2uiRendererCapabilities': {
                    'v99': {
                      'supportedCatalogIds': ['x'],
                    },
                  },
                },
              ),
            ),
          ),
          throwsFormatException,
        );
      });

      test('must list the home catalog for A2UI 1.0', () {
        final other = A2uiRendererCapabilities.forCatalogIds([
          'somebody/else',
        ], version: A2uiProtocolVersion.v1_0).toJson();

        expect(
          () => GenerateRequest.fromJson(
            parseable(body(metadata: {'a2uiRendererCapabilities': other})),
          ),
          throwsA(
            isA<FormatException>().having(
              (e) => e.message,
              'message',
              contains('must list the catalog'),
            ),
          ),
        );
      });

      test('must be an object when it has a data model', () {
        final metadata = rendererMetadata()
          ..['a2uiRendererDataModel'] = {'surfaces': 'nope'};

        expect(
          () => GenerateRequest.fromJson(parseable(body(metadata: metadata))),
          throwsFormatException,
        );
      });
    });
  });
}

class _Default {
  const _Default();
}
