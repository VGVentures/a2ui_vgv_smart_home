import 'package:flutter/material.dart';
import 'package:home_catalog/home_catalog.dart';
import 'package:home_frontend/src/a2ui/a2ui.dart';
import 'package:home_frontend/src/catalog/widget_builders.dart';
import 'package:json_schema_builder/json_schema_builder.dart';

/// A `Text` for tests only. The home catalog has no plain text or button, as
/// the Figma component catalog has none, but the agent tests need a surface
/// with a label to press.
class TestTextDefinition extends GenUiComponent {
  const TestTextDefinition();

  @override
  String get name => 'Text';

  @override
  Schema get schema => CatalogSchemas.component(
    name,
    properties: {'text': CatalogSchemas.dynamicString()},
    required: ['text'],
  );
}

/// A `Button` for tests only: a child and the action it raises.
class TestButtonDefinition extends GenUiComponent {
  const TestButtonDefinition();

  @override
  String get name => 'Button';

  @override
  Schema get schema => CatalogSchemas.component(
    name,
    properties: {
      'child': Schema.fromMap({r'$ref': r'common_types.json#/$defs/Child'}),
      'action': Schema.fromMap({r'$ref': r'common_types.json#/$defs/Action'}),
    },
    required: ['child', 'action'],
  );
}

/// The home catalog with the test-only `Text` and `Button` added.
final GenUiComponentCatalog testCatalog = GenUiComponentCatalog(
  id: homeCatalog.id,
  protocolVersion: A2uiProtocolVersion.v1_0,
  components: [
    ...homeCatalog.components.values,
    const TestTextDefinition(),
    const TestButtonDefinition(),
  ],
);

/// The builders of [widgetBuilders] and simple ones for the test-only
/// components.
final Map<String, ComponentWidgetBuilder> testWidgetBuilders = {
  ...widgetBuilders,
  'Text': (context, node, props, buildChild) =>
      Text(props.string('text') ?? ''),
  'Button': (context, node, props, buildChild) {
    final child = props.child('child');
    return TextButton(
      onPressed: props.action('action'),
      child: child == null ? const SizedBox.shrink() : buildChild(child),
    );
  },
};
