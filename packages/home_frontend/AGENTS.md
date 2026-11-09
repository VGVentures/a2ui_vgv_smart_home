# home_frontend

The Flutter half of A2UI VGV Smart Home. It renders A2UI surfaces produced by the
backend into real widgets, and reports user interactions back.

It answers "how is a component rendered". It does not answer "what components
exist" — that is the sibling `home_catalog` package, which this one
depends on by path.

## Layout

```
lib/
├── home_frontend.dart              public barrel
└── src/
    ├── agent/                           talks to the backend
    │   ├── genui_agent.dart             the GenUIAgent interface
    │   ├── http_genui_agent.dart        the default POST /generate and /action impl
    │   ├── genui_agent_event.dart       events the agent emits
    │   ├── history_entry.dart           one turn of the history sent to the backend
    │   └── generate_response.dart       the {messages, reply} payload decoding
    ├── catalog/
    │   ├── widget_builders.dart         component name -> widget builder
    │   ├── grid_layout.dart             the Row and Column builders
    │   └── genui_catalog.dart           buildCatalog, zips the two halves
    ├── widgets/
    │   ├── widgets.dart                 widget export barrel
    │   ├── default_error_bubble.dart
    │   ├── default_loading_indicator.dart
    │   └── default_user_message_bubble.dart
    └── zone/
        ├── controller/                  state ownership
        └── view/                        rendering
example/                                 runnable app
test/                                    mirrors lib/src/
```

## A2UI version seam

`lib/src/a2ui/a2ui.dart` is the only file in `lib/` that imports
`package:a2ui_flutter` and `package:a2ui_core`. It lists every renderer symbol
the app uses, and the barrel re-exports it so the root app never imports them
either. Import from it, never from those packages. To move to a new A2UI
release, change this file, adding a `typedef` or a small wrapper there for a
symbol that was renamed or reshaped.

`a2ui_core` is declared directly in each package that imports it (this one,
`home_catalog` and `home_backend`), since importing a transitive package breaks
`depend_on_referenced_packages`. `a2ui_agent` is the backend's alone.

Two things the seam cannot hide, because they are the wire format itself:

- The action shape `{event: {name, context}}` that `homeAction` in
  `builders/builder_helpers.dart` writes.
- The `{action: {...}}` JSON that `HttpGenUIAgent` sends as the content of a
  press, which is `A2uiRendererAction.toJson()`.

Tests may import `package:a2ui_core` for the messages they build, since those
fixtures change with the version. Component ids must be valid UAX #31
identifiers (`button_1`, not `button-1`): the renderer refuses the message
otherwise.

## Rendering a new component

Half the work lives in `home_catalog` — the `GenUiComponent` definition
with its `name` and `Schema`. See that package's `AGENTS.md`. The frontend half
is this:

1. **Write the widget.** Add it under `lib/src/widgets/`. It receives already
   decoded data and renders it.

2. **Export it.** Add the file to `lib/src/widgets/widgets.dart`, and to
   `lib/home_frontend.dart` if consumers need to name the type.

3. **Register the builder.** Add an entry to the `widgetBuilders` map in
   `lib/src/catalog/widget_builders.dart`, keyed by the exact component `name`
   the catalog declares. The map is `const`, so the value must be a top-level
   function, not a closure. A builder is a `ComponentWidgetBuilder`:
   `(BuildContext, ComponentNode, ComponentProps, ChildWidgetBuilder)`. The
   renderer calls it again whenever a bound prop changes, so it is a pure
   function of `props`:
   - `plainProps(props)` is the props with every binding replaced by its value,
     which is what a card reads; `props.writable('key')` is the binding to write
     a value through.
   - A press goes through `onPressed(context, node, homeAction(...))` or
     `dispatch(A2uiSurface.of(context), node, action)`, which raise the action
     on the surface. The agent hears it from `SurfaceModel.onAction`.

4. **Test both.** A widget test under `test/widgets/`, a builder test that
   calls `pumpBuilder` (`test/catalog/builders/pump_builder.dart`) so the props
   are resolved by a real surface, and coverage of the new key in
   `test/catalog/genui_catalog_test.dart`.

### The map key is a contract

`buildCatalog` in `lib/src/catalog/genui_catalog.dart` zips the catalog's
components against `widgetBuilders` by name into a `CatalogImplementation` (A2UI
1.0) and throws a `StateError` naming every component with no builder. That happens at construction, before the first
frame, so a mismatch is a launch-time crash rather than a render-time blank.

Keys must match the catalog's `GenUiComponent.name` exactly, case included.
Extra keys in the map are ignored; missing ones are fatal.

## The panel grid

