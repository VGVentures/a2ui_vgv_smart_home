import 'dart:convert';

import 'package:flutter/foundation.dart';

/// {@template generate_response}
/// The successful `POST /generate` response: the model's reply [text].
///
/// The server returns a buffered JSON object `{"text": ...}` on a `2xx`. The
/// factories decode and type-check that payload, throwing a [FormatException]
/// for anything that does not match the contract (a non-JSON body, a
/// non-object or a non-string `text`), so the caller can surface one
/// well-defined error instead of a raw `FormatException`/`TypeError`.
/// {@endtemplate}
@immutable
class GenerateResponse {
  /// {@macro generate_response}
  const GenerateResponse({required this.text});

  /// {@macro generate_response}
  ///
  /// Decodes and validates a buffered `/generate` success [body].
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
  /// A missing or null `text` becomes the empty string. Throws a
  /// [FormatException] when `text` is present but not a string.
  factory GenerateResponse.fromJson(Map<String, dynamic> json) {
    final rawText = json['text'];
    if (rawText != null && rawText is! String) {
      throw const FormatException('"text" field was not a string');
    }
    return GenerateResponse(text: (rawText as String?) ?? '');
  }

  /// The model's reply text. Empty when the server returned no text.
  final String text;
}
