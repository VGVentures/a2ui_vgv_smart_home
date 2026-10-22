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
}
