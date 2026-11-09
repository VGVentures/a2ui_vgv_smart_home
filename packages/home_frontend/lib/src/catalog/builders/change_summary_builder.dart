import 'package:app_ui/app_ui.dart';
import 'package:flutter/widgets.dart';
import 'package:home_frontend/src/a2ui/a2ui.dart';
import 'package:home_frontend/src/catalog/builders/builder_helpers.dart';

/// Renders the `ChangeSummary` component.
Widget changeSummaryBuilder(
  BuildContext context,
  ComponentNode<ComponentImplementation> node,
  ComponentProps props,
  ChildWidgetBuilder buildChild,
) {
  final data = plainProps(props);
  return ChangeSummary(
    eyebrow: string(data, 'eyebrow'),
    title: string(data, 'title') ?? '',
    changes: [
      for (final change in maps(data, 'changes'))
        ChangeTileData(
          icon: string(change, 'icon'),
          label: string(change, 'label') ?? '',
          value: string(change, 'value') ?? '',
          previous: string(change, 'previous'),
          note: string(change, 'note'),
        ),
    ],
  );
}
