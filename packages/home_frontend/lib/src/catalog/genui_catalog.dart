import 'package:home_catalog/home_catalog.dart';
import 'package:home_frontend/src/a2ui/a2ui.dart';
import 'package:home_frontend/src/catalog/widget_builders.dart';

/// Builds the `package:genui` catalog used by the kit's GenUI zone.
///
/// Components and their schemas come from [catalog]; the matching Flutter
/// builders come from [widgetBuilders], keyed by component name. The pair
/// is zipped into the `package:genui` [Catalog] the runtime renderer
/// expects.
///
/// [implicitlyFlexibleComponents], also keyed by name, supplies
/// `isImplicitlyFlexible`.
///
/// When [systemPrompt] is non-empty it is appended as the last system prompt
/// fragment, after the basic catalog rules and the component restriction.
/// Implementations that ship the system prompt elsewhere (for example the
/// HTTP agent, where the backend owns it) can leave it empty.
Catalog buildCatalog({
  required GenUiComponentCatalog catalog,
  required Map<String, CatalogWidgetBuilder> widgetBuilders,
  String systemPrompt = '',
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

  final items = <CatalogItem>[
    for (final component in catalog.components.values)
      CatalogItem(
        name: component.name,
        dataSchema: component.schema,
        widgetBuilder: widgetBuilders[component.name]!,
        isImplicitlyFlexible: implicitlyFlexibleComponents.contains(
          component.name,
        ),
      ),
  ];

  final componentList = items.map((item) => '`${item.name}`').join(', ');
  final catalogRestriction =
      'The ONLY components available in this catalog are: $componentList. '
      'Do NOT reference any other component.';

  return Catalog(
    items,
    functions: BasicFunctions.all,
    catalogId: catalog.id,
    systemPromptFragments: [
      BasicCatalogItems.basicCatalogRules,
      catalogRestriction,
      if (systemPrompt.isNotEmpty) systemPrompt,
    ],
  );
}
