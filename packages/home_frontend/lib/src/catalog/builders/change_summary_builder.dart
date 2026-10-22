import 'package:app_ui/app_ui.dart';
import 'package:flutter/widgets.dart';
import 'package:home_frontend/src/a2ui/a2ui.dart';
import 'package:home_frontend/src/catalog/builders/builder_helpers.dart';

/// Renders the `ChangeSummary` component.
Widget changeSummaryBuilder(CatalogItemContext context) {
  return BoundProps(
    dataContext: context.dataContext,
    data: context.data as Map<String, Object?>,
    builder: (_, props) => ChangeSummary(
      eyebrow: string(props, 'eyebrow'),
      title: string(props, 'title') ?? '',
      changes: [
        for (final change in maps(props, 'changes'))
          ChangeTileData(
            icon: string(change, 'icon'),
            label: string(change, 'label') ?? '',
            value: string(change, 'value') ?? '',
            previous: string(change, 'previous'),
            note: string(change, 'note'),
          ),
      ],
    ),
  );
}
