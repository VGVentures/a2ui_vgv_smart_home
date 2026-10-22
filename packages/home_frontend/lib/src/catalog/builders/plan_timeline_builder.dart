import 'package:app_ui/app_ui.dart';
import 'package:flutter/widgets.dart';
import 'package:home_frontend/src/a2ui/a2ui.dart';
import 'package:home_frontend/src/catalog/builders/builder_helpers.dart';

/// Renders the `PlanTimeline` component.
///
/// Works with literal and data-bound props: `entries` and `tag` may be bound,
/// so the server can move times without resending the card.
Widget planTimelineBuilder(CatalogItemContext context) {
  return BoundProps(
    dataContext: context.dataContext,
    data: context.data as Map<String, Object?>,
    builder: (_, props) => PlanTimeline(
      title: string(props, 'title'),
      subtitle: string(props, 'subtitle'),
      density: PlanDensity.byName(string(props, 'density')),
      tag: _tag(props['tag']),
      entries: [
        for (final entry in maps(props, 'entries'))
          PlanEntry(
            time: string(entry, 'time') ?? '',
            title: string(entry, 'title') ?? '',
            detail: string(entry, 'detail'),
            icon: string(entry, 'icon'),
            previousTime: string(entry, 'previousTime'),
            changedBy: string(entry, 'changedBy'),
            status: PlanEntryStatus.byName(string(entry, 'status')),
          ),
      ],
    ),
  );
}

/// `surface/surface-container-high`, the fill of an "Updated" tag.
const _updatedFill = Color(0xFFECEAE5);

/// The tag of a plan, dressed by its kind: "Updated" on a grey fill, "Changed
/// by" on the climate wash with an edit icon, and a plain fact with a live dot.
StatusTag? _tag(Object? value) {
  if (value is! Map<String, Object?>) return null;
  final label = string(value, 'label');
  if (label == null) return null;
  final kind = StatusTagKind.byName(string(value, 'kind'));
  final icon = string(value, 'icon');
  return switch (kind) {
    StatusTagKind.moved => StatusTag(
      label: label,
      kind: kind,
      icon: icon ?? 'edit',
      tint: AppTone.climate.wash,
      ink: AppTone.climate.ink,
    ),
    StatusTagKind.updated || StatusTagKind.isNew => StatusTag(
      label: label,
      kind: kind,
      icon: icon,
      tint: _updatedFill,
    ),
    StatusTagKind.info => StatusTag(
      label: label,
      kind: kind,
      icon: icon,
      dot: icon == null ? AppColors.spark : null,
      ink: icon == null ? AppColors.ink2 : AppColors.ink,
    ),
  };
}
