import 'package:home_catalog/src/components/a2ui_schemas.dart';
import 'package:home_catalog/src/components/gen_ui_component.dart';
import 'package:json_schema_builder/json_schema_builder.dart';

/// {@template column_component_definition}
/// Catalog definition for the A2UI `Column` component.
/// {@endtemplate}
class ColumnComponentDefinition extends GenUiComponent {
  /// {@macro column_component_definition}
  const ColumnComponentDefinition();

  @override
  String get name => 'Column';

  @override
  Schema get schema => S.object(
    description: 'A layout widget that arranges its children vertically.',
    properties: {
      'justify': S.string(
        description: 'How children are aligned on the main axis. ',
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
      'align': S.string(
        description: 'How children are aligned on the cross axis. ',
        enumValues: ['start', 'center', 'end', 'stretch'],
      ),
      'children': A2uiSchemas.componentArrayReference(
        description:
            'Either an explicit list of widget IDs for the children, or a '
            'template with a data binding to the list of children.',
      ),
    },
    required: ['children'],
  );
}
