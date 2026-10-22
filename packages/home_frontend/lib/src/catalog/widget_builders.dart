import 'package:home_frontend/src/a2ui/a2ui.dart';
import 'package:home_frontend/src/catalog/builders/action_chips_builder.dart';
import 'package:home_frontend/src/catalog/builders/change_summary_builder.dart';
import 'package:home_frontend/src/catalog/builders/charge_card_builder.dart';
import 'package:home_frontend/src/catalog/builders/countdown_card_builder.dart';
import 'package:home_frontend/src/catalog/builders/device_card_builder.dart';
import 'package:home_frontend/src/catalog/builders/heads_up_card_builder.dart';
import 'package:home_frontend/src/catalog/builders/plan_timeline_builder.dart';
import 'package:home_frontend/src/catalog/builders/scene_card_builder.dart';
import 'package:home_frontend/src/catalog/builders/shopping_list_builder.dart';
import 'package:home_frontend/src/catalog/builders/trip_card_builder.dart';
import 'package:home_frontend/src/catalog/grid_layout.dart';

/// Flutter widget builders for the shared kit catalog.
///
/// Keyed by `GenUiComponent.name` so the kit can pair each shared component
/// definition with its renderer. The catalog is the Figma component catalog:
/// the home cards, the footer, and the `Row` and `Column` they are placed
/// with, drawn by the 12 column grid.
const Map<String, CatalogWidgetBuilder> widgetBuilders = {
  'Column': gridColumnBuilder,
  'Row': gridRowBuilder,
  'PlanTimeline': planTimelineBuilder,
  'DeviceCard': deviceCardBuilder,
  'ActionChips': actionChipsBuilder,
  'TripCard': tripCardBuilder,
  'ChargeCard': chargeCardBuilder,
  'SceneCard': sceneCardBuilder,
  'HeadsUpCard': headsUpCardBuilder,
  'ChangeSummary': changeSummaryBuilder,
  'CountdownCard': countdownCardBuilder,
  'ShoppingList': shoppingListBuilder,
};

/// Component names `Row` and `Column` must wrap in a `Flexible`.
///
/// Unflagged width-filling renderers lay out unbounded and the surface never
/// paints. Must match the flags `package:genui` sets on `BasicCatalogItems`.
/// The home cards fill their width with an `Expanded` inside, so each one is
/// flagged and a `Row` gives it a bounded share of the width.
const Set<String> implicitlyFlexibleComponents = {
  'PlanTimeline',
  'DeviceCard',
  'ActionChips',
  'TripCard',
  'ChargeCard',
  'SceneCard',
  'HeadsUpCard',
  'ChangeSummary',
  'CountdownCard',
  'ShoppingList',
};
