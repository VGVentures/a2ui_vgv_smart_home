import 'package:home_catalog/src/components/a2ui_schemas.dart';
import 'package:home_catalog/src/components/card_fit.dart';
import 'package:home_catalog/src/components/catalog_schemas.dart';
import 'package:home_catalog/src/components/gen_ui_component.dart';
import 'package:json_schema_builder/json_schema_builder.dart';

/// {@template countdown_card_component_definition}
/// Catalog definition for the `CountdownCard` component.
///
/// One upcoming event with a big countdown the client computes and ticks.
/// {@endtemplate}
class CountdownCardComponentDefinition extends GenUiComponent {
  /// {@macro countdown_card_component_definition}
  const CountdownCardComponentDefinition();

  @override
  CardFit get fit => const CardFit(
    best: GridCell(5, 1),
    also: [GridCell(4, 1)],
  );

  @override
  String get name => 'CountdownCard';

  @override
  Schema get schema => S.object(
    description:
        'A single upcoming calendar event with a big countdown, e.g. '
        '"Guests in 2h 30m". Use it when one event dominates the next few '
        'hours. Send only startsAt; the client computes and ticks the '
        'countdown. When the event moves, re-send it with the new startsAt.',
    properties: {
      'startsAt': A2uiSchemas.stringReference(
        description:
            'When the event starts, ISO 8601 with offset, e.g. '
            '"2026-10-02T19:00:00-07:00". May be data-bound.',
      ),
      'tag': S.combined(
        description:
            'Chip above the countdown, e.g. {"label":"Dinner party · 6 '
            'guests","icon":"restaurant","kind":"info"}. May be data-bound.',
        oneOf: [
          CatalogSchemas.statusTag(),
          A2uiSchemas.dataBindingSchema(description: 'A path to a tag.'),
        ],
      ),
      'eyebrow': S.string(
        description: 'Line above the countdown, "Guests in".',
      ),
      'subtitle': A2uiSchemas.stringReference(
        description:
            'Footer, e.g. "Dinner at 7:00 PM · Dining Room". May be '
            'data-bound.',
      ),
      'tone': CatalogSchemas.tone(
        description: 'Card color. Defaults to lighting.',
      ),
    },
    required: ['startsAt'],
  );
}
