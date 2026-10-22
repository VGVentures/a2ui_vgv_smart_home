import 'package:genui/genui.dart' show BasicCatalogItems, CatalogWidgetBuilder;
import 'package:home_catalog/home_catalog.dart';
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
  Schema get schema => S.object(
    properties: {'text': A2uiSchemas.stringReference()},
    required: ['text'],
  );
}

/// A `Button` for tests only: a child and the action it raises.
class TestButtonDefinition extends GenUiComponent {
  const TestButtonDefinition();

  @override
  String get name => 'Button';

  @override
  Schema get schema => S.object(
    properties: {
      'child': A2uiSchemas.componentReference(),
      'action': A2uiSchemas.action(),
    },
    required: ['child', 'action'],
  );
}

/// The home catalog with the test-only `Text` and `Button` added.
final GenUiComponentCatalog testCatalog = GenUiComponentCatalog(
  id: homeCatalog.id,
  components: [
    ...homeCatalog.components.values,
    const TestTextDefinition(),
    const TestButtonDefinition(),
  ],
);

/// The builders of [widgetBuilders] and the upstream ones for the test-only
/// components.
final Map<String, CatalogWidgetBuilder> testWidgetBuilders = {
  ...widgetBuilders,
  'Text': BasicCatalogItems.text.widgetBuilder,
  'Button': BasicCatalogItems.button.widgetBuilder,
};
