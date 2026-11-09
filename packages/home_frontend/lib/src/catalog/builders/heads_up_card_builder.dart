import 'package:app_ui/app_ui.dart';
import 'package:flutter/widgets.dart';
import 'package:home_frontend/src/a2ui/a2ui.dart';
import 'package:home_frontend/src/catalog/builders/builder_helpers.dart';

/// Renders the `HeadsUpCard` component.
///
/// Works with literal and data-bound props. The buttons flip nothing locally:
/// they dispatch their action, and the server answers with the action `done`.
Widget headsUpCardBuilder(
  BuildContext context,
  ComponentNode<ComponentImplementation> node,
  ComponentProps props,
  ChildWidgetBuilder buildChild,
) {
  final data = plainProps(props);
  return HeadsUpCard(
    title: string(data, 'title') ?? '',
    message: string(data, 'message'),
    variant: HeadsUpVariant.byName(string(data, 'variant')),
    source: string(data, 'source'),
    timestamp: string(data, 'timestamp'),
    actions: [
      for (final action in maps(data, 'actions'))
        _action(context, node, action),
    ],
  );
}

HeadsUpActionData _action(
  BuildContext context,
  ComponentNode<ComponentImplementation> node,
  Map<String, Object?> action,
) {
  final label = string(action, 'label') ?? '';
  return HeadsUpActionData(
    label: label,
    icon: string(action, 'icon'),
    isPrimary: action['isPrimary'] == true,
    isDone: action['state'] == 'done',
    onPressed: onPressed(
      context,
      node,
      actionFromSpec(action['action'], label),
    ),
  );
}
