import 'package:a2ui_core/a2ui_core.dart';
import 'package:home_catalog/home_catalog.dart' show genUiCatalogId;

/// {@template generate_message_role}
/// Role of a message in the [GenerateRequest] message list.
/// {@endtemplate}
enum GenerateMessageRole {
  /// Message from the human user.
  user,

  /// Message from the model.
  assistant,
}

/// {@template generate_message}
/// A single message in the request message list.
/// {@endtemplate}
class GenerateMessage {
  /// {@macro generate_message}
  ///
  /// Creates a [GenerateMessage] with the given [role] and [content].
  const GenerateMessage({required this.role, required this.content});

  /// {@macro generate_message}
  ///
  /// Parses a [GenerateMessage] from a `{role, content}` JSON map.
  factory GenerateMessage.fromJson(Map<String, dynamic> json) {
    final rawRole = json['role'];
    if (rawRole is! String) {
      throw const FormatException('messages[].role must be a string');
    }
    final role = switch (rawRole) {
      'user' => GenerateMessageRole.user,
      'assistant' => GenerateMessageRole.assistant,
      _ => throw FormatException('Unknown message role: $rawRole'),
    };
    final content = json['content'];
    if (content is! String || content.isEmpty) {
      throw const FormatException(
        'messages[].content must be a non-empty string',
      );
    }
    return GenerateMessage(role: role, content: content);
  }

  /// The role of the message author.
  final GenerateMessageRole role;

  /// The text content of the message.
  final String content;
}

/// {@template generate_request}
/// Body of a `POST /generate` request.
/// {@endtemplate}
///
/// The wire format is a single `messages` list ordered from oldest to newest.
/// The last entry must be a user message and is treated as the prompt for the
/// current turn.
///
/// `metadata` is what an A2UI 1.0 renderer sends with each request:
/// `a2uiRendererCapabilities`, which must list the home catalog, and
/// `a2uiRendererDataModel`, whose surface ids tell this stateless backend which
/// surfaces the panel already shows.
class GenerateRequest {
  /// {@macro generate_request}
  ///
  /// Creates a [GenerateRequest] from the parsed [messages]. [surfaceIds] are
  /// the surfaces the panel already shows.
  const GenerateRequest({
    required this.messages,
    this.surfaceIds = const {},
  });

  /// {@macro generate_request}
  ///
  /// Parses a [GenerateRequest] from a `{messages, metadata}` JSON map.
  factory GenerateRequest.fromJson(Map<String, dynamic> json) {
    final rawMessages = json['messages'];
    if (rawMessages is! List || rawMessages.isEmpty) {
      throw const FormatException('messages must be a non-empty list');
    }
    final messages = <GenerateMessage>[];
    for (final entry in rawMessages) {
      if (entry is! Map<String, dynamic>) {
        throw const FormatException('messages[] entries must be objects');
      }
      messages.add(GenerateMessage.fromJson(entry));
    }
    if (messages.last.role != GenerateMessageRole.user) {
      throw const FormatException('The last message must be a user message');
    }
    return GenerateRequest(
      messages: List.unmodifiable(messages),
      surfaceIds: _surfaceIds(json['metadata']),
    );
  }

  /// Reads `metadata`, and returns the ids of the surfaces the panel reports.
  static Set<String> _surfaceIds(Object? metadata) {
    if (metadata is! Map<String, dynamic>) {
      throw const FormatException('metadata must be an object');
    }
    final capabilities = metadata['a2uiRendererCapabilities'];
    if (capabilities is! Map<String, dynamic>) {
      throw const FormatException(
        'metadata.a2uiRendererCapabilities must be an object',
      );
    }
    final A2uiRendererCapabilities parsed;
    try {
      parsed = A2uiRendererCapabilities.fromJson(capabilities);
    } on A2uiError catch (error) {
      throw FormatException(
        'metadata.a2uiRendererCapabilities is not valid: ${error.message}',
      );
    }
    final supported = parsed
        .forVersion(A2uiProtocolVersion.v1_0)
        ?.supportedCatalogIds;
    if (supported == null || !supported.contains(genUiCatalogId)) {
      throw const FormatException(
        'metadata.a2uiRendererCapabilities must list the catalog '
        '$genUiCatalogId for A2UI 1.0',
      );
    }
    final dataModel = metadata['a2uiRendererDataModel'];
    if (dataModel == null) return const {};
    final surfaces = dataModel is Map<String, dynamic>
        ? dataModel['surfaces']
        : null;
    if (surfaces is! Map<String, dynamic>) {
      throw const FormatException(
        'metadata.a2uiRendererDataModel.surfaces must be an object',
      );
    }
    return Set.unmodifiable(surfaces.keys);
  }

  /// The full message list for this request. Last entry is the user prompt
  /// for the current turn, earlier entries are prior conversation history.
  final List<GenerateMessage> messages;

  /// The ids of the surfaces the panel reports it already shows.
  final Set<String> surfaceIds;

  /// The user message that triggers this generation (the last entry).
  String get prompt => messages.last.content;

  /// Prior conversation turns, oldest first.
  Iterable<GenerateMessage> get history => messages.take(messages.length - 1);
}
