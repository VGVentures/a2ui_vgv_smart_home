import 'package:home_catalog/src/components/a2ui_schemas.dart';
import 'package:home_catalog/src/components/gen_ui_component.dart';
import 'package:json_schema_builder/json_schema_builder.dart';

/// {@template row_component_definition}
/// Catalog definition for the A2UI `Row` component.
/// {@endtemplate}
class RowComponentDefinition extends GenUiComponent {
  /// {@macro row_component_definition}
  const RowComponentDefinition();

  @override
  String get name => 'Row';

  @override
  Schema get schema => S.object(
    description: 'A layout widget that arranges its children horizontally.',
    properties: {
      'children': A2uiSchemas.componentArrayReference(
        description:
            'Either an explicit list of widget IDs for the children, or a '
            'template with a data binding to the list of children.',
      ),
      'justify': S.string(
        enumValues: [
          'start',
          'center',
          'end',
          'spaceBetween',
          'spaceAround',
          'spaceEvenly',
          'stretch',
        ],
      ),
      'align': S.string(enumValues: ['start', 'center', 'end', 'stretch']),
    },
    required: ['children'],
  );
}
