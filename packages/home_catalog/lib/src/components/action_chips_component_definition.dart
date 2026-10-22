import 'package:home_catalog/src/components/catalog_schemas.dart';
import 'package:home_catalog/src/components/gen_ui_component.dart';
import 'package:home_catalog/src/components/home_actions.dart';
import 'package:json_schema_builder/json_schema_builder.dart';

/// {@template action_chips_component_definition}
/// Catalog definition for the `ActionChips` component.
///
/// The bottom "Suggested" row: one to three next steps, each carrying a
/// typed spec of what the press does (see `HomeActions.spec`).
/// {@endtemplate}
class ActionChipsComponentDefinition extends GenUiComponent {
  /// {@macro action_chips_component_definition}
  const ActionChipsComponentDefinition();

  @override
  String get name => 'ActionChips';

  @override
  Schema get schema => S.object(
    description:
        'The bottom "Suggested" row: one to three next steps for the '
        'persona, tied to the current plan and device state. One per screen. '
        'The first chip is the recommended one.',
    properties: {
      'label': S.string(
        description: 'The text next to the sparkle. Defaults to "Suggested".',
      ),
      'chips': S.list(
        description: 'The suggested actions, verb first.',
        minItems: 1,
        maxItems: 3,
        items: S.object(
          properties: {
            'label': S.string(
              description: 'At most 22 characters, e.g. "Preheat now".',
              maxLength: 22,
            ),
            'icon': CatalogSchemas.icon(description: 'Optional icon.'),
            'isPrimary': S.boolean(
              description: 'The recommended chip. Exactly one, the first.',
            ),
            'action': HomeActions.spec(
              description:
                  'Choose what pressing the chip does: a device command, a '
                  'scene, undo, or a request for the assistant. Never write '
                  'an event name or a label; the chip label is shown while '
                  'it runs.',
            ),
          },
          required: ['label', 'action'],
        ),
      ),
    },
    required: ['chips'],
  );
}
