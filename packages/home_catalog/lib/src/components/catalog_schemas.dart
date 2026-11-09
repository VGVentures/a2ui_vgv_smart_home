import 'package:a2ui_core/a2ui_core.dart' show CommonSchemas, CommonSchemasV1;
import 'package:home_catalog/src/components/card_fit.dart';
import 'package:json_schema_builder/json_schema_builder.dart';

/// {@template catalog_schemas}
/// Schema pieces shared by the home components: icons, tone and status tags.
/// Actions are in `HomeActions`.
///
/// The icon and tone names are the contract with `app_ui`. A test in the
/// frontend package keeps `AppIcons` and `AppTone` identical to these lists.
/// {@endtemplate}
abstract final class CatalogSchemas {
  /// Every icon name the model may emit.
  static const List<String> iconNames = [
    'oven',
    'fridge',
    'light',
    'speaker',
    'thermostat',
    'blinds',
    'lock',
    'garage',
    'car',
    'charger',
    'doorbell',
    'meter',
    'dishwasher',
    'fan',
    'scene',
    'alert',
    'trip',
    'delivery',
    'check',
    'restaurant',
    'cake',
    'school',
    'guests',
    'flame',
    'wine',
    'send',
    'chat',
    'undo',
    'bell',
    'coffee',
    'radio',
    'volume_down',
    'timer',
    'cart',
    'share',
    'rain',
    'snowflake',
    'traffic',
    'savings',
    'clock',
    'sparkle',
    'edit',
    'plus',
    'home',
    'play',
  ];

  /// The card tones. A closed set: the model never sends colors.
  static const List<String> toneNames = [
    'neutral',
    'lighting',
    'energy',
    'climate',
    'security',
    'weather',
  ];

  /// The kinds of [statusTag].
  static const List<String> tagKinds = ['updated', 'new', 'moved', 'info'];

  /// An icon name.
  static Schema icon({String? description}) =>
      S.string(description: description, enumValues: iconNames);

  /// A card tone.
  static Schema tone({String? description}) => S.string(
    description:
        description ??
        'The card color, chosen by the kind of device or message.',
    enumValues: toneNames,
  );

  /// The small pill in a card corner that says the card changed.
  static Schema statusTag({String? description}) => S.object(
    description:
        description ??
        'A small pill saying the card changed, e.g. "Updated just now".',
    properties: {
      'label': S.string(description: 'The pill text.'),
      'kind': S.string(
        description: 'How the pill looks.',
        enumValues: tagKinds,
      ),
      'icon': icon(description: 'Optional icon, defaults from the kind.'),
    },
    required: ['label'],
  );

  /// The schema of one component: an object whose `component` is [name], with
  /// the `weight` every component can carry in a `Row`.
  ///
  /// A2UI 1.0 has each component declare its own `component` discriminator, so
  /// the catalog and the schema the model is shown read the same thing.
  static Schema component(
    String name, {
    required Map<String, Schema> properties,
    String? description,
    List<String> required = const [],
  }) => S.object(
    description: description,
    properties: {
      'component': S.string(constValue: name),
      ...properties,
      'weight': S.integer(
        description:
            'The columns this component spans in its Row, out of '
            '$gridColumns. Set it on every card in a Row and on every Column '
            'beside a full height card.',
        minimum: 1,
        maximum: gridColumns,
      ),
    },
    required: ['component', ...required],
  );

  /// A string that is literal, bound to the data model or computed.
  ///
  /// With [enumValues] the literal is one of them; a binding stays free.
  static Schema dynamicString({
    String? description,
    List<String>? enumValues,
  }) => enumValues == null
      ? _described(CommonSchemasV1.dynamicString, description)
      : S.combined(
          description: description,
          oneOf: [
            S.string(enumValues: enumValues),
            CommonSchemasV1.dataBinding,
            CommonSchemasV1.functionCall,
          ],
        );

  /// A number that is literal, bound to the data model or computed.
  static Schema dynamicNumber({String? description}) =>
      _described(CommonSchemasV1.dynamicNumber, description);

  /// A boolean that is literal, bound to the data model or computed.
  static Schema dynamicBoolean({String? description}) =>
      _described(CommonSchemasV1.dynamicBoolean, description);

  /// A path into the data model, written `{"@path": "/devices/oven/value"}`.
  static Schema dataBinding({String? description}) =>
      _described(CommonSchemasV1.dataBinding, description);

  /// A list written out, bound to the data model or computed.
  static Schema dynamicList({required Schema items, String? description}) =>
      S.combined(
        description: description,
        oneOf: [
          S.list(items: items),
          CommonSchemasV1.dataBinding,
          CommonSchemasV1.functionCall,
        ],
      );

  /// The ids of a component's children, or a template over a data list.
  static Schema childList({String? description}) =>
      _described(CommonSchemas.childList, description);

  static Schema _described(Schema schema, String? description) =>
      description == null
      ? schema
      : Schema.fromMap({...schema.value, 'description': description});
}
