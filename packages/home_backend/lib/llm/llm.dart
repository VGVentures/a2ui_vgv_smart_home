import 'package:genkit/genkit.dart';
import 'package:genkit_google_genai/genkit_google_genai.dart';

/// Runs the model over [messages] (system prompt, history and the new user
/// message) with the caller's [apiKey] and returns the reply text. Tool calls
/// run inside it.
typedef Generate =
    Future<String> Function(String apiKey, List<Message> messages);

/// The Gemini model used when `HOME_LLM_MODEL` is not set.
const defaultModel = 'gemini-3.1-flash-lite';

/// Builds the process-wide Genkit runtime.
///
/// The Google plugin is registered with no key on purpose: the server holds
/// none, and every call brings the caller's own through [genkitGenerate].
Genkit buildGenkitRuntime() {
  // `promptDir: null` disables Genkit's `.prompt` auto-loading; the server
  // renders its own prompts through the `dotprompt` package.
  return Genkit(plugins: [googleAI()], promptDir: null);
}

/// A [Generate] backed by Genkit: [model] with the registered [tools].
///
/// The key goes in the options of each call, so it is not kept by the runtime.
Generate genkitGenerate({
  required Genkit ai,
  required ModelRef<dynamic> model,
  required List<Tool<dynamic, dynamic>> tools,
}) {
  return (apiKey, messages) async {
    final conversation = [...messages];
    for (var attempt = 0; ; attempt++) {
      try {
        final response = await ai.generate<dynamic, dynamic>(
          model: model,
          messages: conversation,
          tools: tools,
          config: GeminiOptions(apiKey: apiKey),
        );
        return response.text;
      } on GenkitException catch (error) {
        final name = _missingTool(error);
        if (name == null || attempt >= _toolRetries) rethrow;
        // The model asked to call something that is not a tool: the A2UI
        // messages it writes in its reply. Say so and let it answer again,
        // instead of failing the request over a slip it can correct.
        conversation.add(
          Message(
            role: Role.user,
            content: [
              TextPart(
                text:
                    'There is no tool called "$name". The A2UI messages are '
                    'not tools: write them as fenced JSON in your reply, '
                    'after reading the data with the tools you were given.',
              ),
            ],
          ),
        );
      }
    }
  };
}

/// How many times a call that named a tool that does not exist is asked again.
const _toolRetries = 2;

/// The tool a [GenkitException] says does not exist, or null for any other.
String? _missingTool(GenkitException error) {
  if (error.status != StatusCodes.NOT_FOUND) return null;
  return RegExp(r'^Tool (\S+) not found').firstMatch(error.message)?.group(1);
}
