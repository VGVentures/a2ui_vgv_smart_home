import 'package:app_ui/app_ui.dart';
import 'package:flutter/widgets.dart';
import 'package:home_frontend/src/a2ui/a2ui.dart';
import 'package:home_frontend/src/catalog/builders/builder_helpers.dart';

/// Renders the `HeadsUpCard` component.
///
/// Works with literal and data-bound props. The buttons flip nothing locally:
/// they dispatch their action, and the server answers with the action `done`.
Widget headsUpCardBuilder(CatalogItemContext context) {
  return BoundProps(
    dataContext: context.dataContext,
    data: context.data as Map<String, Object?>,
    builder: (_, props) => HeadsUpCard(
      title: string(props, 'title') ?? '',
      message: string(props, 'message'),
      variant: HeadsUpVariant.byName(string(props, 'variant')),
      source: string(props, 'source'),
      timestamp: string(props, 'timestamp'),
      actions: [
        for (final action in maps(props, 'actions')) _action(context, action),
      ],
    ),
  );
}

HeadsUpActionData _action(
  CatalogItemContext context,
  Map<String, Object?> action,
) {
  final label = string(action, 'label') ?? '';
  return HeadsUpActionData(
    label: label,
    icon: string(action, 'icon'),
    isPrimary: action['isPrimary'] == true,
    isDone: action['state'] == 'done',
    onPressed: onPressed(context, actionFromSpec(action['action'], label)),
  );
}
