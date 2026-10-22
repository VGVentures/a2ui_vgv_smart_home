import 'package:a2ui_core/a2ui_core.dart';
import 'package:home_catalog/src/components/action_chips_component_definition.dart';
import 'package:home_catalog/src/components/change_summary_component_definition.dart';
import 'package:home_catalog/src/components/charge_card_component_definition.dart';
import 'package:home_catalog/src/components/column_component_definition.dart';
import 'package:home_catalog/src/components/countdown_card_component_definition.dart';
import 'package:home_catalog/src/components/device_card_component_definition.dart';
import 'package:home_catalog/src/components/gen_ui_component.dart';
import 'package:home_catalog/src/components/heads_up_card_component_definition.dart';
import 'package:home_catalog/src/components/plan_timeline_component_definition.dart';
import 'package:home_catalog/src/components/row_component_definition.dart';
import 'package:home_catalog/src/components/scene_card_component_definition.dart';
import 'package:home_catalog/src/components/shopping_list_component_definition.dart';
import 'package:home_catalog/src/components/trip_card_component_definition.dart';

/// {@template gen_ui_component_catalog}
/// A catalog of [GenUiComponent]s — the value the frontend agent and the API
/// server consume.
///
/// Aliases `package:a2ui_core`'s `Catalog<GenUiComponent>` so catalog packages
/// built on top of this one can name and construct a catalog without a direct
/// dependency on `package:a2ui_core`. A distinct name (rather than re-exporting
/// `Catalog`) avoids colliding with `package:genui`'s own `Catalog` type in
/// consumers that import both.
/// {@endtemplate}
typedef GenUiComponentCatalog = Catalog<GenUiComponent>;

/// Stable identifier for A2UI VGV Smart Home's shared component catalog.
///
/// Surface messages that reference this catalog (e.g. A2UI `createSurface`)
/// must use this exact id so both the API server and the Flutter renderer
/// resolve the same component set.
const String genUiCatalogId = 'verygood.ventures/catalogs/home/v1';

/// The shared catalog of components used by A2UI VGV Smart Home.
///
/// The frontend consumes this to build a `package:genui` catalog of widget
/// builders. The API server renders its schemas into the LLM system prompt.
final GenUiComponentCatalog homeCatalog = GenUiComponentCatalog(
  id: genUiCatalogId,
  components: const [
    ColumnComponentDefinition(),
    RowComponentDefinition(),
    PlanTimelineComponentDefinition(),
    DeviceCardComponentDefinition(),
    ActionChipsComponentDefinition(),
    TripCardComponentDefinition(),
    ChargeCardComponentDefinition(),
    SceneCardComponentDefinition(),
    HeadsUpCardComponentDefinition(),
    ChangeSummaryComponentDefinition(),
    CountdownCardComponentDefinition(),
    ShoppingListComponentDefinition(),
  ],
);
