import 'dart:convert';

import 'package:home_backend/validation/llm_response_validator.dart';
import 'package:home_catalog/home_catalog.dart';

/// {@template a2ui_envelope_validator}
/// Validates that the LLM response carries at least one well-formed A2UI
/// message envelope.
/// {@endtemplate}
///
/// An A2UI message is a fenced ```json block whose decoded object holds exactly
/// one supported message key — `createSurface` or `updateComponents` — with a
/// `version` of at least [_minVersionLabel] and the top-level fields that
/// message type needs. A `createSurface` must also target this catalog.
///
/// This checks the envelope only. It does not validate component internals:
/// those are the client renderer's job, and Issue #71 keeps broader A2UI
/// conformance out of scope. A response fails when it has no A2UI message at
/// all, or when a block that looks like one is malformed: unparseable JSON,
/// more than one message per block, a bad `version`, a missing required field,
/// or a `createSurface` pointing at the wrong catalog. Failing triggers the
/// pipeline's retry.
///
/// This matters most for tool calling: after a native tool call the model tends
/// to summarize the result in prose instead of emitting A2UI. Failing here
/// makes it reissue the answer as A2UI.
class A2uiEnvelopeValidator implements LlmResponseValidator {
  /// {@macro a2ui_envelope_validator}
  ///
  /// Creates an [A2uiEnvelopeValidator] that checks a `createSurface` message
  /// targets [catalog].
  A2uiEnvelopeValidator(GenUiComponentCatalog catalog)
    : _catalogId = catalog.id;

  final String _catalogId;

  // The prompt instructs the LLM to fence A2UI messages with ```json ... ```.
  static final _fenceRegExp = RegExp(r'```json\b(.*?)```', dotAll: true);

  // Minimum supported A2UI version. Responses may carry this or higher.
  static const _minMajor = 0;
  static const _minMinor = 9;
  static const _minVersionLabel = 'v$_minMajor.$_minMinor';

  // The supported message types and the fields each message body must carry.
  // Mirrors the required fields in the catalog's render_a2ui_message_schema,
  // limited to the messages this kit's prompt teaches. Per-type rules beyond
  // presence (catalogId match, components shape) are applied in
  // [_validateMessage].
  static const _requiredFields = <String, List<String>>{
    'createSurface': ['surfaceId', 'catalogId'],
    'updateComponents': ['surfaceId', 'components'],
  };

  static const _noMessageError =
      'Your response contained no A2UI message. Every response must include at '
      'least one fenced ```json block holding a single `createSurface` or '
      '`updateComponents` message. Present all information, including tool '
      'results, as A2UI components rather than plain text.';

  @override
  List<String>? validate(String response) {
    final errors = <String>[];
    var sawValidMessage = false;

    for (final match in _fenceRegExp.allMatches(response)) {
      final raw = match.group(1);
      if (raw == null) continue;

      final Object? decoded;
      try {
        decoded = jsonDecode(raw);
      } on FormatException {
        errors.add(
          'A ```json block is not valid JSON. Emit complete, parseable JSON '
          'for every A2UI message.',
        );
        continue;
      }

      // Anything that is not a JSON object carrying a message key is some other
      // JSON, not an A2UI envelope. Skip it, so the response falls back to
      // [_noMessageError] unless a real message appears elsewhere.
      if (decoded is! Map<String, Object?>) continue;
      final messageKeys = _requiredFields.keys
          .where(decoded.containsKey)
          .toList();
      if (messageKeys.isEmpty) continue;

      final blockErrors = _validateMessage(messageKeys, decoded);
      if (blockErrors.isEmpty) {
        sawValidMessage = true;
      } else {
        errors.addAll(blockErrors);
      }
    }

    if (errors.isNotEmpty) return errors;
    return sawValidMessage ? null : const [_noMessageError];
  }

  // Returns the reasons this block is a malformed message, or an empty list
  // when the envelope is well-formed.
  List<String> _validateMessage(
    List<String> messageKeys,
    Map<String, Object?> decoded,
  ) {
    if (messageKeys.length > 1) {
      final found = messageKeys.join(', ');
      final error =
          'A single ```json block must hold exactly one A2UI message, but this '
          'one has ${messageKeys.length}: $found. Put each message in its own '
          '```json block.';
      return [error];
    }

    final key = messageKeys.single;
    final errors = <String>[];

    final version = decoded['version'];
    if (version is! String || !_isVersionSupported(version)) {
      errors.add(
        'A2UI `$key` message must set `version` to `$_minVersionLabel` or '
        'higher.',
      );
    }

    final body = decoded[key];
    if (body is! Map<String, Object?>) {
      errors.add('A2UI `$key` message must be a JSON object.');
      return errors;
    }

    for (final field in _requiredFields[key]!) {
      if (!body.containsKey(field)) {
        errors.add('A2UI `$key` message is missing required field `$field`.');
      }
    }

    if (key == 'createSurface' && body['catalogId'] != _catalogId) {
      errors.add(
        'A2UI `createSurface` message must set `catalogId` to `$_catalogId`.',
      );
    }
    if (key == 'updateComponents' &&
        body.containsKey('components') &&
        body['components'] is! List) {
      errors.add(
        'A2UI `updateComponents` message needs `components` to be a JSON '
        'array.',
      );
    }
    return errors;
  }

  // Accepts [_minVersionLabel] or higher. Compares major then minor so a future
  // `v0.10` or `v1.0` still passes, where a plain string compare would reject
  // them.
  static bool _isVersionSupported(String version) {
    final match = RegExp(r'^v?(\d+)\.(\d+)').firstMatch(version);
    if (match == null) return false;
    final major = int.parse(match.group(1)!);
    final minor = int.parse(match.group(2)!);
    if (major != _minMajor) return major > _minMajor;
    return minor >= _minMinor;
  }
}
