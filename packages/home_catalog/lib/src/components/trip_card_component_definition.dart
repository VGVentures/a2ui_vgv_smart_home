import 'package:home_catalog/src/components/a2ui_schemas.dart';
import 'package:home_catalog/src/components/card_fit.dart';
import 'package:home_catalog/src/components/catalog_schemas.dart';
import 'package:home_catalog/src/components/gen_ui_component.dart';
import 'package:json_schema_builder/json_schema_builder.dart';

/// {@template trip_card_component_definition}
/// Catalog definition for the `TripCard` component.
///
/// Where to be and when to leave, with the stops on the way.
/// {@endtemplate}
class TripCardComponentDefinition extends GenUiComponent {
  /// {@macro trip_card_component_definition}
  const TripCardComponentDefinition();

  @override
  CardFit get fit => const CardFit(
    best: GridCell(7, 1),
    note: 'Always half tall. It shows up to 3 stops across its width.',
  );

  @override
  String get name => 'TripCard';

  @override
  Schema get schema => S.object(
    description:
        'Where the user needs to be and when to leave: a big leave-by time '
        'and up to three stops. Calendar and Maps data, not Home data. Best '
        'across the full width.',
    properties: {
      'label': S.string(description: 'Defaults to "Leave by".'),
      'leaveBy': A2uiSchemas.stringReference(
        description: 'When to leave, e.g. "5:00 PM". Bindable.',
      ),
      'previousLeaveBy': A2uiSchemas.stringReference(
        description:
            'The time before the change, e.g. "5:00 PM". Highlights the '
            'leave-by time and shows "was 5:00 PM". Bindable.',
      ),
      'footer': S.object(
        description:
            'The line under the leave-by time, e.g. "14 min · light '
            'traffic".',
        properties: {
          'icon': CatalogSchemas.icon(description: 'e.g. car or traffic.'),
          'text': A2uiSchemas.stringReference(
            description: 'The line. Bindable.',
          ),
          'tone': S.string(
            description: 'Use warning for a traffic or delay line.',
            enumValues: ['normal', 'warning'],
          ),
        },
        required: ['text'],
      ),
      'progress': S.object(
        description:
            'Makes the card an en route card: a track under the stops with '
            'an icon that sits at percent along it. Use it for an order or '
            'trip that is under way, e.g. a delivery out for delivery.',
        properties: {
          'percent': A2uiSchemas.numberReference(
            description: 'How far along, 0 to 100. Bindable.',
          ),
          'icon': CatalogSchemas.icon(
            description: 'The marker on the track, e.g. delivery or car.',
          ),
        },
        required: ['percent'],
      ),
      'tag': CatalogSchemas.statusTag(
        description: 'Says the card changed, e.g. "Updated just now".',
      ),
      'stops': A2uiSchemas.listOrReference(
        description: 'Up to three stops along the way. Bindable.',
        items: S.object(
          properties: {
            'icon': CatalogSchemas.icon(
              description: 'e.g. school, cake or home.',
            ),
            'title': S.string(description: 'e.g. "School pickup".'),
            'subtitle': S.string(description: 'e.g. "Lincoln Elementary".'),
            'time': S.string(description: 'e.g. "5:15 PM".'),
            'emphasis': S.string(
              description: 'Use good to say there is slack.',
              enumValues: ['none', 'good'],
            ),
          },
          required: ['title', 'time'],
        ),
      ),
    },
    required: ['leaveBy'],
  );
}
