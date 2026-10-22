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
class GenerateRequest {
  /// {@macro generate_request}
  ///
  /// Creates a [GenerateRequest] from the parsed [messages].
  const GenerateRequest({required this.messages});

  /// {@macro generate_request}
  ///
  /// Parses a [GenerateRequest] from a `{messages}` JSON map.
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
    return GenerateRequest(messages: List.unmodifiable(messages));
  }

  /// The full message list for this request. Last entry is the user prompt
  /// for the current turn, earlier entries are prior conversation history.
  final List<GenerateMessage> messages;

  /// The user message that triggers this generation (the last entry).
  String get prompt => messages.last.content;

  /// Prior conversation turns, oldest first.
  Iterable<GenerateMessage> get history => messages.take(messages.length - 1);
}
