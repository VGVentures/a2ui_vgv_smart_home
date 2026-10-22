import 'package:home_catalog/src/components/a2ui_schemas.dart';
import 'package:home_catalog/src/components/card_fit.dart';
import 'package:home_catalog/src/components/catalog_schemas.dart';
import 'package:home_catalog/src/components/gen_ui_component.dart';
import 'package:json_schema_builder/json_schema_builder.dart';

/// {@template shopping_list_component_definition}
/// Catalog definition for the `ShoppingList` component.
///
/// A short checklist the user ticks off.
/// {@endtemplate}
class ShoppingListComponentDefinition extends GenUiComponent {
  /// {@macro shopping_list_component_definition}
  const ShoppingListComponentDefinition();

  @override
  CardFit get fit => const CardFit(
    best: GridCell(5, 2),
    note: 'Always the full height cell.',
  );

  @override
  String get name => 'ShoppingList';

  @override
  Schema get schema => S.object(
    description:
        'A short checklist, e.g. shopping for tonight. Ticking a row flips it '
        'at once and tells the backend (toggle_todo). The open count is '
        'computed on the client. Best 5 columns wide and two rows tall.',
    properties: {
      'listId': S.string(
        description: 'The id of the list, from the list data.',
      ),
      'title': S.string(description: 'e.g. "Shopping".'),
      'subtitle': S.string(
        description: 'e.g. "Missing from the fridge · dinner for 6".',
      ),
      'icon': CatalogSchemas.icon(description: 'Defaults to cart.'),
      'items': S.list(
        description:
            'Every item of the list, ticked or not, two to five rows. Never '
            'only the open ones.',
        minItems: 2,
        maxItems: 5,
        items: S.object(
          properties: {
            'id': S.string(description: 'A stable id, e.g. "ribs".'),
            'label': S.string(description: 'e.g. "Short ribs".'),
            'detail': S.string(description: 'e.g. "4 lb · bone-in".'),
            'checked': A2uiSchemas.booleanReference(
              description:
                  'Whether the row is ticked. Bind it to the data model so '
                  'a tick can flip it. Defaults to false.',
            ),
          },
          required: ['id', 'label'],
        ),
      ),
      'footerAction': S.object(
        description:
            'The full-width pill under the list. Pressing it shares the list.',
        properties: {
          'label': S.string(description: 'e.g. "Share list with Marco".'),
          'icon': CatalogSchemas.icon(description: 'e.g. share.'),
        },
        required: ['label'],
      ),
    },
    required: ['listId', 'title', 'items'],
  );
}
