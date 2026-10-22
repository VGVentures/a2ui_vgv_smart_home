import 'package:home_catalog/src/components/a2ui_schemas.dart';
import 'package:home_catalog/src/components/card_fit.dart';
import 'package:home_catalog/src/components/catalog_schemas.dart';
import 'package:home_catalog/src/components/gen_ui_component.dart';
import 'package:json_schema_builder/json_schema_builder.dart';

/// {@template scene_card_component_definition}
/// Catalog definition for the `SceneCard` component.
///
/// A group of device settings that run with one tap.
/// {@endtemplate}
class SceneCardComponentDefinition extends GenUiComponent {
  /// {@macro scene_card_component_definition}
  const SceneCardComponentDefinition();

  @override
  CardFit get fit => const CardFit(
    best: GridCell(5, 1),
    also: [GridCell(4, 1)],
    note: 'Ready (with its Start button) is drawn 5 columns wide, running 4.',
  );

  @override
  String get name => 'SceneCard';

  @override
  Schema get schema => S.object(
    description:
        'A named scene that sets several devices at once, for example a '
        'dinner party scene. Ready shows a Start button; running shows an '
        'On tag and no button.',
    properties: {
      'sceneId': S.string(
        description: 'The id of the scene, from the scene data.',
      ),
      'name': S.string(description: 'e.g. "Dinner party scene".'),
      'description': S.string(
        description: 'The line under the name, e.g. "Dining Room · 4 devices".',
      ),
      'icon': CatalogSchemas.icon(description: 'Defaults to scene.'),
      'tone': CatalogSchemas.tone(
        description: 'The card color. Defaults to lighting.',
      ),
      'state': A2uiSchemas.stringReference(
        description: 'ready (default) or running. Bindable.',
        enumValues: ['ready', 'running'],
      ),
      'settings': S.list(
        description: 'What the scene sets, up to four, e.g. "Pendants 40 %".',
        items: S.string(),
      ),
      'actionLabel': S.string(
        description: 'The button text, imperative. Defaults to "Start".',
      ),
    },
    required: ['sceneId', 'name'],
  );
}
