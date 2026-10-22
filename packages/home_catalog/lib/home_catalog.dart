/// Shared A2UI component catalog for A2UI VGV Smart Home.
library;

export 'src/catalog/home_catalog.dart'
    show GenUiComponentCatalog, genUiCatalogId, homeCatalog;
export 'src/components/a2ui_schemas.dart' show A2uiSchemas;
export 'src/components/action_chips_component_definition.dart'
    show ActionChipsComponentDefinition;
export 'src/components/card_fit.dart'
    show
        CardFit,
        GridCell,
        gridAreaWidth,
        gridColumns,
        gridGutter,
        gridRowHeight,
        gridRows;
export 'src/components/catalog_schemas.dart' show CatalogSchemas;
export 'src/components/change_summary_component_definition.dart'
    show ChangeSummaryComponentDefinition;
export 'src/components/charge_card_component_definition.dart'
    show ChargeCardComponentDefinition;
export 'src/components/column_component_definition.dart'
    show ColumnComponentDefinition;
export 'src/components/countdown_card_component_definition.dart'
    show CountdownCardComponentDefinition;
export 'src/components/device_card_component_definition.dart'
    show DeviceCardComponentDefinition;
export 'src/components/gen_ui_component.dart' show GenUiComponent;
export 'src/components/heads_up_card_component_definition.dart'
    show HeadsUpCardComponentDefinition;
export 'src/components/home_actions.dart' show HomeActions;
export 'src/components/plan_timeline_component_definition.dart'
    show PlanTimelineComponentDefinition;
export 'src/components/row_component_definition.dart'
    show RowComponentDefinition;
export 'src/components/scene_card_component_definition.dart'
    show SceneCardComponentDefinition;
export 'src/components/shopping_list_component_definition.dart'
    show ShoppingListComponentDefinition;
export 'src/components/trip_card_component_definition.dart'
    show TripCardComponentDefinition;
export 'src/prompt/catalog_prompt_asset.dart' show catalogPromptAssetUri;
export 'src/prompt/render_a2ui_message_schema.dart'
    show renderA2uiMessageSchema, renderLeanA2uiMessageSchema;
export 'src/prompt/render_card_fits.dart' show renderCardFits;
export 'src/protocol.dart' show a2uiVersion, dashboardSurfaceId;
