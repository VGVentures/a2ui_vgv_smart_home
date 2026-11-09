/// The only file in the app that imports the A2UI renderer packages.
///
/// Everything the frontend (and the root app) uses from `a2ui_flutter` and
/// `a2ui_core` is listed here, so the surface of A2UI 1.0 that the code depends
/// on is two short `show` lists. Moving to a new A2UI release means editing
/// this file: re-point the export, and bridge a renamed or reshaped symbol with
/// a `typedef` or a small wrapper next to it, rather than touching the
/// builders, the agent or the zone.
///
/// Wire-format details the code also depends on live next to the code that
/// owns them and are named in `home_frontend/AGENTS.md` under "A2UI version
/// seam".
library;

export 'package:a2ui_core/a2ui_core.dart'
    show
        A2uiError,
        A2uiProtocolVersion,
        A2uiRendererAction,
        A2uiRendererError,
        CapabilitiesOptions,
        ComponentNode,
        FunctionImplementation,
        MessageProcessor,
        ReadonlySignal,
        ResolvedBinding,
        SurfaceGroupModel,
        SurfaceModel,
        WritableBinding;
export 'package:a2ui_flutter/a2ui_flutter.dart'
    show
        A2uiSurface,
        CatalogImplementation,
        ChildWidgetBuilder,
        ComponentImplementation,
        ComponentProps,
        ComponentWidgetBuilder;
