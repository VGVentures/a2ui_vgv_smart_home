/// The only file in the app that imports `package:genui`.
///
/// Everything the frontend (and the root app) uses from the A2UI renderer is
/// listed here, so the surface of A2UI 0.9 that the code depends on is one
/// short `show` list. Moving to A2UI 1.0 means editing this file: re-point the
/// export, and bridge a renamed or reshaped symbol with a `typedef` or a small
/// wrapper next to it, rather than touching the builders, the agent or the
/// zone.
///
/// Wire-format details the code also depends on live next to the code that
/// owns them and are named in `home_frontend/AGENTS.md` under "A2UI
/// version seam".
library;

import 'package:genui/genui.dart' show StandardPart, UiPartExtension;

export 'package:genui/genui.dart'
    show
        A2uiMessage,
        A2uiTransportAdapter,
        BasicCatalogItems,
        BasicFunctions,
        Catalog,
        CatalogItem,
        CatalogItemContext,
        CatalogWidgetBuilder,
        ChatMessage,
        ChatMessageRole,
        Conversation,
        ConversationError,
        ConversationEvent,
        ConversationSurfaceAdded,
        DataContext,
        DataPath,
        Surface,
        SurfaceContext,
        SurfaceController,
        TextPart,
        UpdateDataModel,
        UserActionEvent,
        resolveContext;

/// The interaction JSON a message part carries, or null when it is not a UI
/// interaction. A press on a surface and a validation report travel as one.
String? interactionJson(StandardPart part) =>
    part.isUiInteractionPart ? part.asUiInteractionPart!.interaction : null;
