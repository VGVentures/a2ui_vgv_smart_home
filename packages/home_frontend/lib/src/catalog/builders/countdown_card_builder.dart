import 'package:app_ui/app_ui.dart';
import 'package:flutter/widgets.dart';
import 'package:home_frontend/src/a2ui/a2ui.dart';
import 'package:home_frontend/src/catalog/builders/builder_helpers.dart';

/// Renders the `CountdownCard` component.
///
/// Works with literal and data-bound props. The countdown is computed and
/// ticked by the widget from `startsAt`; "now" comes from the nearest
/// `NowScope`, which the app fills with its scenario clock.
Widget countdownCardBuilder(CatalogItemContext context) {
  return BoundProps(
    dataContext: context.dataContext,
    data: context.data as Map<String, Object?>,
    builder: (_, props) {
      final raw = string(props, 'startsAt');
      final startsAt = raw == null ? null : parseWallTime(raw);
      if (startsAt == null) return const SizedBox.shrink();
      return CountdownCard(
        startsAt: startsAt,
        tag: _tag(props['tag']),
        eyebrow: string(props, 'eyebrow'),
        subtitle: string(props, 'subtitle'),
        tone: AppTone.byName(
          string(props, 'tone'),
          fallback: AppTone.lighting,
        ),
      );
    },
  );
}

/// Reads an ISO 8601 time as the household's wall clock, ignoring any offset.
///
/// The model copies the offset of the calendar's time zone onto `startsAt`
/// (`19:00:00-05:00`), but the app's scenario clock is a wall time, so "now"
/// and the event have to be compared as wall times: the same fields on any
/// machine, whatever its own time zone. Null when it is not a time.
@visibleForTesting
DateTime? parseWallTime(String iso) {
  final match = RegExp(
    r'^(\d{4}-\d{2}-\d{2}[T ]\d{2}:\d{2}(?::\d{2})?)',
  ).firstMatch(iso.trim());
  return match == null ? null : DateTime.tryParse(match.group(1)!);
}

StatusTag? _tag(Object? value) {
  if (value is! Map<String, Object?>) return null;
  final label = string(value, 'label');
  if (label == null) return null;
  return StatusTag(
    label: label,
    kind: StatusTagKind.byName(string(value, 'kind')),
    icon: string(value, 'icon'),
    tint: AppColors.brandYellow100,
  );
}
