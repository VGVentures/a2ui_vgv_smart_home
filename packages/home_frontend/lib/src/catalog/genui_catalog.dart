import 'package:home_catalog/home_catalog.dart';
import 'package:home_frontend/src/a2ui/a2ui.dart';

/// Builds the renderer catalog used by the kit's GenUI zone.
///
/// Components and their schemas come from [catalog]; the matching Flutter
/// builders come from [widgetBuilders], keyed by component name. The pair is
/// zipped into the [CatalogImplementation] the A2UI 1.0 renderer expects.
///
/// Throws a [StateError] naming every component that has no builder, so a
/// mismatch is a launch-time crash and not a blank at render time.
CatalogImplementation buildCatalog({
  required GenUiComponentCatalog catalog,
  required Map<String, ComponentWidgetBuilder> widgetBuilders,
}) {
  // Validate all builders up front so a missing one surfaces with a useful
  // call site instead of mid-iteration during the final list build.
  final missing = catalog.components.keys
      .where((name) => !widgetBuilders.containsKey(name))
      .toList();
  if (missing.isNotEmpty) {
    throw StateError(
      'No widget builder registered for component(s) '
      '${missing.map((n) => '"$n"').join(', ')}. '
      'Add one to widget_builders.dart.',
    );
  }

  return CatalogImplementation(
    id: catalog.id,
    protocolVersion: A2uiProtocolVersion.v1_0,
    components: [
      for (final component in catalog.components.values)
        ComponentImplementation(
          name: component.name,
          schema: component.schema,
          builder: widgetBuilders[component.name]!,
        ),
    ],
  );
}
