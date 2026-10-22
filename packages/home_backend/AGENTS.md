# home_backend

A thin Dart Frog proxy between the Flutter panel and Gemini. It holds no API
key: the caller brings their own, and it runs the model through Genkit with tools over the mock household data,
checks the reply is well-formed A2UI, and returns it. It also owns the demo's
scripted Saturday (the clock, the services, the `/live` socket).

`README.md` is the reference for behavior and configuration. This file is the
map: where code goes, what a change has to touch, and what breaks when it does
not.

## Layout

```
main.dart                    bootstrap: builds the Runtime once
routes/                      Dart Frog routes, one file per path segment
assets/                      dotprompt assets rendered at startup, and
                             photos/<user id>.jpg, the profile photos
data/                        the demo's mock database, one JSON file per source
lib/
├── runtime.dart             the one process-wide Runtime: what visitors share
├── session/                 one demo world per visitor: store, middleware
├── action/                  ActionRequest and ActionCommand, the /action vocabulary
├── gemini_key/              the caller's own Gemini key: middleware and a redacting wrapper
├── cors/                    the origin allowlist and its middleware
├── data/                    MockDatabase, loads data/ once per visitor's world
├── devices/                 the device state machine, the only writer of the home
├── env/                     HOME_* declaration and .env loading (no key lives here)
├── generate/                request model and runGeneration, shared by /generate and /action
├── live/                    the /live socket: hub and session
├── llm/                     Genkit runtime (Gemini only), the Generate function
├── logging/
├── prompt/                  SystemPrompt: the four assets rendered into one message
├── scenario/                the demo's mocked services and the engine
├── tools/                   tools the model may call
├── transcribe/              /transcribe relay and the Gemini Live session
└── validation/              the two checks a reply must pass
test/                        mirrors lib/, plus routes/ and openapi_spec_test
example.env                  every supported variable, documented
openapi.json                 hand-maintained API contract
```

## Routes

| Path | File | Notes |
| --- | --- | --- |
| `/` | `routes/index.dart` | Placeholder greeting. |
| `/health` | `routes/health.dart` | Returns `status: ok`. |
| `/generate` | `routes/generate.dart` | The real work. POST only; anything else is a 405. |
| `/action` | `routes/action.dart` | A component press: applies it to the device state machine, then runs the same generation as `/generate`. POST only. |
| `/users` | `routes/users/index.dart` | Lists users as id, name, role and the base64 photo, for the profile toggle. |
| `/users/<id>` | `routes/users/[id].dart` | One full user profile, or 404. |
| `/clock` | `routes/clock.dart` | The scenario clock. `GET` reads it; `POST {to}` or `{minutes}` moves it and reconciles. |
| `/reset` | `routes/reset.dart` | `POST`: restores every document, the undo stack and the clock to Saturday 7:30 AM. |
| `/live` | `routes/live.dart` | WebSocket. The panel sends the clock as its dial turns; the server pushes the clock, device value updates, inbox items and refresh hints to every connection. |
| `/transcribe` | `routes/transcribe.dart` | WebSocket. Relays audio to Gemini live transcription, opened with the caller's key, and streams the text back. |

`routes/_middleware.dart` applies to every route below it. It provides what the
routes read (`context.read<T>()`, all taken from `runtime`) and wraps the
request in the key check, request logging and CORS. Adding a collaborator means adding a
field to `Runtime` and a `provider` here, not constructing it inside the route.

`/generate`, `/action` and `/transcribe` need the caller's own Gemini key, and
the other paths need nothing. `/transcribe` is the exception to the header.
Browsers can't set `Authorization` on a WebSocket, so the middleware reads the
key from `Sec-WebSocket-Protocol` there, as the entry next to the protocol name.
Keep the route selecting only the protocol name, or the key is echoed back in the
handshake.

## One demo world per visitor

Nothing a visitor does may reach another. The database, the device state
machine, the scenario clock, the `/live` hub and the model's tools all live in a
`DemoSession` (`lib/session/`), and `Runtime` shares only what is read-only: the
system prompt, the validators, the CORS list and the transcriber.

