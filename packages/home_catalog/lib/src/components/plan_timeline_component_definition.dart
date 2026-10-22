import 'package:home_catalog/src/components/a2ui_schemas.dart';
import 'package:home_catalog/src/components/card_fit.dart';
import 'package:home_catalog/src/components/catalog_schemas.dart';
import 'package:home_catalog/src/components/gen_ui_component.dart';
import 'package:json_schema_builder/json_schema_builder.dart';

/// {@template plan_timeline_component_definition}
/// Catalog definition for the `PlanTimeline` component.
///
/// An ordered list of events for the day that the agent can shift live.
/// {@endtemplate}
class PlanTimelineComponentDefinition extends GenUiComponent {
  /// {@macro plan_timeline_component_definition}
  const PlanTimelineComponentDefinition();

  @override
  CardFit get fit => const CardFit(
    best: GridCell(4, 2),
    also: [GridCell(4, 1), GridCell(5, 1)],
    note:
        '`density: detailed` takes the full height cell; `density: compact` '
        'takes a half tall one.',
  );

  @override
  String get name => 'PlanTimeline';

  @override
  Schema get schema => S.object(
    description:
        'The ordered plan for the evening, for example a dinner plan. Use it '
        'when the user has more than one dated thing today or the plan just '
        'changed; for a single event use CountdownCard. Entries that moved '
        'carry previousTime. It fills the width it is given, so when placing '
        'it inside a Row, give it a weight.',
    properties: {
      'title': S.string(
        description: 'Heading, e.g. "Tonight\'s plan". Literal.',
      ),
      'subtitle': S.string(
        description: 'Date line such as "Friday, Oct 2". Detailed only.',
      ),
      'density': S.string(
        description:
            'detailed (default): icon bubbles, up to 4 rows, 2 grid rows tall. '
            'compact: times only, up to 3 rows. Literal.',
        enumValues: ['detailed', 'compact'],
      ),
      'tag': S.combined(
        description:
            'Says the plan changed, e.g. {"label":"Updated","kind":"updated"}.'
            ' May be data-bound.',
        oneOf: [
          CatalogSchemas.statusTag(),
          A2uiSchemas.dataBindingSchema(description: 'A path to a tag.'),
        ],
      ),
      'entries': S.combined(
        description:
            'The events in time order, 1 to 5. May be data-bound to a list.',
        oneOf: [
          S.list(
            minItems: 1,
            maxItems: 5,
            items: S.object(
              properties: {
                'time': S.string(description: 'Display time, "6:00 PM".'),
                'title': S.string(description: 'What happens.'),
                'detail': S.string(description: 'Optional second line.'),
                'icon': CatalogSchemas.icon(
                  description: 'Detailed only; tints the bubble.',
                ),
                'previousTime': S.string(
                  description: 'The time before the change, e.g. "6:00".',
                ),
                'changedBy': S.string(
                  description: 'Who moved it, e.g. "Ana".',
                ),
                'status': S.string(
                  description:
                      'unchanged shows "Unchanged", for a second person.',
                  enumValues: ['unchanged', 'moved', 'new'],
                ),
              },
              required: ['time', 'title'],
            ),
          ),
          A2uiSchemas.dataBindingSchema(description: 'A path to the entries.'),
        ],
      ),
    },
    required: ['entries'],
  );
}
