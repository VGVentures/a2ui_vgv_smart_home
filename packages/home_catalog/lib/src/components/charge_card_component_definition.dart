import 'package:home_catalog/src/components/a2ui_schemas.dart';
import 'package:home_catalog/src/components/card_fit.dart';
import 'package:home_catalog/src/components/catalog_schemas.dart';
import 'package:home_catalog/src/components/gen_ui_component.dart';
import 'package:json_schema_builder/json_schema_builder.dart';

/// {@template charge_card_component_definition}
/// Catalog definition for the `ChargeCard` component.
///
/// Battery, range and charging window for a car.
/// {@endtemplate}
class ChargeCardComponentDefinition extends GenUiComponent {
  /// {@macro charge_card_component_definition}
  const ChargeCardComponentDefinition();

  @override
  CardFit get fit => const CardFit(
    best: GridCell(4, 1),
    also: [GridCell(5, 1)],
  );

  @override
  String get name => 'ChargeCard';

  @override
  Schema get schema => S.object(
    description:
        "The car's battery, range and charging window. Always the energy "
        'tone. Under 30 percent the bar turns warm, so add an HeadsUpCard.',
    properties: {
      'title': S.string(description: 'Defaults to "Car".'),
      'status': S.string(
        description: 'Shown after the title, e.g. "Plugged in".',
      ),
      'percent': A2uiSchemas.numberReference(
        description: 'Battery level, 0 to 100. Bindable.',
      ),
      'range': A2uiSchemas.stringReference(
        description: 'e.g. "190 mi range". Bindable.',
      ),
      'summary': A2uiSchemas.stringReference(
        description: 'e.g. "Enough for both stops". Bindable.',
      ),
      'window': A2uiSchemas.stringReference(
        description: 'The footer text, e.g. "Charging tonight 9 PM - 6 AM".',
      ),
      'windowIcon': S.string(
        description: 'clock for a window, savings for a saving.',
        enumValues: ['clock', 'savings'],
      ),
      'tag': CatalogSchemas.statusTag(
        description: 'e.g. "Not charging" or "Updated".',
      ),
    },
    required: ['percent'],
  );
}