Every request carries `X-Session-Id` (on `/live`, the `Sec-WebSocket-Protocol`
entry next to the protocol name). `provideSession` looks up that visitor's world
in the `SessionStore`, building it on the first request, and provides its
database, machine, world, hub and `Generate` to the route, so routes still read
them with `context.read`. `/health` and `/transcribe` touch no world. A missing
or malformed id is a `400`.

The store keeps memory bounded: a world idle for 30 minutes is dropped, at most
200 exist, and one whose `/live` socket is open is never dropped. When all 200
are connected a new visitor gets a `503`.

Three rules hold it together:

- **No world state outside a `DemoSession`.** Never add a field to `Runtime`, a
  top-level variable or a static that a route writes. It would be shared.
- **Tools belong to a session.** `_newSession` builds a Genkit runtime per world
  and registers tools over that world's database. Do not register tools once at
  boot.
- **The id is not a secret.** It only keeps worlds apart and there is no login,
  so never use it to protect something. The Gemini key stays the only credential
  and is never stored in a session.

## Bootstrap

`main.dart`'s `init` runs once before the server accepts traffic: logging,
`.env` merge, config validation, the mock world, the Genkit runtime, tool
registration and the system prompt. It assigns the result to `runtime`
(`lib/runtime.dart`). Dart Frog builds the server and its routes separately, so
a process-wide value is how `init` hands them what it built; tests bind fakes
through `context.read` instead.

Anything that fails there crashes the process on purpose. A misconfigured server
must never report healthy. Do not catch and continue.

## Prompts

`SystemPrompt.load` renders four dotprompt assets once at boot and joins them
into ONE system message, because Anthropic and Gemini keep a single system field
and silently drop later system entries:

