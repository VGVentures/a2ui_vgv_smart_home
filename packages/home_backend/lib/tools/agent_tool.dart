import 'dart:async';

/// {@template agent_tool}
/// A tool the model may call: a name, a description, the JSON Schema of its
/// arguments and the function that runs it.
/// {@endtemplate}
///
/// It is independent of Genkit so a tool's logic is testable without a Genkit
/// instance; `registerAgentTools` registers each one on the runtime.
///
/// Throw an `Exception` for an expected failure (nothing found, a rejected
/// command): Genkit hands its message back to the model and generation
/// continues. An `Error` is a bug and fails the request.
class AgentTool {
  /// {@macro agent_tool}
  ///
  /// Creates a tool. [inputSchema] is `null` for a tool without arguments.
  const AgentTool({
    required this.name,
    required this.description,
    required this.onCall,
    this.inputSchema,
  });

  /// The tool name the model calls.
  final String name;

  /// The description the model uses to decide when to call the tool.
  final String description;

  /// The JSON Schema of the tool's arguments, or `null` when it takes none.
  final Map<String, dynamic>? inputSchema;

  /// The tool's logic.
  final FutureOr<Object?> Function(Map<String, dynamic> args) onCall;

  /// Runs the tool with the model's `args`. Always asynchronous, so a failure
  /// surfaces as a failed future like Genkit sees it.
  Future<Object?> call(Map<String, dynamic> args) async => onCall(args);
}
