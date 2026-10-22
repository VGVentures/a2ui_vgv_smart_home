import 'package:home_frontend/src/a2ui/a2ui.dart';
import 'package:home_frontend/src/zone/controller/genui_zone_item.dart';

/// {@template gen_u_i__zone_state}
/// The states a `GenUIZone` can be in while requesting and rendering a
/// generated UI.
/// {@endtemplate}
sealed class GenUIZoneState {
  /// {@macro gen_u_i__zone_state}
  const GenUIZoneState();
}

/// {@template gen_u_i__zone_initial}
/// State before any item has arrived from the agent.
///
/// The zone has produced no items yet and has not failed. The agent may or
/// may not have been started.
/// {@endtemplate}
final class GenUIZoneInitial extends GenUIZoneState {
  /// {@macro gen_u_i__zone_initial}
  const GenUIZoneInitial();
}

/// {@template gen_u_i__zone_items_updated}
/// State emitted after the agent produced at least one item.
///
/// Holds a live [SurfaceController] so the view can resolve `SurfaceContext`s
/// for each surface id, and the cumulative ordered list of items the zone has
/// rendered so far. Items include both user messages and agent surfaces in
/// arrival order.
/// {@endtemplate}
final class GenUIZoneItemsUpdated extends GenUIZoneState {
  /// {@macro gen_u_i__zone_items_updated}
  const GenUIZoneItemsUpdated({
    required this.controller,
    required this.items,
  });

  /// The controller used by the [Surface] widgets in the view.
  final SurfaceController controller;

  /// Items produced so far in the conversation, in arrival order.
  final List<GenUIZoneItem> items;
}

/// {@template gen_u_i__zone_error}
/// State emitted when the agent fails to start.
///
/// Only a failure that leaves the zone with nothing to show lands here. A turn
/// that fails after the conversation is under way is recorded as an [ErrorItem]
/// instead, so the items already on screen survive it.
/// {@endtemplate}
final class GenUIZoneError extends GenUIZoneState {
  /// {@macro gen_u_i__zone_error}
  const GenUIZoneError({required this.error});

  /// Human-readable description of the failure.
  final String error;
}