| Asset | Answers |
| --- | --- |
| `assets/a2ui-prompt.prompt` | How to write a reply (required; a missing asset stops the server) |
| `assets/layout.prompt` | The layout: the 12 column grid, the proportion each card is built for (rendered from the catalog's `fit`), and the rules every screen follows |
| the catalog package's `catalog-prompt.prompt`, via `catalogPromptAssetUri` | Which component when |
| `assets/system-prompt.prompt` | The demo's persona and rules |

Each is rendered with `catalogId`, `componentNames`, `a2uiSchema` and
`cardFits`, all derived from the live catalog. Do not copy catalog details into
the prompts by hand.

## Mock data

`data/` is the demo's database, loaded by `MockDatabase.load` once for each visitor's world.
Each file is one source, named after the system that owns it in the real world:

| File | Source | Tool |
| --- | --- | --- |
| `users.json` | the household's profiles | `get_user_data` |
| `google_home.json` | Home APIs: structure, rooms, devices, groups, routines | `get_google_home_data` |
| `calendar.json` | Google Calendar | `get_home_activity` (through the scenario engine) |
| `recipe_timeline.json` | tonight's dinner steps | `get_home_activity` |
| `trips.json` | Google Maps | `get_home_activity` |
| `todos.json` | the household's to-do lists (shopping) | `get_todo_lists` |
| `bakery.json` | the mocked bakery's orders and messages, and its fixed delivery slots and duration | `get_bakery_orders` |
| `inbox.json` | the household inbox: what one person changed that another has to know | `get_inbox`, `mark_inbox_read` |

The calendar is one household calendar. An event has an owner (`userId`) and
may name more people in `assignedTo`; `ActivityFeed` (package
`home_timeline`) serves
it to each of them, so the dinner is Ana's and Marco's and the pickups are
Marco's. A task is assigned to a person, and a tool that acts on it checks
that: `request_bakery_delivery` only works for the person the pickup is
assigned to.

Keep Calendar, Maps and to-do data out of `google_home.json`. Adding a source
means a JSON file, a `MockDatabase` accessor, a tool in `lib/tools/`, an entry
in `buildAgentTools` and a line in the `Dockerfile` only if it lives outside
`data/`.

## Scenario: the services and the engine

The clock and the activity feed live in `packages/home_timeline`; the feed's
moments are declared in its `feed_rules.json`, and `DatabaseFeedSource` lets it
read the mock database.

The demo is one scripted Saturday, from 7:30 AM (the morning, then the day from 4:30 PM, the sunset, the evening), and `lib/scenario/` is what
lets it be replayed. Four rules hold it together:

- **One clock.** `ScenarioClock`, from `packages/home_timeline`, lives on `MockDatabase.clock`,
  starts at the `now` of `data/google_home.json` and only moves through
  `POST /clock` (`ScenarioWorld.moveTo`). Nothing time dependent reads the
  host clock: `get_google_home_data` and `get_home_activity` answer the scenario's time. Times are naive local wall times
  (`2026-10-10T16:30:00`, see `home_timeline`'s `wall_time.dart`).
- **State is a function of time.** `ScenarioEngine.reconcile` writes down what
  is true at the clock's time from the schedules the data holds: the oven
  (stopped, preheating with a rising temperature, ready, roasting, done), the
  car's climate, the bakery order's status, the doorbell and which plan steps
  are done. Nothing fires once, so the clock can go back as well as forward,
  and what a user changed (the oven's preheat time, an order) is an input that
  survives. Call `ScenarioWorld.reconcile` after anything changes a schedule;
  `DeviceStateMachine` does it through `onChanged`.
- **Writes go through a service, never into the maps.** `CalendarService`,
  `OvenService`, `RecipeService`, `BakeryService` and `TripService` are the
  mocked outside systems. `DinnerPlanner.moveGuests` is the one request that
  fans out over several of them: it moves the calendar event, shifts the recipe
  plan and the oven programme, tells the bakery, and the engine replans
  Marco's route. It returns each step as an `effect`. Add a request like it
  the same way: one planner method, each step a service call, listed in the
  result. The model reaches them through `lib/tools/scenario_tools.dart`.
- **A change that reaches past the person who made it goes through the
  inbox.** `DinnerPlanner.moveGuests` writes an `InboxService` item for every
  other person the dinner is assigned to, with what moved, what it means for
  their route and, when one option is clearly best, a `suggestion` naming the
  tool (delivery, for a pickup that would now land after the guests). The
  model reads the inbox when it composes their screen and offers the
  suggestion; a person taps it. The service pushes each item to the `/live`
  hub as it is written.
- **Reset is one call.** `MockDatabase` snapshots its documents when it is
  built and `reset()` restores them with the clock, so any state a new service
  keeps must live in a document (see `bakery.json`), not in a field. The
  restored maps are new objects: read through the getters, never hold a map
  across a reset. `POST /reset` also clears the state machine's undo stack.

The calendar has events around each part of the day the panel's timeline
jumps to (morning 7:30 AM, day 4:30 PM, sunset 5:40 PM, evening 8:40 PM), so
each one has something recent and something next. Marco's later events would
flow into his trip's itinerary, which lists every event of his after he
leaves, so the additions after that point belong to Ana.

`test/scenario/timeline_test.dart` walks the event timeline against the
shipped data, from the first state to the guests at the door. Change the data
or an engine rule and it says what the demo would now do differently.
`test/fixtures/data/` holds the demo's earlier, larger data. The tests of
machinery (commands, validators) load it through
`loadFixtureDatabase()` so they keep covering every trait the machine knows,
whatever the shipped demo contains.

## LLM and tools

`lib/llm/llm.dart` holds the whole model story. `buildGenkitRuntime` registers
the Google plugin with no key, `genkitGenerate` returns the `Generate` function
the routes call, and `Generate` takes the caller's key as its first argument. The
key goes in the options of that one call (`GeminiOptions(apiKey:)`), so the
runtime never holds it. Tests pass a plain function instead.

Gemini is the only provider. Do not add another, and do not add a variable, file
or secret that holds a key: the server being unable to store one is the point.

### Adding a tool

1. Define an `AgentTool` in `lib/tools/` (name, description, input schema, an
   `onCall`).
2. List it in `buildAgentTools` in `lib/tools/agent_tools.dart`.
   `registerAgentTools` handles Genkit registration and needs no codegen.
3. If the model should use it, say when in `assets/system-prompt.prompt`.

Fail deliberately inside a tool. Throw an `Exception` for an expected,
recoverable failure (nothing found, a rejected command) and Genkit hands the
message back to the model. Let an `Error` escape only for a real bug.

## Action loop

`POST /action` applies a press deterministically, then the model composes the
updated surface. The model is never asked to decide what happened.

**The principle: the model only chooses targets, code builds every action.**
The model composing a screen picks ids (a device, a scene, a list and its
items) and closed enums (a command from `HomeActions.commands`). The client
builds each action event from them, so `/action` only ever receives payloads
written by code. Do not make the backend guess what the model meant: no key
aliases, no lenient values, no label or intent interpretation. If a press
cannot be read, that is a client bug and a `400`.

1. `ActionRequest.fromJson` (`lib/action/`) validates the body: the usual
   `messages` plus `action: {name, context}`. A body it cannot read, or a known
   action with a missing or mistyped field, is a `400`
   (`That action couldn't be understood.`). A name outside the vocabulary is a
   `400` (`That action isn't supported.`). Keys and types are exact (a boolean
   is a boolean), and `progressLabel` is ignored.
2. `ActionCommand.applyTo` runs the command on `DeviceStateMachine`
   (`lib/devices/`). Vocabulary, all written by code: `toggle_device`
   {deviceId, on}, `adjust_device` {deviceId, direction `up`|`down`},
   `run_device_action` {deviceId, command (a `DeviceCommand` wire name),
   value?}, `run_scene` {sceneId}, `toggle_todo` {listId, itemId, checked},
   `share_list` {listId} and `undo_change` {}. `ask` is not an `/action` name:
   the client sends an `ask` chip to `/generate` as a typed request, and
   `suggestion_selected` no longer exists. The state machine still resolves an
   id by id, name or alias. `DeviceNotFound` is a `404` and `CommandRejected` a
   `409`, both with a user-safe message of 60 characters or fewer. The client
   shows that message, so write new ones for people.
3. `runGeneration` in `lib/generate/generate_handler.dart` runs the shared
   generation stage, the same function `routes/generate.dart` calls: the system
   prompt, history, one validated retry and the status mapping. For `/action` the last user message is the interaction JSON
   plus a note of what the machine did, so the model reads fresh data. Keep the
   ladder in that one place.

**Targets are not validated while the response is generated.** An id the model
invents fails when it is pressed (`404`), so the prompt tells the model to copy
ids from the read tools (`get_google_home_data`, `get_todo_lists`).
`test/action/plan_samples_test.dart` builds every press for every device, scene
and list in the shipped data, so a new component action goes in there.

The state machine mutates the same maps `MockDatabase.homeFor` returns, so it is
the single source of truth: every read tool sees a change at once. The model's
write tools (`run_device_command`, `run_scene`, `set_todo_item`) call the same
machine, which `_newSession` in `main.dart` builds for each visitor and hands to `buildAgentTools` and the
middleware. Do not write device traits anywhere else.

Adding an action means a case in `ActionCommand.parse`, its entry in
`ActionCommand.names` and the `Action` enum in `openapi.json` (a test compares
them), plus any command the machine needs. The client builds the event, so the
catalog's `HomeActions` and the frontend change with it. A new device means an entry in
`data/google_home.json` with the traits the machine knows (`OnOff`,
`OperationalState`, `LevelControl`, `Thermostat`, `TemperatureControl`,
`WindowCovering`, `OpenClose`, `DoorLock`, `EnergyEvse`, `FanControl`, `Timer`,
`EnergySaver`, `AlarmSettings`, `MediaPlayback`) and
optional `aliases`. A scene is an automation with `"kind": "scene"` and a
`state` of `ready` or `running`.

## The generate step

`runGeneration` in `lib/generate/generate_handler.dart` builds the messages
(system prompt, history, the new prompt), calls `Generate`, and validates the
trimmed reply. If a validator objects, the errors go back to the model as a user
turn for one retry. Two properties are load-bearing:

- **The response is buffered, not streamed.** That is what lets the route return
  a real status code instead of a committed 200 it cannot take back.
- **Statuses are deliberate:** `400` a bad body, `401` no Gemini key, `422` exhausted
  validation, `502` the model call failed. Client-facing messages stay generic;
  the real cause goes to the log.

The validators (`lib/validation/`) are built from `homeCatalog` in
`main.dart`: `A2uiEnvelopeValidator` rejects a reply with no well-formed A2UI
message (after a tool call the model likes to answer in prose), and
`CatalogComponentValidator` rejects components the catalog does not declare, and
`LayoutValidator` rejects a screen that is off the grid: a `Row` whose `weight`s
do not add up to 12, a card at a span its `fit` does not list, a full height
card outside the single `Row` that holds it, a missing or dangling child. Its
errors name the id and the spans the card is built for. A new catalog component
needs no change here: both read the catalog.

## Bring your own key

`lib/gemini_key/` is the whole story. `requireGeminiKey` reads the key from
`Authorization: Bearer` (from `Sec-WebSocket-Protocol` on `/transcribe`) on the
paths that call Gemini and provides it as a `GeminiApiKey`. It does not check
the key: Gemini does, and a wrong one is a `502` from the model call.

Three properties are load-bearing:

- **The key lives in the request.** It is never put on `Runtime`, a field, a
  cache or a file, and no environment variable is read for it.
- **It is never logged.** `GeminiApiKey.toString` hides it, and `runGeneration`
  scrubs it from the error it logs, in case the provider echoed it back.
- **The Google plugin's own fallback must stay unreachable.** With no key it
  reads `GOOGLE_API_KEY` or `GEMINI_API_KEY` from the environment. The
  middleware answers `401` first, so the call always carries the caller's key.

## Voice transcription

`TranscribeRelay` in `lib/transcribe/transcribe_relay.dart` sits between one
client socket and one `TranscriptionSession`. Two properties are load-bearing:

- **It holds early audio in memory.** The Gemini session starts connecting when
  the client does, and frames that arrive before `setupComplete` are listed per
  connection and flushed in order. The class doc and the README's "Voice
  transcription" describe the list. Change both together.
- **Close codes are 1000 or from 3000 to 4999.** `package:web_socket` throws
  on any other code, and the throw lands in an unawaited close where nothing
  catches it. `4400` and `4502` are the relay's own.

`GeminiLiveSession` speaks the Live API. It ends `finish` after 2 seconds
because Gemini answers silence with nothing. Gemini may also drop speech that
starts on the first sample of the stream. The README's "Possible issue" section
has the evidence. Nothing works around it until a real frontend confirms it.

The relay test and the session test run against real sockets on localhost,
with a fake session and a fake Gemini.

## Configuration

`lib/env/home_var.dart` declares every `HOME_*` variable the server
reads. Adding a variable means adding it there and documenting it in
`example.env`, the only place a consumer looks. `.env` is loaded from the
working directory at startup, and the real process environment wins on overlap.

## openapi.json

Hand-maintained, not generated. Update it whenever the wire contract changes: a
new path, a new status code on an existing operation, or a changed field on
`GenerateRequest`, `GenerateResponse` or `ApiError`. `test/openapi_spec_test.dart`
guards it by exercising the real model classes, so it fails when a field is
added to a model and not to the document. Treat that failure as "update the
spec", never as "loosen the test".

## Tests

`test/` mirrors `lib/` directory for directory, plus `test/routes/` for the
route handlers. A new file under `lib/foo/` gets a test at `test/foo/`. Run
`dart test` here, or `mise run test:backend` from the repo root for the CI flags
and coverage floor.
