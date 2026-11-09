import 'dart:convert';

import 'package:flutter/foundation.dart';

/// {@template generate_response}
/// The successful `POST /generate` and `POST /action` response: the A2UI
/// [messages] to apply and the model's [reply].
///
/// The server returns a buffered JSON object `{"messages": [...], "reply":
/// "..."}` on a `2xx`. [messages] are validated A2UI 1.0 messages for the
/// dashboard surface, to apply in one step. [reply] is the model's own text,
/// which is what the history keeps as the assistant turn, since the backend
/// holds none. The factories decode and type-check that payload, throwing a
/// [FormatException] for anything that does not match the contract (a non-JSON
/// body, a non-object, a `messages` that is not a list of objects or a
/// non-string `reply`), so the caller can surface one well-defined error
/// instead of a raw `FormatException`/`TypeError`.
/// {@endtemplate}
@immutable
class GenerateResponse {
  /// {@macro generate_response}
  const GenerateResponse({required this.messages, required this.reply});

  /// {@macro generate_response}
  ///
  /// Decodes and validates a buffered success [body].
  ///
  /// Throws a [FormatException] when [body] is not valid JSON, is not a JSON
  /// object, or fails the field checks in [GenerateResponse.fromJson].
  factory GenerateResponse.fromBody(String body) {
    // jsonDecode throws a FormatException when the body is not valid JSON.
    final decoded = jsonDecode(body);
    if (decoded is! Map<String, dynamic>) {
      throw const FormatException('response body was not a JSON object');
    }
    return GenerateResponse.fromJson(decoded);
  }

  /// {@macro generate_response}
  ///
  /// Reads a [GenerateResponse] from an already-decoded [json] map.
  ///
  /// A missing or null `messages` becomes an empty list and a missing or null
  /// `reply` the empty string. Throws a [FormatException] when `messages` is
  /// not a list of objects or `reply` is present but not a string.
  factory GenerateResponse.fromJson(Map<String, dynamic> json) {
    final rawMessages = json['messages'];
    if (rawMessages != null &&
        (rawMessages is! List ||
            rawMessages.any((m) => m is! Map<String, dynamic>))) {
      throw const FormatException('"messages" field was not a list of objects');
    }
    final rawReply = json['reply'];
    if (rawReply != null && rawReply is! String) {
      throw const FormatException('"reply" field was not a string');
    }
    return GenerateResponse(
      messages: [
        for (final message in (rawMessages as List?) ?? const [])
          message as Map<String, Object?>,
      ],
      reply: (rawReply as String?) ?? '',
    );
  }

  /// The A2UI messages to apply, in order. Empty when the server sent none.
  final List<Map<String, Object?>> messages;

  /// The model's reply text. Empty when the server returned no text.
  final String reply;
}
