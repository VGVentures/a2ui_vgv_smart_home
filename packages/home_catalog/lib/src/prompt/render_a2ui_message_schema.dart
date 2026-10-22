import 'dart:convert';

import 'package:a2ui_core/a2ui_core.dart';
import 'package:home_catalog/src/components/card_fit.dart';
import 'package:home_catalog/src/components/gen_ui_component.dart';
import 'package:home_catalog/src/protocol.dart';

/// Renders the full A2UI message JSON Schema for [catalog] as an indented
/// JSON string suitable for inclusion in an LLM system prompt.
///
/// The schema is a `oneOf` over the four A2UI message types
/// (`createSurface`, `updateComponents`, `updateDataModel`, `deleteSurface`).
/// Catalog-derived bits are wired in dynamically:
///
/// - `createSurface.catalogId` carries a `"const"` constraint of
///   `catalog.id`, so the LLM can only emit a `createSurface` that targets
///   this exact catalog.
/// - `updateComponents.components.items.oneOf` is built from the catalog
///   entries. Each entry's schema is augmented with a `component` discriminator
///   enum (mirroring `package:genui`'s `CatalogItem.dataSchema`) so the LLM
///   emits the correct type tag.
///
/// If a component's schema already declares a `component` property, this
/// function throws to surface the bug at server bootstrap instead of silently
/// shipping a contradictory schema.
///
/// With [compact] the JSON has no indentation or spaces: the same schema in a
/// third of the characters, which is what a model reads best at this size.
///
/// The output is deterministic for a given catalog (component order, JSON
/// indentation) so it can be golden-tested and reasoned about diff-wise.
String renderA2uiMessageSchema(
  Catalog<GenUiComponent> catalog, {
  bool compact = false,
}) {
  final componentSchemas = catalog.components.values
      .map(_augmentedComponentSchema)
      .toList(growable: false);

  final schema = <String, Object?>{
    'title': 'A2UI Message Schema',
    'description':
        'Describes a JSON payload for an A2UI (Agent to UI) message, '
        'which is used to dynamically construct and update user interfaces.',
    'oneOf': <Map<String, Object?>>[
      _createSurfaceBranch(catalog.id),
      _updateComponentsBranch(componentSchemas),
      _updateDataModelBranch,
      _deleteSurfaceBranch,
    ],
  };

  return compact
      ? jsonEncode(schema)
      : const JsonEncoder.withIndent('  ').convert(schema);
}

Map<String, Object?> _augmentedComponentSchema(GenUiComponent component) {
  final raw = Map<String, Object?>.from(component.schema.value);
  final properties = Map<String, Object?>.from(
    (raw['properties'] as Map?)?.cast<String, Object?>() ?? const {},
  );
  if (properties.containsKey('component')) {
    throw StateError(
      'Component "${component.name}" declares a "component" property in its '
      'schema. That key is reserved as the A2UI discriminator and is added '
      'by renderA2uiMessageSchema. Remove it from the schema.',
    );
  }
  final required = List<Object?>.from(
    (raw['required'] as List?)?.cast<Object?>() ?? const [],
  );

  properties['component'] = <String, Object?>{
    'type': 'string',
    'enum': <String>[component.name],
  };
  // Every component can sit in a `Row`, where its `weight` is the columns it
  // spans. The layout prompt says so, but a model follows the schema it is
  // given first, so the property is written into it.
  properties.putIfAbsent('weight', () => _weight);

  return <String, Object?>{
    ...raw,
    'properties': properties,
    'required': <Object?>['component', ...required],
  };
}

const Map<String, Object?> _weight = {
  'type': 'integer',
  'minimum': 1,
  'maximum': gridColumns,
  'description':
      'The columns this component spans in its Row, out of $gridColumns. Set '
      'it on every card in a Row and on every Column beside a full height '
      'card.',
};

const _createSurfaceDescription =
    'Signals the client to create a new surface and begin rendering it. '
    'When this message is sent, the client will expect '
    "'updateComponents' and/or 'updateDataModel' messages for the same "
    'surfaceId that define the component tree.';

const _updateComponentsDescription =
    'Updates a surface with a new set of components. This message can be '
    'sent multiple times to update the component tree of an existing '
    'surface. One of the components in one of the components lists MUST '
    "have an 'id' of 'root' to serve as the root of the component tree. "
    'The createSurface message MUST have been previously sent with the '
    "'catalogId' that is in this message.";

const _updateDataModelDescription =
    'Updates the data model for an existing surface. This message can be '
    'sent multiple times to update the data model. The createSurface '
    "message MUST have been previously sent with the 'catalogId' that is "
    'in this message.';

