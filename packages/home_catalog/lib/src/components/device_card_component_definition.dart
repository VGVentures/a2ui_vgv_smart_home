import 'package:home_catalog/src/components/a2ui_schemas.dart';
import 'package:home_catalog/src/components/card_fit.dart';
import 'package:home_catalog/src/components/catalog_schemas.dart';
import 'package:home_catalog/src/components/gen_ui_component.dart';
import 'package:home_catalog/src/components/home_actions.dart';
import 'package:json_schema_builder/json_schema_builder.dart';

/// {@template device_card_component_definition}
/// Catalog definition for the `DeviceCard` component.
///
/// One device's state plus one control slot: a toggle, a stepper, a button or
/// nothing. The state props (`isActive`, `isLoading`, `value`, `status`,
/// `delta`, `tag`) may be bound to the data model so the server can move
/// them in place.
/// {@endtemplate}
class DeviceCardComponentDefinition extends GenUiComponent {
  /// {@macro device_card_component_definition}
  const DeviceCardComponentDefinition();

  @override
  CardFit get fit => const CardFit(
    best: GridCell(4, 1),
    also: [GridCell(3, 1), GridCell(5, 1)],
    note: 'Always half tall, never a full height cell.',
  );

  @override
  String get name => 'DeviceCard';

  @override
  Schema get schema => S.object(
    description:
        "One Google Home device's state with an optional control, for "
        'example an oven, a thermostat or a coffee maker.',
    properties: {
      'deviceId': S.string(
        description: 'The id of the device, from the device data.',
      ),
      'name': S.string(description: 'The device name, e.g. "Oven".'),
      'room': S.string(
        description: 'The room, shown before the status line, e.g. "Entry".',
      ),
      'status': A2uiSchemas.stringReference(
        description: 'A short state line, e.g. "Preheats at 6:00 PM".',
      ),
      'icon': CatalogSchemas.icon(
        description: 'An icon that matches the device kind.',
      ),
      'tone': CatalogSchemas.tone(
        description:
            'The card color by device kind: neutral for oven, fridge, '
            'speaker, timer and coffee; lighting for lights and blinds; '
            'climate for thermostats; energy for the meter and charger; '
            'security for locks, garage and doorbell; weather for outside.',
      ),
      'value': A2uiSchemas.stringReference(
        description: 'The hero reading, e.g. "400" or "Locked".',
      ),
      'unit': S.string(
        description: 'The small unit after the hero, e.g. "°F" or "kWh".',
      ),
      'delta': A2uiSchemas.stringReference(
        description: 'A line next to the hero, e.g. "↑ from 72 °F".',
      ),
      'tag': S.combined(
        description:
            'A pill beside the icon that says the device just changed, e.g. '
            '"Updated just now". The control stays. Literal or data-bound.',
        oneOf: [CatalogSchemas.statusTag(), A2uiSchemas.dataBindingSchema()],
      ),
      'isActive': A2uiSchemas.booleanReference(
        description: 'True when the device is on. Bind it for a toggle.',
      ),
      'isLoading': A2uiSchemas.booleanReference(
        description:
            'True while a command on the device is still running: the card '
            'is drawn as a skeleton with an "Updating…" note.',
      ),
      'control': S.object(
        description:
            'The one control of the card. The client builds what a press '
            'does: a toggle turns the device on or off, a stepper raises or '
            'lowers it, a button runs `command`.',
        properties: {
          'type': S.string(
            description: 'Which control to show.',
            enumValues: ['toggle', 'stepper', 'button', 'none'],
          ),
          'label': S.string(
            description: 'The button text, imperative, e.g. "Brew".',
            maxLength: 22,
          ),
          'icon': CatalogSchemas.icon(description: 'The button icon.'),
          'command': S.string(
            description: 'The command a button runs. Button only.',
            enumValues: HomeActions.commands,
          ),
        },
        required: ['type'],
      ),
    },
    required: ['deviceId', 'name', 'status'],
  );
}
