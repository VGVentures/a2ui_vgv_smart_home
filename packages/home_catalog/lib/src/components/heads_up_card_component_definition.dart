import 'package:home_catalog/src/components/a2ui_schemas.dart';
import 'package:home_catalog/src/components/card_fit.dart';
import 'package:home_catalog/src/components/catalog_schemas.dart';
import 'package:home_catalog/src/components/gen_ui_component.dart';
import 'package:home_catalog/src/components/home_actions.dart';
import 'package:json_schema_builder/json_schema_builder.dart';

/// {@template heads_up_card_component_definition}
/// Catalog definition for the `HeadsUpCard` component.
///
/// A timely item with a reason line and the one or two things the user can do
/// about it. It owns its action buttons. `timestamp` and `actions[].state` may
/// be data-bound.
/// {@endtemplate}
class HeadsUpCardComponentDefinition extends GenUiComponent {
  /// {@macro heads_up_card_component_definition}
  const HeadsUpCardComponentDefinition();

  @override
  CardFit get fit => const CardFit(
    best: GridCell(7, 1),
    also: [GridCell(5, 1), GridCell(8, 2)],
    note:
        '`variant: headsUp` takes 7 or 5 columns, half tall; two actions need '
        '7 columns, at 5 give it one. `variant: urgent` takes 8 columns and '
        'both rows, and the screen then has no ActionChips.',
  );

  @override
  String get name => 'HeadsUpCard';

  @override
  Schema get schema => S.object(
    description:
        'A timely item the agent surfaces unprompted (traffic, rain, a hot '
        'room), with a reason line and the things to do about it. At most '
        'one, in the top slot. headsUp is amber, urgent is red.',
    properties: {
      'source': S.string(description: 'Where it comes from, e.g. "Traffic".'),
      'variant': S.string(
        description:
            'How urgent it is: headsUp (amber, the default) or urgent (red, '
            'only for something to act on now, like an open fridge door).',
        enumValues: ['headsUp', 'urgent'],
      ),
      'title': S.string(description: 'The headline, e.g. "Rain in 20 min."'),
      'message': S.string(
        description: 'The reason line, e.g. "Garage door is open".',
      ),
      'timestamp': A2uiSchemas.stringReference(
        description: 'When it happened, e.g. "Just now".',
      ),
      'actions': S.list(
        description: 'Up to two buttons. The first is primary by default.',
        maxItems: 2,
        items: S.object(
          properties: {
            'label': S.string(
              description:
                  'The button text. When state is done, write it in the past '
                  'tense: "Blinds closed".',
            ),
            'icon': CatalogSchemas.icon(description: 'Optional icon.'),
            'isPrimary': S.boolean(description: 'Draw as the primary button.'),
            'state': A2uiSchemas.stringReference(
              description: 'pending (default) or done.',
            ),
            'action': HomeActions.spec(
              description:
                  'Choose what pressing the button does: a device command, a '
                  'scene, undo, or a request for the assistant. Never write '
                  'an event name or a label; the button label is shown while '
                  'it runs.',
            ),
          },
          required: ['label', 'action'],
        ),
      ),
    },
    required: ['title'],
  );
}