`lib/src/catalog/grid_layout.dart` draws the model's `Row` and `Column` on the
12 column by 2 row grid of the Figma component catalog. Both builders read their
children as `ComponentNode`s, so a template child list is laid out like a list,
and they listen to the props of the cards under them, since a node's props do
not change when a child's do. A card's width is its
`weight`, the columns it spans, and every cell is drawn at exactly that
proportion; nothing is dropped and nothing is stretched. A screen is a root
`Column` of one `Row` or two, or of one `Row` that holds a full height card and
`Column` bands of up to two cards, ending with `ActionChips`. What a screen may
hold is the catalog's `GenUiComponent.fit`, which the backend's `LayoutValidator`
enforces before a reply is sent, so the renderer never has to choose what to
leave out. `Text`, `Button` and `DateTimeInput` are not in the catalog, as they
are not on the board.

## Updates outside a reply

`GenUIAgent.apply` puts an A2UI 1.0 message that did not come in a reply on the
surface, such as the `updateDataModel` the backend sends over `/live` as a device
changes (`LiveCubit.surfaceMessages`, forwarded by `MemberDashboard`). A card
bound to the path changes in place and nothing is asked of the model. A message
the processor refuses is logged and dropped.

A reply carries the values its devices had when it was written, and one may
have changed since. So `HttpGenUIAgent` keeps the latest update that came for
each path and puts them back after a reply lands, in the same `processMessages`
call: the newest word on a value is always the last update for it. The
messages already name the `dashboard` surface, so nothing addresses them.

## The whole dashboard, as messages

`POST /generate` and `POST /action` answer `{messages, reply}`. `messages` are
validated A2UI 1.0 messages for the one `dashboard` surface: on the first turn a
single `createSurface` that carries the components and the data model, and on
later turns the `updateDataModel` messages and the `updateComponents` that
replace the dashboard. `HttpGenUIAgent` applies them, with the newest update per
path, in one `processMessages` call, so the panel never shows half of a
dashboard and a message the renderer refuses fails the turn before anything is
applied. `reply` is the model's own text, kept as the assistant entry of the
history.

Every request carries `metadata`: `a2uiRendererCapabilities` from
`MessageProcessor.getRendererCapabilities`, and `a2uiRendererDataModel` from
`getRendererDataModel`. The backend keeps no state, so the surface ids in the
data model are how it learns the dashboard exists and tells the model to update
it instead of creating it. `createSurface` sets `sendDataModel: true` for that.

