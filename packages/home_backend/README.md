# home_backend

A thin Dart Frog proxy between the Flutter panel and Gemini. It is bring your
own key: it holds no API key, and runs the model with the caller's own through [Genkit](https://genkit.dev) with a handful of
tools over the mock household data, checks that the reply is well-formed A2UI,
and returns it. Everything else (rendering, state, layout) lives in the app and
the catalog package. `AGENTS.md` maps the code.

## OpenAPI document

This package ships its OpenAPI 3.1 document as a static file at
[`openapi.json`](openapi.json) in the package root. It describes the server's
HTTP contract — the `POST /generate`, `POST /action` and `GET /health` operations, their request
and response bodies, and the Gemini key security scheme — so a client or an
alternative server can be generated from it. The document is not served over
HTTP; read it straight from the package, no running server required.

Use it with any OpenAPI 3.1-compatible generator. For example,
[OpenAPI Generator](https://openapi-generator.tech/) can create a TypeScript
client or a server stub in another language:

```bash
openapi-generator-cli generate -i openapi.json -g typescript-fetch -o client
openapi-generator-cli generate -i openapi.json -g nodejs-express-server -o server
```

Run `openapi-generator-cli list` to see the client and server targets supported
by your installed generator version.

The document is hand-maintained. `test/openapi_spec_test.dart` guards it against
drift from the contract it describes.

## Your Gemini key

The server holds no API key and has nowhere to keep one. Each person pastes
their own [Gemini API key](https://aistudio.google.com/apikey) into the app, and
the app sends it with every request that calls Gemini. The server uses it for
that request and it is gone when the response is sent: it is not read from the
environment, written to disk, cached between requests or logged. Gemini is the
only provider.

Clients send the key in the `Authorization` header:

```
Authorization: Bearer <your gemini api key>
```

Only `POST /generate`, `POST /action` and `GET /transcribe` call Gemini, so only
they need it. A request to one of them with no key gets `401 Unauthorized` and
`{"message": "Missing Gemini API key"}`. The key is not checked here: Gemini
rejects a wrong one when the model is called, and that comes back as a `502`.

Every other path (`/health`, `/users`, `/clock`, `/reset`, `/live`) answers
without a key. They only serve the visitor's own mock household.

`/transcribe` is a WebSocket, and browsers can't set an `Authorization` header
on one. Its client offers the key as a subprotocol instead. See
[Voice transcription](#voice-transcription).

## Configuration

| Variable | Required | Description |
|---|---|---|
| `HOME_LLM_MODEL` | no | Overrides the default Gemini model, `gemini-3.1-flash-lite`. |
| `HOME_CORS_ALLOWED_ORIGINS` | no | Comma separated browser origins allowed to call the API. |

There is no variable for a key, and a key placed in `.env` or the environment is
not read.

The system prompt is four dotprompt assets rendered once at boot and sent as
one system message: `assets/a2ui-prompt.prompt` (how to emit A2UI),
`assets/layout.prompt` (the layout: the 12 column panel grid and the proportion each card is built for),
`catalog-prompt.prompt` from the catalog package (which component when),
and `assets/system-prompt.prompt` (the demo's persona and rules).

The server reads `.env` from the working directory and the process
environment; the process environment wins. Copy `example.env` to `.env`:

```bash
cp example.env .env
dart_frog dev
```

## One demo world per visitor

Each visitor gets a demo world of their own: their own household data, device
state, scenario clock and `/live` feed. Moving the clock, turning the oven on or
resetting only affects the visitor who did it.

The client makes up a random id once, 16 to 64 letters, digits, `_` or `-`, and
sends it as `X-Session-Id` on every request except `/health` and `/transcribe`.
`/live` is a WebSocket, so there the id is the second subprotocol, next to
`genui.live.v1`. There is no login: the id only keeps one visitor's world apart
from another's.

```
X-Session-Id: 3k1xv0Q8c2mJ9aTn7LwYp5RbZdE4HsUo
```

A world is built on the visitor's first request, in the demo's first state. It is
dropped after 30 minutes without a request, unless a `/live` socket is still
open, and at most 200 exist at once. A request with no valid id gets `400`, and a
new visitor when all 200 are in use gets `503`. State lives in server memory, so
a restart also starts everyone over.

### Example request

```bash
curl -X POST http://localhost:8080/generate \
  -H 'Authorization: Bearer <your gemini api key>' \
  -H 'X-Session-Id: 3k1xv0Q8c2mJ9aTn7LwYp5RbZdE4HsUo' \
  -H 'Content-Type: application/json' \
  -d '{"messages": [{"role": "user", "content": "What is on for tonight?"}]}'
```

The response is buffered and validated before it is returned, so `/generate`
reports a real HTTP status code. On success it returns `200` with the
generated `text`:

```json
{"text": "```json\n{\"version\": \"v0.9\", ...}\n```"}
```

A reply must carry a well-formed A2UI message that only names catalog
components and sit on the panel grid (`A2uiEnvelopeValidator`,
`CatalogComponentValidator`, `LayoutValidator`). When it does
not, the model gets the errors back and one more try. Failures return a real
status code with a generic `{"message": ...}` body so internal details never
leak:

| Status | Meaning |
|---|---|
| `400` | The request body is malformed or violates the `messages` contract, or the `X-Session-Id` is missing or invalid. |
| `401` | The Gemini key is missing. |
| `503` | Every demo slot is in use. |
| `422` | The reply failed validation, even after the retry. |
| `502` | The model call failed, for example because Gemini rejected the key. |

`messages` is a non-empty list ordered from oldest to newest. Each entry has a
`role` of `user` or `assistant` and a non-empty `content` string. The last
entry must be a user message and is the prompt for this turn.

## Component presses: `POST /action`

`POST /action` is the other way to start a turn. The client sends it when the
user presses a component (a switch, a stepper, a chip, a scene's Start button, a
checkbox) instead of typing or speaking. The backend applies the press to the
device state machine in `lib/devices/`, with no model in the loop, and only then
runs the same generation as `/generate` so the model composes the updated
surface from the fresh data. The response is the same `{text}` body and
the A2UI protocol is unchanged.

```bash
curl -X POST http://localhost:8080/action \
  -H 'Content-Type: application/json' \
  -d '{
    "messages": [
      {"role": "user", "content": "{\"action\":{\"name\":\"toggle_device\"}}"}
    ],
    "action": {
      "name": "toggle_device",
      "context": {"progressLabel": "Turn off oven", "deviceId": "oven", "on": false}
    }
  }'
```

`messages` has the shape `/generate` takes; its last entry is the interaction
JSON the client built. Code writes every action: the model only chooses targets
(device, scene and list ids, a command from a closed list) and the client builds
the event from them, so the keys and types below are exact. There is no key
aliasing, no lenient value (`"on"` for true) and no label reading. `progressLabel`
is for the client's snackbar and is ignored here.

| Action name | Context | Effect |
|---|---|---|
| `toggle_device` | `deviceId`, `on` (bool) | Run, light, arm, open or lock the device (on), or the opposite. |
| `adjust_device` | `deviceId`, `direction` (`up` or `down`) | One step on the thermostat, oven, light, speaker volume or blinds. |
| `run_device_action` | `deviceId`, `command`, optional `value` (number) | A named command, one of `on`, `off`, `start`, `stop`, `open`, `close`, `lock`, `unlock`, `add_time`, `set_level`, `set_temperature`, `up`, `down`. |
| `run_scene` | `sceneId` | Starts the scene (`dinner_party`). |
| `toggle_todo` | `listId`, `itemId`, `checked` (bool) | Checks or clears a list item. |
| `share_list` | `listId` | Shares the list with its target (Marco, for the shopping list). |
| `undo_change` | none | Reverts the last command that changed something. |

`ask` is not an action name. The client sends an `ask` chip to `/generate` as a
typed request, so the model handles it with its tools. `suggestion_selected` no
longer exists.

The ids the model chooses are not checked before the response is returned. A press on an id that does not exist is refused when it happens (`404`), and the
prompt tells the model to copy ids from the tools.

Failures return `{"message": ...}` with a short reason written for the user:

| Status | When | Example message |
|---|---|---|
| `400` | Malformed body or a missing or mistyped field | `That action couldn't be understood.` |
| `400` | An action name outside the vocabulary | `That action isn't supported.` |
| `404` | Unknown device, scene, list or list item | `Couldn't find the oven.` |
| `409` | The device is offline or cannot do the command | `The oven can't do that right now.` |
| `401`, `422`, `502` | As for `/generate` | |

The model has the same power through its write tools, `run_device_command`,
`run_scene` and `set_todo_item`, so a spoken or typed request changes the same
state a press does.

## Live connection

`GET /live` is a WebSocket that connects the panel to the scenario. The panel
used to post the clock to `/clock` once a minute while its time dial turned and
then ask again for everything that followed. Over the socket it sends the clock
as it turns, and the server pushes back what changes, to every connection.

Connect with the protocol name. It needs no key:

```js
const socket = new WebSocket(`${backendUrl}/live`, ['genui.live.v1']);
```

The client sends one frame, as text:

| Frame | Effect |
| --- | --- |
| `{"type": "clock", "to": "2026-10-10T16:45:00"}` | Moves the scenario clock, held within the scenario, and reconciles. |

The server sends, to every connection:

| Frame | When |
| --- | --- |
| `{"type": "clock", "now", "start", "end", "timeZone"}` | On connect, and after the clock moves or the demo resets. |
| `{"type": "a2ui", "message"}` | After a device's card values change: an `updateDataModel` for the dashboard on screen (see "Live device values" below). |
| `{"type": "inbox", "userId", "unread", "item"}` | When a notification lands in someone's inbox. |
| `{"type": "changed", "users", "reason"}` | When household data changed for those users outside the clock, so their screens should refresh. |
| `{"type": "error", "message"}` | For a frame it cannot read. The connection stays open. |

`POST /clock` and `POST /reset` still work and publish the same frames.

## How a screen is shaped

The model chooses the cards and ranks them. Code lays them out, because adding
up columns is what the model does worst. Around each visitor's `Generate`,
`composingScreens` (`lib/devices/device_filler.dart`) runs a `LayoutComposer`
(`lib/validation/layout_composer.dart`) on every reply:

- it reads the cards in the order the model wrote them and packs them onto the
  12 column grid from each card's `fit`, in the shapes of `assets/layout.prompt`;
- it never gives up one of the model's cards for another: when no arrangement
  holds them all, the last ranked is left out first;
- when the cards leave a row short, it adds `DeviceCard`s for devices the screen
  does not show (`DeviceFiller`), as few as the grid needs, the devices the
  person uses first. The model is told not to pad, because the panel does it.

`LayoutValidator` still checks the result, and mends a reply that reaches it
off the grid the same way, so a layout error never costs a retry.

## Live device values

A dashboard is updated in place, as an A2UI agent updates a surface, instead
of being generated again. The model still writes each `DeviceCard` with literal
values. After every reply, `bindDevices` (`lib/devices/device_binder.dart`,
wrapped around each visitor's `Generate` in `main.dart`) replaces the three
values that follow from the device alone (`isActive`, `status`, `value`) with a
binding to `/devices/<id>/<value>`, and adds the `updateDataModel` that seeds
them. The values are `DeviceReadings` (`lib/devices/device_readings.dart`), the
one place that says what a device's card shows, so the first screen and every
update are worded alike.

When a command or the clock changes a device, `ScenarioWorld` sends only the
devices that moved as `a2ui` frames. Each carries
`{version, updateDataModel: {surfaceId: "dashboard", path: "/devices/<id>",
value}}`. The app applies it to the surface it has open, and only the cards
bound to that path rebuild.

The devices with readings are the ones in `DeviceReadings.deviceIds`: the
oven, the fridge, the table lights, the speaker, the thermostat and the front
door. For any other device the card keeps what the model wrote. The protocol
version is `a2uiVersion` and the surface id is `dashboardSurfaceId`, both in
`home_catalog`, so moving to a newer protocol starts with that package.

## Voice transcription

`GET /transcribe` is a WebSocket that turns speech into text with Gemini's live
transcription model, `gemini-3.5-transcribe-live`. It's built for short spoken
commands of a few seconds. The backend holds the Gemini connection for each
session, opened with the caller's own key.

The backend reaches the model through the [Gemini Live
API](https://ai.google.dev/api/live) of the Gemini Developer API, at the
`v1beta` `BidiGenerateContent` WebSocket on `generativelanguage.googleapis.com`.
The key travels in the `x-goog-api-key` header, and the session setup turns on
input audio transcription. Google's [live transcription
guide](https://ai.google.dev/gemini-api/docs/live-api/live-transcribe) covers the
model.

It uses the key the caller connects with, the same one `/generate` uses. The
server keeps it only for the life of the session.

### Connecting

Browsers can't set an `Authorization` header on a WebSocket. Offer two
subprotocols instead: the protocol name and your Gemini API key.

```js
const socket = new WebSocket(`${backendUrl}/transcribe`, [
  'genui.transcribe.v1',
  geminiApiKey,
]);
```

The server selects `genui.transcribe.v1` and never echoes the key back. The
key travels inside TLS and stays out of request logs. A missing key gets a
`401` before the upgrade. A browser origin outside
`HOME_CORS_ALLOWED_ORIGINS` gets a `403`. A request that isn't a WebSocket
upgrade gets a `404`.

### Messages

The client sends:

- Binary frames of raw 16 kHz mono 16-bit little-endian PCM. Start as soon as
  the socket opens. Frames of about 100 ms work well.
- `{"type": "stop"}` as a text frame when the user stops talking.

The server sends:

- `{"type": "interim", "text": "..."}` while the user is talking. Each one
  replaces the one before.
- `{"type": "final", "text": "..."}` when an utterance is finished.
- `{"type": "error", "message": "..."}` with a generic message, right before it
  closes on a failure.

After `stop` the server sends any remaining final text and closes. A close with
no `final` means nothing was heard.

| Close code | Meaning |
|---|---|
| `1000` | Done. Sent after `stop`, or when Gemini ends the session. |
| `4400` | The client sent a message the protocol doesn't define. |
| `4502` | Gemini failed, or wasn't ready within 5 seconds. |

The real cause of a `4502` goes to the log.

### Audio that arrives before Gemini is ready

The backend opens the Gemini session as soon as the client connects. Gemini
needs a setup round trip of about 300 ms before it accepts audio, and the user
may already be talking. The backend holds that audio itself, so every client
gets the same behavior without code of its own:

- Each connection keeps a list of audio frames in memory. It starts empty.
- Until Gemini's `setupComplete` arrives, every binary frame from the client is
  appended to the list.
- When `setupComplete` arrives, the backend sends the listed frames to Gemini in
  order, empties the list, and forwards later frames straight through.
- A `stop` that arrives first is handled after the listed frames, so no audio is
  lost.
- If setup fails or takes longer than 5 seconds, the client gets an `error` and
  a `4502`, and the list is dropped.

The list belongs to one connection and never outlives it. Audio arrives at 32
KB per second, so at real-time rate the 5-second limit keeps it under about 160
KB. `TranscribeRelay` in `lib/transcribe/transcribe_relay.dart` owns the list.

Gemini sends nothing back for audio with no speech in it, so after `stop` the
session in `lib/transcribe/gemini_live_session.dart` waits at most 2 seconds for
a last transcript.

### Possible issue: speech at the very start of the audio

In local tests, Gemini dropped the first words of a clip whose speech starts on
its first sample. A `say` clip of "Dinner's an hour later, delay the oven
preheat" came back as "Delay the oven preheat." in four runs out of four, twice
sent straight to Gemini and twice through the backend. Gemini's activity
detection reported speech starting at 1.48 seconds, after the pause at the
comma. The same sentence with silence in front came back whole every time, with
as little as 100 ms.

Nothing in the backend works around this yet. Microphone audio usually starts
with some silence, and a recording of a real voice came back whole. Check it
with the app's microphone button before deciding whether the backend should pad
the audio.

## Tools

The model reads and changes the household through the tools in `lib/tools/`.
`buildAgentTools` lists them and `registerAgentTools` registers them on the
Genkit runtime at boot.

| Tool | Reads or writes |
|---|---|
| `get_user_data`, `get_google_home_data`, `get_todo_lists`, `get_bakery_orders` | The mock data in `data/`. |
| `get_home_activity` | What just happened and what is next, as of the scenario clock. |
| `get_inbox`, `mark_inbox_read` | What other people changed that concerns one person. |
| `run_device_command`, `run_scene`, `set_todo_item` | The device state machine, the one writer `/action` also uses. |
| `schedule_oven`, `reschedule_guest_arrival`, `request_bakery_delivery` | The scenario services. |

A tool is an `AgentTool`: a name, a description, an input JSON Schema map and a
function. Throw an `Exception` for an expected failure (nothing found, a
rejected command): Genkit hands its message back to the model. An `Error` is a
bug and fails the request.

```dart
AgentTool bakeryOrdersTool(MockDatabase database) {
  return AgentTool(
    name: 'get_bakery_orders',
    description: "Returns a user's bakery orders.",
    inputSchema: userIdInputSchema,
    onCall: (args) => database.bakeryFor(requiredUserId(args)),
  );
}
```

## Continuous Integration

`.github/workflows/backend.yaml` runs on every pull request:

- `dart format --set-exit-if-changed .`
- `dart analyze --fatal-infos --fatal-warnings .`
- `very_good dart test --no-optimization --coverage`

`--no-optimization` is required because the test optimizer bundles tests into
a single suite, which breaks coverage collection for Dart Frog's `routes/`
layout.

