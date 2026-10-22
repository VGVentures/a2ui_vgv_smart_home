import 'package:genkit/genkit.dart';
import 'package:home_backend/llm/llm.dart';
import 'package:test/test.dart';

void main() {
  group('buildGenkitRuntime', () {
    test('builds with no API key, because the server holds none', () {
      expect(buildGenkitRuntime, returnsNormally);
    });
  });

  group('genkitGenerate', () {
    late Map<String, dynamic>? seenConfig;
    late Generate generate;

    setUp(() {
      seenConfig = null;
      final ai = Genkit()
        ..defineModel(
          name: 'echo',
          fn: (request, context) async {
            seenConfig = request.config;
            return ModelResponse(
              finishReason: FinishReason.stop,
              message: Message(
                role: Role.model,
                content: [
                  TextPart(
                    text: request.messages.map((m) => m.text).join(' | '),
                  ),
                ],
              ),
            );
          },
        );
      generate = genkitGenerate(
        ai: ai,
        model: modelRef('echo'),
        tools: const [],
      );
    });

    List<Message> conversation() => [
      Message(
        role: Role.system,
        content: [TextPart(text: 'system')],
      ),
      Message(
        role: Role.user,
        content: [TextPart(text: 'hello')],
      ),
    ];

    test('sends the messages to the model and returns its text', () async {
      expect(await generate('key', conversation()), 'system | hello');
    });

    test("sends the caller's key with the call", () async {
      await generate('callers-key', conversation());

      expect(seenConfig, containsPair('apiKey', 'callers-key'));
    });
  });

  group(
    'genkitGenerate when the model asks for a tool that does not exist',
    () {
      late int calls;
      late List<List<String>> seen;

      Genkit aiThatAsks({required int times}) {
        calls = 0;
        seen = [];
        return Genkit()..defineModel(
          name: 'slips',
          fn: (request, context) async {
            calls++;
            seen.add([for (final m in request.messages) m.text]);
            if (calls <= times) {
              return ModelResponse(
                finishReason: FinishReason.stop,
                message: Message(
                  role: Role.model,
                  content: [
                    ToolRequestPart(
                      toolRequest: ToolRequest(
                        name: 'createSurface',
                        input: const {},
                        ref: 'call-$calls',
                      ),
                    ),
                  ],
                ),
              );
            }
            return ModelResponse(
              finishReason: FinishReason.stop,
              message: Message(
                role: Role.model,
                content: [TextPart(text: 'the screen')],
              ),
            );
          },
        );
      }

      List<Message> conversation() => [
        Message(
          role: Role.user,
          content: [TextPart(text: 'hello')],
        ),
      ];

      test('says it is not a tool and asks again', () async {
        final generate = genkitGenerate(
          ai: aiThatAsks(times: 1),
          model: modelRef('slips'),
          tools: const [],
        );

        expect(await generate('key', conversation()), 'the screen');
        expect(calls, 2);
        expect(
          seen.last.last,
          allOf(
            contains('no tool called "createSurface"'),
            contains('fenced JSON in your reply'),
          ),
        );
      });

      test('gives up after asking twice', () async {
        final generate = genkitGenerate(
          ai: aiThatAsks(times: 5),
          model: modelRef('slips'),
          tools: const [],
        );

        await expectLater(
          generate('key', conversation()),
          throwsA(
            isA<GenkitException>().having(
              (e) => e.message,
              'message',
              contains('createSurface'),
            ),
          ),
        );
        expect(calls, 3);
      });

      test('does not hide any other failure', () async {
        final ai = Genkit()
          ..defineModel(
            name: 'broken',
            fn: (request, context) async => throw GenkitException(
              'quota',
              status: StatusCodes.RESOURCE_EXHAUSTED,
            ),
          );
        final generate = genkitGenerate(
          ai: ai,
          model: modelRef('broken'),
          tools: const [],
        );

        await expectLater(
          generate('key', conversation()),
          throwsA(isA<GenkitException>()),
        );
      });
    },
  );
}