`lib/src/queue/turn_queue.dart` runs presses and typed or spoken turns one at a
time: A2UI orders messages only within one stream, so the app orders its own
turns. A `refresh` (data changed behind the person's back) is dropped when one of
those runs or waits, folded when another refresh is asking, and marked stale when
one starts while it asks. `GenUIAgent.refresh` is the entry point for the app's
own refreshes.

## Zone: controller and view

The zone is the bounded region of the app the LLM draws into. Ownership splits
across `lib/src/zone/`:

| File | Owns |
| --- | --- |
| `controller/genui_zone_controller.dart` | The `ChangeNotifier` driving one `GenUIAgent`. Subscribes to agent events, accumulates items and tracks `isSending`. |
| `controller/genui_zone_item.dart` | `GenUIZoneItem`, sealed over `UserMessageItem`, `SurfaceItem`, and `ErrorItem`. One entry per row the zone renders. A `SurfaceItem` holds the surface id; the view finds the model in `GenUIZoneItemsUpdated.surfaces`. |
| `controller/genui_zone_state.dart` | `GenUIZoneState`, sealed over `GenUIZoneInitial`, `GenUIZoneItemsUpdated`, `GenUIZoneError`. |
| `view/genui_zone.dart` | The public `GenUIZone.chat` widget and the four builder typedefs — surface, user message, error, loading. |
| `view/genui_zone_view.dart` | Listens to the controller and switches over its state. Holds the default builders. |
| `view/surface_view.dart` | `SurfaceView`: draws a `SurfaceModel` with `A2uiSurface` once it has a `root`, and a placeholder before. |
| `view/lockable_surface.dart` | Freezes a surface once it is no longer the latest turn. |

Rules that hold across those files:

- The host constructs the controller, calls `start()` exactly once, and disposes
  it. The controller does not own the agent it drives; whoever built the agent
  disposes it.
- Both `GenUIZoneItem` and `GenUIZoneState` are sealed. Adding a variant makes
  every `switch` in the view a compile error, which is the point. Do not add a
  default case to silence it.
- Only a failed `start()` is terminal: `GenUIZoneError` replaces the item list.
  A turn that fails after that appends an `ErrorItem` instead, so one bad turn
  does not erase the conversation before it.
- `ErrorItem` carries the error object, not a string, and `errorBuilder`
  receives it as-is so a host can branch on the type — `AuthError` to ask for the
  Gemini key again, `HttpException` to offer a retry. Do not flatten it with `toString`
  before it reaches the builder; only the default bubble renders it.

## Interaction and send lifecycle

1. The host calls `controller.sendMessage(text)`. `isSending` flips true and
   listeners are notified.
2. The agent emits `UserMessageAdded` before the request leaves, so the bubble
   appears immediately rather than after the round trip.
3. The response arrives and the processor creates a surface, which the agent
   forwards as a `SurfaceAdded` event. The controller appends a `SurfaceItem`
   and clears `isSending`.
4. The view recomputes which surface is latest and rebuilds.

A turn the user starts from a surface rather than the input bar runs the same
lifecycle, but the host never called `sendMessage`, so the agent reports the
edges itself: `UiInteractionAdded` when the interaction is recorded and
`UiInteractionCompleted` on every exit path. Without that pair the zone would
never learn the turn ended and would sit disabled.

`UiInteractionCompleted` says how the turn ended. `succeeded` is false on every
failure exit (HTTP error, auth error, empty or malformed reply, network error).
`reason` is the backend's own `message`, set only when a press (`POST /action`)
got a non-2xx answer with a parseable `{"message": ...}` body. It is null for a
401, a network error or any other failure, so the host shows its generic line.
The controller counts failed turns in `failedTurns` (it also notifies), and the
host feeds that to `OptimisticScope(revision: ...)` from `app_ui`.

### Optimistic controls

A switch, stepper or checkbox flips on tap before the backend answers, and
takes the flip back when the turn fails (phase 1: a new surface replaces the
whole tree, so a successful turn settles them by itself).

- The `app_ui` `DeviceCard` and `ShoppingList` hold the flip in widget state, bound
  or literal, drop it when their prop changes, and drop it when the nearest
  `OptimisticScope` revision changes.
- A bound prop is also written through its `WritableBinding`, by
  `OptimisticWrites` in `builder_helpers.dart`. It remembers the value the
  binding held before the first write and restores it on the same revision
  change (`OptimisticWritesHost` for builders that are plain functions). The
  restore runs after the frame, since it writes while the tree is building.

A turn that fails emits `UserTurnRolledBack`, because the agent drops the user
message from its history — the server rejects a history ending on two
consecutive user messages, so a dangling entry would break the next request.
The controller keeps the bubble on screen and marks it failed instead of
removing it.

"Latest" means at or after the index of the last `UserMessageItem` that did not
fail. Everything before it is stale, and the default surface builder wraps stale
surfaces in `LockableSurface`. A failed message is skipped deliberately: the
turn it started produced nothing, so letting it count as latest would freeze the
surface before it over a turn the model never answered.

`LockableSurface` locks three ways at once, and all three matter. `IgnorePointer`
drops input, `Opacity` signals the state visually, and `Semantics(enabled:
false)` tells screen readers. Preserve all three in any replacement — dropping
the `Semantics` leaves assistive tech offering controls that no longer respond.

A host that supplies its own `surfaceBuilder` takes over that responsibility.
It receives `isLatest` and decides what freezing means.

## Agent

`GenUIAgent` is the interface; `HttpGenUIAgent` is the shipped implementation,
which owns a `MessageProcessor` (`surfaces` is its `SurfaceGroupModel`).
It posts to `<baseUri>/generate` and expects a buffered JSON body, not a stream.

A press on a rendered surface (an `A2uiRendererAction` a builder raised with
`dispatchAction`, heard on `SurfaceModel.onAction`) posts to
`<baseUri>/action` instead, with the same `messages` plus
`action: {name, context}`. A press has no caller to throw to, so a failed press
is reported as a `TurnFailed` event. The renderer's own error reports
(`SurfaceModel.onError`) are logged and never sent to the model. The answer, headers and auth are the same. Typed or
spoken text and client validation reports stay on `/generate`. So does a press
named `ask` (`HomeActions.ask`), which is a typed request, not a command: its
wire content is the plain `context.text`, also when it appears in history, and
it carries no `action`. Its label and failure `reason` work as for any press. The turn's label
is `action.context.progressLabel` (trimmed, non-empty), then the first literal
text under the component, then the action name.

- Failures arrive as HTTP status codes carrying a `message` body, not as in-band
  events. The thrown message names the path (`POST /action failed ...`); the
  raw backend message travels separately as `UiInteractionCompleted.reason`. `AuthError` extends `HttpException`, so existing catches keep working.
- `tokenProvider` is called on every request. It is expected to do its own
  caching; the agent adds no second layer. A null or empty token throws
  `AuthError` before the request leaves the client.
- `GenerateResponse` validates the payload and throws `FormatException` on
  anything off-contract, so a malformed body surfaces as one defined error
  rather than a `TypeError` from deep inside a map lookup.
- A well-formed 2xx carrying no text throws `EmptyResponseException`, which is
  deliberately **not** an `HttpException` — nothing failed at the transport
  level. The turn still fails, because the server rejects history entries with
  empty content and persisting one would break the next request.

Swapping transports means implementing `GenUIAgent`, not editing
`HttpGenUIAgent`. The controller depends only on the interface.

## Generating a component instead of writing it

The `convert_design_system_to_genui_catalog_item` MCP prompt takes a Flutter
widget — a file path, a class name, or its source — and produces the catalog
definition, the `widget_builders.dart` entry here, and tests for both. Prefer it
when porting an existing design system widget.
