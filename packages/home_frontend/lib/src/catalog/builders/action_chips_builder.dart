import 'package:app_ui/app_ui.dart';
import 'package:flutter/widgets.dart';
import 'package:home_frontend/src/a2ui/a2ui.dart';
import 'package:home_frontend/src/catalog/builders/builder_helpers.dart';

/// Renders the `ActionChips` component.
Widget actionChipsBuilder(
  BuildContext context,
  ComponentNode<ComponentImplementation> node,
  ComponentProps props,
  ChildWidgetBuilder buildChild,
) {
  final data = plainProps(props);
  return ActionChips(
    label: string(data, 'label') ?? 'Suggested',
    chips: [
      for (final chip in maps(data, 'chips')) _chip(context, node, chip),
    ],
  );
}

ActionChipData _chip(
  BuildContext context,
  ComponentNode<ComponentImplementation> node,
  Map<String, Object?> chip,
) {
  final label = string(chip, 'label') ?? '';
  return ActionChipData(
    label: label,
    icon: string(chip, 'icon'),
    isPrimary: chip['isPrimary'] == true,
    onPressed: onPressed(context, node, actionFromSpec(chip['action'], label)),
  );
}
