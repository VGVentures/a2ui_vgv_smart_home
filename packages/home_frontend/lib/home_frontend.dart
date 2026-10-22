/// A2UI VGV Smart Home public API.
library;

export 'package:home_catalog/home_catalog.dart'
    show dashboardSurfaceId, homeCatalog;

export 'src/a2ui/a2ui.dart';
export 'src/agent/genui_agent.dart' show GenUIAgent;
export 'src/agent/genui_agent_event.dart'
    show
        GenUIAgentEvent,
        UiInteractionAdded,
        UiInteractionCompleted,
        UserMessageAdded,
        UserTurnRolledBack;
export 'src/agent/http_genui_agent.dart'
    show
        AuthError,
        EmptyResponseException,
        GenUITokenProvider,
        HttpException,
        HttpGenUIAgent;
export 'src/catalog/widget_builders.dart' show widgetBuilders;
export 'src/widgets/widgets.dart'
    show DefaultErrorBubble, DefaultLoadingIndicator, DefaultUserMessageBubble;
export 'src/zone/controller/genui_zone_controller.dart'
    show GenUIZoneController;
export 'src/zone/controller/genui_zone_item.dart'
    show ErrorItem, GenUIZoneItem, SurfaceItem, UserMessageItem;
export 'src/zone/controller/genui_zone_state.dart'
    show
        GenUIZoneError,
        GenUIZoneInitial,
        GenUIZoneItemsUpdated,
        GenUIZoneState;
export 'src/zone/view/genui_zone.dart'
    show
        GenUIErrorBuilder,
        GenUILoadingBuilder,
        GenUISurfaceBuilder,
        GenUIUserMessageBuilder,
        GenUIZone;
export 'src/zone/view/lockable_surface.dart' show LockableSurface;
