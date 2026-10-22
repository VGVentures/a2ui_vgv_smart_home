import 'dart:convert';

import 'package:home_backend/validation/llm_response_validator.dart';
import 'package:home_catalog/home_catalog.dart';

/// {@template catalog_component_validator}
/// Validates that every component referenced inside an `updateComponents`
/// block in the LLM response exists in the catalog.
/// {@endtemplate}
///
/// Only inspects the documented A2UI shape from the system prompt:
/// fenced ```json blocks containing an `updateComponents` object whose
/// `components` array holds entries with a `component` string field. Other
/// JSON shapes and malformed blocks are ignored on purpose. Issue #71 limits
/// this validator to catalog-membership; JSON validity and broader A2UI
/// conformance are out of scope.
class CatalogComponentValidator implements LlmResponseValidator {
  /// {@macro catalog_component_validator}
  ///
  /// Creates a [CatalogComponentValidator] that compares component names
  /// against [catalog].
  CatalogComponentValidator(GenUiComponentCatalog catalog)
    : _catalogId = catalog.id,
      _knownNames = catalog.components.keys.toSet();

  final String _catalogId;
  final Set<String> _knownNames;

  // The prompt instructs the LLM to fence A2UI messages with ```json ... ```.
  static final _fenceRegExp = RegExp(r'```json\b(.*?)```', dotAll: true);

  @override
  List<String>? validate(String response) {
    final unknownNames = <String>{};
    for (final match in _fenceRegExp.allMatches(response)) {
      final raw = match.group(1);
      if (raw == null) continue;
      final dynamic decoded;
      try {
        decoded = jsonDecode(raw);
      } on FormatException {
        continue;
      }
      _collectUnknownNames(decoded, unknownNames);
    }
    if (unknownNames.isEmpty) return null;
    return [
      for (final name in unknownNames)
        'Component `$name` is not in the catalog with ID `$_catalogId`.',
    ];
  }

  void _collectUnknownNames(Object? decoded, Set<String> unknownNames) {
    if (decoded is! Map<String, Object?>) return;
    final update = decoded['updateComponents'];
    if (update is! Map<String, Object?>) return;
    final components = update['components'];
    if (components is! List) return;
    for (final entry in components) {
      if (entry is! Map<String, Object?>) continue;
      final name = entry['component'];
      if (name is! String) continue;
      if (!_knownNames.contains(name)) unknownNames.add(name);
    }
  }
}