const _deleteSurfaceDescription =
    "Signals the client to delete the surface identified by 'surfaceId'. "
    'The createSurface message MUST have been previously sent with the '
    "'catalogId' that is in this message.";

const _updateDataModelValueDescription =
    'The new value to write to the data model. If null/omitted, the key is '
    'removed.';

Map<String, Object?> _createSurfaceBranch(String catalogId) => {
  'type': 'object',
  'properties': {
    'version': {'type': 'string', 'const': a2uiVersion},
    'createSurface': {
      'type': 'object',
      'description': _createSurfaceDescription,
      'properties': {
        'surfaceId': {
          'type': 'string',
          'description': 'The unique ID for the surface.',
        },
        'catalogId': {
          'type': 'string',
          'const': catalogId,
          'description': 'The URI of the component catalog.',
        },
        'theme': {
          'type': 'object',
          'description': 'Theme parameters for the surface.',
          'additionalProperties': true,
        },
        'sendDataModel': {
          'type': 'boolean',
          'description':
              'Whether to send the data model to every client request.',
        },
      },
      'required': ['surfaceId', 'catalogId'],
    },
  },
  'required': ['version', 'createSurface'],
  'additionalProperties': false,
};

Map<String, Object?> _updateComponentsBranch(
  List<Map<String, Object?>> componentSchemas,
) => {
  'type': 'object',
  'properties': {
    'version': {'type': 'string', 'const': a2uiVersion},
    'updateComponents': {
      'type': 'object',
      'description': _updateComponentsDescription,
      'properties': {
        'surfaceId': {
          'type': 'string',
          'description': 'The unique identifier for the UI surface.',
        },
        'components': {
          'type': 'array',
          'description': 'A flat list of component definitions.',
          'items': {
            'description':
                'Must match one of the component definitions in the catalog.',
            'oneOf': componentSchemas,
          },
          'minItems': 1,
        },
      },
      'required': ['surfaceId', 'components'],
    },
  },
  'required': ['version', 'updateComponents'],
  'additionalProperties': false,
};

const Map<String, Object?> _updateDataModelBranch = {
  'type': 'object',
  'properties': {
    'version': {'type': 'string', 'const': a2uiVersion},
    'updateDataModel': {
      'type': 'object',
      'description': _updateDataModelDescription,
      'properties': {
        'surfaceId': {'type': 'string'},
        'path': {'type': 'string', 'default': '/'},
        'value': {'description': _updateDataModelValueDescription},
      },
      'required': ['surfaceId'],
    },
  },
  'required': ['version', 'updateDataModel'],
  'additionalProperties': false,
};

const Map<String, Object?> _deleteSurfaceBranch = {
  'type': 'object',
  'properties': {
    'version': {'type': 'string', 'const': a2uiVersion},
    'deleteSurface': {
      'type': 'object',
      'description': _deleteSurfaceDescription,
      'properties': {
        'surfaceId': {'type': 'string'},
      },
      'required': ['surfaceId'],
    },
  },
  'required': ['version', 'deleteSurface'],
  'additionalProperties': false,
};

/// Renders the A2UI message schema in the form the system prompt uses: compact
/// JSON, only the `createSurface` and `updateComponents` messages the prompt
/// teaches, and without the schema's description texts.
///
/// The prose prompts say when to use each component, so the descriptions only
/// repeated it. Measured against the full compact schema, a lean prompt a
/// third shorter answered as well, so the model sees the same structure with
/// less to read.
String renderLeanA2uiMessageSchema(Catalog<GenUiComponent> catalog) {
  final schema =
      jsonDecode(renderA2uiMessageSchema(catalog, compact: true))
          as Map<String, Object?>;
  final messages = (schema['oneOf']! as List).cast<Map<String, Object?>>();
  return jsonEncode(
    _withoutDescriptions({
      ...schema,
      'oneOf': [
        for (final message in messages)
          if (_isTaughtMessage(message)) message,
      ],
    }),
  );
}

bool _isTaughtMessage(Map<String, Object?> message) {
  final properties = message['properties']! as Map<String, Object?>;
  return properties.containsKey('createSurface') ||
      properties.containsKey('updateComponents');
}

// Drops description texts only: a property that is itself called
// `description` is a map and stays.
Object? _withoutDescriptions(Object? node) => switch (node) {
  final Map<String, Object?> map => {
    for (final entry in map.entries)
      if (!(entry.key == 'description' && entry.value is String))
        entry.key: _withoutDescriptions(entry.value),
  },
  final List<Object?> list => list.map(_withoutDescriptions).toList(),
  _ => node,
};
