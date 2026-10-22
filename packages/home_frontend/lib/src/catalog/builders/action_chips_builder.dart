import 'package:app_ui/app_ui.dart';
import 'package:flutter/widgets.dart';
import 'package:home_frontend/src/a2ui/a2ui.dart';
import 'package:home_frontend/src/catalog/builders/builder_helpers.dart';

/// Renders the `ActionChips` component.
Widget actionChipsBuilder(CatalogItemContext context) {
  return BoundProps(
    dataContext: context.dataContext,
    data: context.data as Map<String, Object?>,
    builder: (_, props) => ActionChips(
      label: string(props, 'label') ?? 'Suggested',
      chips: [
        for (final chip in maps(props, 'chips')) _chip(context, chip),
      ],
    ),
  );
}

ActionChipData _chip(CatalogItemContext context, Map<String, Object?> chip) {
  final label = string(chip, 'label') ?? '';
  return ActionChipData(
    label: label,
    icon: string(chip, 'icon'),
    isPrimary: chip['isPrimary'] == true,
    onPressed: onPressed(context, actionFromSpec(chip['action'], label)),
  );
}
