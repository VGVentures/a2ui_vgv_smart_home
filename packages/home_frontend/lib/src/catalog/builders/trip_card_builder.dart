import 'package:app_ui/app_ui.dart';
import 'package:flutter/widgets.dart';
import 'package:home_frontend/src/a2ui/a2ui.dart';
import 'package:home_frontend/src/catalog/builders/builder_helpers.dart';

/// Renders the `TripCard` component.
Widget tripCardBuilder(CatalogItemContext context) {
  return BoundProps(
    dataContext: context.dataContext,
    data: context.data as Map<String, Object?>,
    builder: (_, data) {
      final footer = data['footer'];
      final tag = data['tag'];
      final progress = data['progress'];
      final percent = progress is Map<String, Object?>
          ? progress['percent']
          : null;
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
        progress: percent is num
            ? TripProgress(
                percent: percent.round(),
                icon:
                    string(progress! as Map<String, Object?>, 'icon') ?? 'trip',
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
    },
  );
}
