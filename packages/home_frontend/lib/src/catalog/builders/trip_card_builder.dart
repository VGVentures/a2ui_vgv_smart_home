import 'package:app_ui/app_ui.dart';
import 'package:flutter/widgets.dart';
import 'package:home_frontend/src/a2ui/a2ui.dart';
import 'package:home_frontend/src/catalog/builders/builder_helpers.dart';

/// Renders the `TripCard` component.
Widget tripCardBuilder(
  BuildContext context,
  ComponentNode<ComponentImplementation> node,
  ComponentProps props,
  ChildWidgetBuilder buildChild,
) {
  final data = plainProps(props);
  final footer = data['footer'];
  final tag = data['tag'];
  return TripCard(
    label: string(data, 'label') ?? 'Leave by',
    leaveBy: string(data, 'leaveBy') ?? '',
    previousLeaveBy: string(data, 'previousLeaveBy'),
    footer: footer is Map<String, Object?> && string(footer, 'text') != null
        ? TripFooter(
            text: string(footer, 'text')!,
            icon: string(footer, 'icon') ?? 'car',
            tone: TripFooterTone.byName(string(footer, 'tone')),
          )
        : null,
    tag: tag is Map<String, Object?> ? string(tag, 'label') : null,
    tagKind: StatusTagKind.byName(
      tag is Map<String, Object?> ? string(tag, 'kind') : null,
    ),
    tagIcon: tag is Map<String, Object?> ? string(tag, 'icon') : null,
    stops: [
      for (final stop in maps(data, 'stops'))
        TripStop(
          title: string(stop, 'title') ?? '',
          time: string(stop, 'time') ?? '',
          subtitle: string(stop, 'subtitle'),
          icon: string(stop, 'icon'),
          emphasis: TripStopEmphasis.byName(string(stop, 'emphasis')),
        ),
    ],
  );
}
