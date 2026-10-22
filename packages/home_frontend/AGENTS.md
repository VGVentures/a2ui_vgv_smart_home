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
    │   └── generate_response.dart       /generate payload decoding
    ├── catalog/
    │   ├── widget_builders.dart         component name -> widget builder
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
`package:genui`. It lists every renderer symbol the app uses, and the barrel
re-exports it so the root app never imports `genui` either. Import from it, never
from `package:genui`. To move to a new A2UI release, change this file, adding a
`typedef` or a small wrapper there for a symbol that was renamed or reshaped.

Two things the seam cannot hide, because they are the wire format itself:

- The action shape `{event: {name, context}}` and `{functionCall}` in
  `builders/builder_helpers.dart`.
- The decoded `{action: {...}}` interaction JSON read in
  `agent/http_genui_agent.dart`.

Tests keep importing `package:genui` for the protocol messages they build
(`CreateSurface`, `UpdateComponents`), since those fixtures change with the
version.

`a2ui_core` is pinned only in `home_catalog`. Other packages take the catalog
type as `GenUiComponentCatalog` instead of depending on it.

## Rendering a new component

Half the work lives in `home_catalog` — the `GenUiComponent` definition
with its `name` and `Schema`. See that package's `AGENTS.md`. The frontend half
is this:

1. **Write the widget.** Add it under `lib/src/widgets/`. It receives already
   decoded data and renders it. Skip this step when a `package:genui`
   `BasicCatalogItems` entry already renders the shape you want.

2. **Export it.** Add the file to `lib/src/widgets/widgets.dart`, and to
   `lib/home_frontend.dart` if consumers need to name the type.

3. **Register the builder.** Add an entry to the `widgetBuilders` map in
   `lib/src/catalog/widget_builders.dart`, keyed by the exact component `name`
   the catalog declares. The map is `const`, so the value must be a top-level
   function, not a closure.

4. **Test both.** A widget test under `test/widgets/`, and coverage of the new
   key in `test/catalog/genui_catalog_test.dart`.

### The map key is a contract

`buildCatalog` in `lib/src/catalog/genui_catalog.dart` zips the catalog's
components against `widgetBuilders` by name and throws a `StateError` naming
every component with no builder. That happens at construction, before the first
frame, so a mismatch is a launch-time crash rather than a render-time blank.

Keys must match the catalog's `GenUiComponent.name` exactly, case included.
Extra keys in the map are ignored; missing ones are fatal.

`buildCatalog` also derives a system prompt fragment listing the component names
and telling the model to use nothing else, so the map indirectly shapes what the
LLM is allowed to emit.

## The panel grid

`lib/src/catalog/grid_layout.dart` draws the model's `Row` and `Column` on the
12 column by 2 row grid of the Figma component catalog. A card's width is its
`weight`, the columns it spans, and every cell is drawn at exactly that
proportion; nothing is dropped and nothing is stretched. A screen is a root
`Column` of one `Row` or two, or of one `Row` that holds a full height card and
`Column` bands of up to two cards, ending with `ActionChips`. What a screen may
hold is the catalog's `GenUiComponent.fit`, which the backend's `LayoutValidator`
enforces before a reply is sent, so the renderer never has to choose what to
leave out. `Text`, `Button` and `DateTimeInput` are not in the catalog, as they
are not on the board.

## Updates outside a reply

`GenUIAgent.apply` puts an A2UI message that did not come in a reply on the
surface, such as the `updateDataModel` the backend sends over `/live` as a device
changes (`LiveCubit.surfaceMessages`, forwarded by `MemberDashboard`). A card
bound to the path changes in place and nothing is asked of the model.

A reply carries the values its devices had when it was written, and one may
have changed since. So `HttpGenUIAgent` keeps the latest update that came for
each path and puts them back after a reply lands: the newest word on a value is
always the last update for it. `StableSurface.address` points the message at the
one surface, as it does for a reply.

## Turn queue and stable surface

`lib/src/queue/` stands in for the ordered agent stream A2UI 1.0 defines, until
the official client replaces it. It is opt-in: `HttpGenUIAgent` only uses it
when given `stableSurfaceId`, which the root app's `HttpAgentFactory` does.

| File | Does |
| --- | --- |
| `turn_queue.dart` | Runs presses and typed or spoken turns one at a time. A `refresh` (data changed behind the person's back) is dropped when one of those runs or waits, folded when another refresh is asking, and marked stale when one starts while it asks. |
| `stable_surface.dart` | Addresses every message of every reply to one surface id, lets `createSurface` through once, and rejects a reply with no `root` or with a component pointing at a missing id, before the renderer sees any of it. |

The model still writes a whole dashboard each turn under a new surface id. The
renderer sees `updateComponents` on one live surface, so it rebuilds in place
and the zone holds one surface item. `GenUIAgent.refresh` is the entry point
for the app's own refreshes.

To move to the official A2UI client: delete `lib/src/queue/`, drop
`_queue`, `_stable` and `_deliver` from `HttpGenUIAgent` (feed the stream
straight to the transport), and keep `GenUIAgent.refresh` as the app's way to
ask again. The zone, the builders and the dashboard do not change.

## Zone: controller and view

The zone is the bounded region of the app the LLM draws into. Ownership splits
across `lib/src/zone/`:

| File | Owns |
| --- | --- |
| `controller/genui_zone_controller.dart` | The `ChangeNotifier` driving one `GenUIAgent`. Subscribes to agent events, accumulates items and tracks `isSending`. |
| `controller/genui_zone_item.dart` | `GenUIZoneItem`, sealed over `UserMessageItem`, `SurfaceItem`, and `ErrorItem`. One entry per row the zone renders. |
| `controller/genui_zone_state.dart` | `GenUIZoneState`, sealed over `GenUIZoneInitial`, `GenUIZoneItemsUpdated`, `GenUIZoneError`. |
| `view/genui_zone.dart` | The public `GenUIZone.chat` widget and the four builder typedefs — surface, user message, error, loading. |
| `view/genui_zone_view.dart` | Listens to the controller and switches over its state. Holds the default builders. |
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
3. The response arrives and the agent forwards a `ConversationSurfaceAdded`
   inside `ConversationEventReceived`. The controller appends a `SurfaceItem`
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
- A bound prop is also written to the data model, through `OptimisticWrites`
  in `builder_helpers.dart`. It remembers the value the path held before the
  first write and restores it on the same revision change
  (`OptimisticWritesHost` for builders that are plain functions). The restore
  runs after the frame, since it writes while the tree is building.

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

`GenUIAgent` is the interface; `HttpGenUIAgent` is the shipped implementation.
It posts to `<baseUri>/generate` and expects a buffered JSON body, not a stream.

A press on a rendered surface (an interaction whose action has `name`,
`surfaceId` and `sourceComponentId`, and no `error`) posts to
`<baseUri>/action` instead, with the same `messages` plus
`action: {name, context}`. The answer, headers and auth are the same. Typed or
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
