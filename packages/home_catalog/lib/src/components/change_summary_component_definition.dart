import 'package:home_catalog/src/components/card_fit.dart';
import 'package:home_catalog/src/components/catalog_schemas.dart';
import 'package:home_catalog/src/components/gen_ui_component.dart';
import 'package:json_schema_builder/json_schema_builder.dart';

/// {@template change_summary_component_definition}
/// Catalog definition for the `ChangeSummary` component.
///
/// Confirms what the agent changed after a request, as a row of tiles. It has
/// no buttons and is replaced whole.
/// {@endtemplate}
class ChangeSummaryComponentDefinition extends GenUiComponent {
  /// {@macro change_summary_component_definition}
  const ChangeSummaryComponentDefinition();

  @override
  CardFit get fit => const CardFit(
    best: GridCell(8, 1),
    note: 'Always half tall. It shows 4 changes.',
  );

  @override
  String get name => 'ChangeSummary';

  @override
  Schema get schema => S.object(
    description:
        'Confirms what the agent changed right after a spoken or typed '
        'request, so the user sees the request turn into device actions. At '
        'most one, the highlight of the screen and its widest card.',
    properties: {
      'eyebrow': S.string(
        description: 'e.g. "Done · from your request at 5:40 PM".',
      ),
      'title': S.string(description: 'e.g. "Dinner moved to 8:00 PM".'),
      'changes': S.list(
        description: 'One tile per change.',
        minItems: 1,
        maxItems: 4,
        items: S.object(
          properties: {
            'icon': CatalogSchemas.icon(description: 'Optional icon.'),
            'label': S.string(description: 'e.g. "Oven preheat".'),
            'value': S.string(description: 'The new value, e.g. "7:00 PM".'),
            'previous': S.string(description: 'e.g. "was 6:00 PM".'),
            'note': S.string(
              description: 'Used when there is no previous, e.g. "Sent 5:41".',
            ),
          },
          required: ['label', 'value'],
        ),
      ),
    },
    required: ['title', 'changes'],
  );
}
