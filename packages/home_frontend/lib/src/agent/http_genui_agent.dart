import 'dart:async';
import 'dart:convert';
import 'dart:developer' as developer;

import 'package:home_catalog/home_catalog.dart';
import 'package:home_frontend/src/a2ui/a2ui.dart';
import 'package:home_frontend/src/agent/generate_response.dart';
import 'package:home_frontend/src/agent/genui_agent.dart';
import 'package:home_frontend/src/agent/genui_agent_event.dart';
import 'package:home_frontend/src/catalog/genui_catalog.dart';
import 'package:home_frontend/src/queue/stable_surface.dart';
import 'package:home_frontend/src/queue/turn_queue.dart';
import 'package:http/http.dart' as http;

/// Returns the bearer token to attach to outgoing requests: the person's own
/// Gemini API key.
///
/// The agent calls this on every request, so a key that changed is used on the
/// next one. A `null` or empty result is treated as an [AuthError] before the
/// request leaves the client.
typedef GenUITokenProvider = Future<String?> Function();

/// {@template http_gen_u_i__agent}
/// Default [GenUIAgent] that fetches buffered responses from the kit's API
/// server.
///
/// The server is expected to expose `POST <baseUri>/generate` returning a
/// buffered JSON body `{"text": ...}` on `2xx`. Failures arrive
/// as real HTTP status codes (`401` auth, `422` validation, `502` provider)
/// carrying a `{"message": ...}` body rather than as in-band stream events.
///
/// A press on a rendered surface goes to `POST <baseUri>/action` instead, with
/// the same `messages` plus `action: {name, context}`; it answers with the same
/// body, and a rejection's `message` reaches the UI as
/// `UiInteractionCompleted.reason`. The exception is an `ask` press
/// (`HomeActions.ask`), a typed request: it goes to `/generate` with
/// `context.text` as the message content, and its failure `message` is
/// still the `reason`.
/// {@endtemplate}
class HttpGenUIAgent implements GenUIAgent {
  /// {@macro http_gen_u_i__agent}
  ///
  /// Creates an agent that posts to `<baseUri>/generate`.
  ///
  /// `catalog` is the shared component catalog the LLM is allowed to render.
  /// `widgetBuilders` supplies the Flutter renderer for each component name.
  /// The backend owns the system prompt, but the local [SurfaceController]
  /// still needs both to render surfaces.
  ///
  /// `baseUri` defaults to `http://localhost:8080`, matching the Dart Frog
  /// dev server. Pass a custom [client] in tests.
  ///
  /// `sessionId`, when given, is sent as `X-Session-Id` so the backend answers
  /// from this visitor's own demo world.
  ///
  /// `stableSurfaceId`, when given, keeps every reply on that one surface and
  /// turns each answer into an update of it, in the order the turns were asked
  /// (see `TurnQueue` and `StableSurface`). Without it every reply is handed to
  /// the renderer as the model wrote it, and a new surface adds a row to the
  /// zone.
  ///
  /// `tokenProvider` is invoked on every request and its result is sent as
  /// `Authorization: Bearer <token>`. A `null` or empty result throws
  /// [AuthError] before the request leaves the client.
  HttpGenUIAgent({
    required this._catalog,
    required this._widgetBuilders,
    required this._tokenProvider,
    this._sessionId,
    String? stableSurfaceId,
    Uri? baseUri,
    http.Client? client,
  }) : _baseUri = baseUri ?? Uri.parse('http://localhost:8080'),
       _client = client ?? http.Client(),
       _ownsClient = client == null,
       _stable = stableSurfaceId == null
           ? null
           : StableSurface(stableSurfaceId);

  final GenUiComponentCatalog _catalog;
  final Map<String, CatalogWidgetBuilder> _widgetBuilders;
  final Uri _baseUri;
  final http.Client _client;
  final bool _ownsClient;
  final GenUITokenProvider _tokenProvider;
  final String? _sessionId;
  final StableSurface? _stable;
  final _queue = TurnQueue();

  /// The latest data model update that came for each path, outside a reply.
  ///
  /// A reply carries the values its devices had when it was written. One may
  /// have changed since, and the update that said so may have come first, so
  /// these are put back once a reply lands.
  final _latest = <String, A2uiMessage>{};

  late final SurfaceController _controller;
  late final A2uiTransportAdapter _transport;
  late final Conversation _conversation;
  final _eventsController = StreamController<GenUIAgentEvent>.broadcast();
  final List<ChatMessage> _history = [];
  StreamSubscription<ConversationEvent>? _conversationEventsSub;
  bool _started = false;

  @override
  SurfaceController get controller => _controller;

  @override
  Stream<GenUIAgentEvent> get events => _eventsController.stream;

  @override
  List<ChatMessage> get history => List.unmodifiable(_history);

  @override
  Future<void> start() async {
    if (_started) {
      throw StateError('GenUIAgent.start can only be called once.');
    }

    final catalog = buildCatalog(
      catalog: _catalog,
      widgetBuilders: _widgetBuilders,
    );
    _controller = SurfaceController(catalogs: [catalog]);
    _transport = A2uiTransportAdapter(onSend: _onSend);
    _conversation = Conversation(
      controller: _controller,
      transport: _transport,
    );
    _conversationEventsSub = _conversation.events.listen(
      (event) => _eventsController.add(ConversationEventReceived(event)),
    );
    _started = true;
  }

  @override
  Future<void> sendMessage(String text) async {
    if (!_started) {
      throw StateError('GenUIAgent.sendMessage requires start() first.');
    }
    _eventsController.add(UserMessageAdded(text));
    // Go through the transport (not `_conversation.sendRequest`) so errors
    // surface to the caller instead of being absorbed into a
    // `ConversationError` event. `_transport.flush()` is intentionally not
    // called here because it would close the underlying input stream and
    // break subsequent turns.
    await _transport.sendRequest(ChatMessage.user(text));
  }

  Future<void> _onSend(ChatMessage message) {
    // The renderer reports a component it found invalid as if it were a user
    // turn. Answered, it is one more model run with no dashboard to go on,
    // whose reply (an apology, a lone card) would replace the whole screen a
    // moment after the real one. A stable surface keeps what it shows.
    final report = _stable == null ? null : _rendererReport(message);
    if (report != null) {
      developer.log(report, name: 'home_frontend', level: 900);
      return Future.value();
    }
    return _queue.interaction(() => _runTurn(message));
  }

  // The message of a renderer error report in [message], or null when it is
  // anything else.
  static String? _rendererReport(ChatMessage message) {
    for (final part in message.parts) {
      final json = interactionJson(part);
      if (json == null) continue;
      try {
        final decoded = jsonDecode(json);
        if (decoded is Map<String, Object?> &&
            decoded['error'] is Map<String, Object?>) {
          final error = decoded['error']! as Map<String, Object?>;
          return 'Dropped a renderer error report: ${error['message']}';
        }
      } on FormatException {
        // Not JSON: not a report.
      }
    }
    return null;
  }

  @override
  Future<void> refresh(String text) async {
    if (!_started) {
      throw StateError('GenUIAgent.refresh requires start() first.');
    }
    await _queue.refresh((isCurrent) async {
      // Asked from scratch: the history of the turns before would only repeat
      // what the data already says.
      final reply = await _fetch(const [], text, null);
      if (!isCurrent()) return;
      _deliver(reply);
      _history
        ..clear()
        ..add(ChatMessage.user(text))
        ..add(ChatMessage.model(reply));
    });
  }

  @override
  void apply(Map<String, Object?> message) {
    if (!_started) return;
    final A2uiMessage parsed;
    try {
      parsed = A2uiMessage.fromJson(_stable?.address(message) ?? message);
    } on Object catch (error) {
      developer.log(
        'Ignored a message the renderer cannot read: $error',
        name: 'home_frontend',
        level: 900,
      );
      return;
    }
    if (parsed case UpdateDataModel(:final surfaceId, :final path)) {
      _latest['$surfaceId$path'] = parsed;
    }
    _transport.addMessage(parsed);
  }

  // Hands a reply to the renderer: as the model wrote it, or as updates of the
  // one stable surface. A reply the stable surface rejects reaches no one.
  void _deliver(String reply) {
    final stable = _stable;
    if (stable == null) return _transport.addChunk(reply);
    // Parsed in full first, so a message the renderer refuses reaches no one.
    stable
        .admit(reply)
        .map(A2uiMessage.fromJson)
        .toList()
        .forEach(_transport.addMessage);
    // What the reply says of a value is as old as the reply: the newest word on
    // each is the last update that came for it.
    _latest.values.forEach(_transport.addMessage);
  }

  Future<void> _runTurn(ChatMessage message) async {
    final content = _wireContent(message);
    final priorHistory = List<ChatMessage>.from(_history);
    _history.add(message);

    String? interactionLabel;
    String? failureReason;
    var modelMessageAppended = false;
    try {
      // A surface component bypasses sendMessage, so its turn is reported here
      // instead. Inside the try so the finally clause rolls history back if
      // resolving the label throws.
      final interaction = _interactionOf(message);
      interactionLabel = _userActionLabel(interaction);
      final press = _surfacePress(interaction);
      if (interactionLabel != null) {
        _eventsController.add(UiInteractionAdded(interactionLabel));
      }

      final replyText = await _fetch(priorHistory, content, press);
      _deliver(replyText);
      _history.add(ChatMessage.model(replyText));
      modelMessageAppended = true;
    } on _BackendRejection catch (e) {
      failureReason = e.reason;
      rethrow;
    } finally {
      // Drop the user message if no model reply was appended. The server
      // rejects requests whose history ends on two consecutive user
      // messages, so leaving a dangling user entry would break the next
      // turn.
      if (!modelMessageAppended) {
        _history.removeLast();
        _eventsController.add(const UserTurnRolledBack());
      }
      // Every exit path, including the empty reply above, which neither throws
      // nor produces a surface.
      if (interactionLabel != null) {
        _eventsController.add(
          UiInteractionCompleted(
            succeeded: modelMessageAppended,
            reason: modelMessageAppended ? null : failureReason,
          ),
        );
      }
    }
  }

  // Asks the backend for a reply and returns its text. Throws on every failure,
  // before anything is kept: the caller owns the history.
  Future<String> _fetch(
    List<ChatMessage> priorHistory,
    String content,
    ({String name, Map<String, Object?> context})? press,
  ) async {
    // Resolve the auth header inside the try block so a provider failure
    // rolls back the user message via the existing finally clause.
    final String token;
    try {
      final raw = await _tokenProvider();
      if (raw == null || raw.isEmpty) {
        throw AuthError('token provider returned no token');
      }
      token = raw;
    } on AuthError {
      rethrow;
    } on Object catch (e) {
      throw AuthError('token provider failed: $e');
    }

    // A press on a rendered surface is applied by the backend as a command
    // before the surface is composed, so it has its own route. Typed or
    // spoken text, `ask` presses and validation reports go to `/generate`.
    // An `ask` press is the exception: it is a typed request the model
    // handles with its tools, so it goes to `/generate` as plain text.
    final isCommand = press != null && press.name != HomeActions.ask;
    final path = isCommand ? '/action' : '/generate';
    final request = http.Request('POST', _baseUri.resolve(path))
      ..headers['Content-Type'] = 'application/json'
      ..headers['Accept'] = 'application/json'
      ..headers['Authorization'] = 'Bearer $token'
      ..body = jsonEncode({
        'messages': [
          for (final m in priorHistory)
            {'role': _wireRole(m.role), 'content': _wireContent(m)},
          {'role': 'user', 'content': content},
        ],
        if (isCommand) 'action': {'name': press.name, 'context': press.context},
      });
    if (_sessionId case final sessionId?) {
      request.headers['X-Session-Id'] = sessionId;
    }

    final response = await _client.send(request);
    final body = await response.stream.bytesToString();
    if (response.statusCode == 401) {
      throw AuthError('server rejected token: ${_errorMessage(body)}');
    }
    if (response.statusCode < 200 || response.statusCode >= 300) {
      final message =
          '$path failed with status ${response.statusCode}: '
          '${_errorMessage(body)}';
      // Only a press carries a backend reason the UI may show to the user.
      final reason = press == null ? null : _backendMessage(body);
      throw _BackendRejection('POST $message', reason);
    }

    // A 2xx response is expected to carry a JSON object matching the
    // `/generate` contract. GenerateResponse decodes and type-checks it; a
    // proxy or misbehaving server returning a non-JSON body, a JSON array, or
    // a mistyped field surfaces as an HttpException like the non-2xx path,
    // rather than escaping as a raw FormatException/TypeError.
    final GenerateResponse generated;
    try {
      generated = GenerateResponse.fromBody(body);
    } on FormatException catch (e) {
      throw HttpException(
        'POST $path returned a malformed success body: ${e.message}',
      );
    }

    final replyText = generated.text;

    // An empty reply is treated as a failed turn: the server rejects history
    // entries with empty content, so persisting `ChatMessage.model('')` would
    // break the next request. Throwing leaves `modelMessageAppended` false,
    // so the finally block rolls the user message back too, and it reaches
    // the zone as the same failure notice every other error path produces
    // rather than a turn that silently went nowhere.
    if (replyText.isEmpty) {
      throw EmptyResponseException('the model returned an empty reply');
    }
    return replyText;
  }

  // The decoded `{action: {...}}` JSON of the first interaction part, or null.
  // `UserActionEvent` serializes flat: name, surfaceId, sourceComponentId,
  // timestamp and a `context` map sit side by side inside `action`.
  static Map<String, Object?>? _interactionOf(ChatMessage message) {
    for (final part in message.parts) {
      final interaction = interactionJson(part);
      if (interaction == null) continue;
      final Object? decoded;
      try {
        decoded = jsonDecode(interaction);
      } on FormatException {
        continue;
      }
      if (decoded is! Map<String, Object?>) continue;
      final action = decoded['action'];
      if (action is! Map<String, Object?>) continue;
      if (action['name'] is! String) continue;
      return action;
    }
    return null;
  }

  // A press on a rendered surface: it names the surface and the component.
  // Validation reports carry an `error` instead of a name and never reach here.
  static ({String name, Map<String, Object?> context})? _surfacePress(
    Map<String, Object?>? action,
  ) {
    if (action == null || action.containsKey('error')) return null;
    if (action['surfaceId'] is! String) return null;
    if (action['sourceComponentId'] is! String) return null;
    final context = action['context'];
    return (
      name: action['name']! as String,
      context: context is Map<String, Object?> ? context : {},
    );
  }

  // Label for a message carrying a user action, null otherwise. Validation
  // reports share this path but carry an `error` instead of a named `action`.
  // The agent-authored `context.progressLabel` wins; the visible text of the
  // component and then the action name are fallbacks.
  String? _userActionLabel(Map<String, Object?>? action) {
    if (action == null) return null;
    final name = action['name']! as String;
    final context = action['context'];
    if (context is Map<String, Object?>) {
      final progress = context['progressLabel'];
      if (progress is String && progress.trim().isNotEmpty) {
        return progress.trim();
      }
    }

    // `Surface` stamps both keys onto a press from a rendered surface.
    final surfaceId = action['surfaceId'];
    final componentId = action['sourceComponentId'];
    if (surfaceId is! String || componentId is! String) return name;
    return _componentLabel(surfaceId, componentId) ?? name;
  }

  // First literal text at or under the component that raised the action. Null
  // when the surface is gone or the text is a data binding, not a literal.
  String? _componentLabel(String surfaceId, String componentId) {
    final components = _controller.registry.getSurface(surfaceId)?.components;
    if (components == null) return null;

    final pending = <String>[componentId];
    final visited = <String>{};
    while (pending.isNotEmpty) {
      final id = pending.removeAt(0);
      if (!visited.add(id)) continue;
      final properties = components[id]?.properties;
      if (properties == null) continue;
      final text = properties['text'];
      if (text is String && text.trim().isNotEmpty) return text.trim();
      pending.addAll(_childIds(properties));
    }
    return null;
  }

  // A component's child ids. The template shape `children` also allows is
  // skipped: a templated row binds its text, so there is no literal to find.
  static Iterable<String> _childIds(Map<String, Object?> properties) {
    final ids = <String>[];
    for (final key in const ['child', 'children']) {
      switch (properties[key]) {
        case final String id:
          ids.add(id);
        case final List<Object?> list:
          ids.addAll(list.whereType<String>());
      }
    }
    return ids;
  }

  // Failure responses carry a JSON `{"message": ...}` body. Surface that
  // message when present, falling back to the raw body for non-JSON responses.
  static String _errorMessage(String body) {
    try {
      final json = jsonDecode(body);
      if (json is Map<String, dynamic> && json['message'] is String) {
        return json['message'] as String;
      }
    } on FormatException {
      // Not JSON; fall through to the raw body.
    }
    return body;
  }

  // The `message` of a `{"message": ...}` failure body, or null when the body
  // is not that shape or the message is blank.
  static String? _backendMessage(String body) {
    try {
      final json = jsonDecode(body);
      if (json is Map<String, dynamic>) {
        final message = json['message'];
        if (message is String && message.trim().isNotEmpty) {
          return message.trim();
        }
      }
    } on FormatException {
      // Not JSON: there is no reason to show.
    }
    return null;
  }

  // Serializes a message to the wire `content` string. TextParts contribute
  // their text; UI interaction parts contribute their interaction JSON. A
  // server-action button press or a validation report arrives as a
  // ChatMessage whose only payload is a UiInteractionPart (its text is empty),
  // so serializing from ChatMessage.text alone would send empty content that
  // the server rejects with 422.
  static String _wireContent(ChatMessage message) {
    final segments = <String>[];
    for (final part in message.parts) {
      if (part is TextPart) {
        segments.add(part.text);
      } else if (interactionJson(part) case final interaction?) {
        segments.add(_askText(interaction) ?? interaction);
      }
    }
    return segments.join('\n');
  }

  // The text of an `ask` press, which goes on the wire as if it were typed, or
  // null for any other interaction.
  static String? _askText(String interaction) {
    final Object? decoded;
    try {
      decoded = jsonDecode(interaction);
    } on FormatException {
      return null;
    }
    if (decoded is! Map<String, Object?>) return null;
    final action = decoded['action'];
    final press = _surfacePress(action is Map<String, Object?> ? action : null);
    if (press == null || press.name != HomeActions.ask) return null;
    final text = press.context['text'];
    return text is String && text.trim().isNotEmpty ? text.trim() : null;
  }

  static String _wireRole(ChatMessageRole role) => switch (role) {
    ChatMessageRole.user => 'user',
    ChatMessageRole.model => 'assistant',
    ChatMessageRole.system => 'user',
  };

  @override
  void dispose() {
    unawaited(_conversationEventsSub?.cancel());
    unawaited(_eventsController.close());
    if (_ownsClient) _client.close();
    if (!_started) return;
    _conversation.dispose();
    _transport.dispose();
    _controller.dispose();
  }
}

/// {@template http_exception}
/// Raised when a request fails at the transport level.
///
/// Covers a non-2xx status and a 2xx whose body does not match the `/generate`
/// contract. A well-formed response carrying no text is an
/// [EmptyResponseException] instead.
/// {@endtemplate}
class HttpException implements Exception {
  /// {@macro http_exception}
  HttpException(this.message);

  /// The human-readable description of the failure.
  final String message;

  @override
  String toString() => 'HttpException: $message';
}

// A non-2xx answer to a press, carrying the backend's own user-safe reason.
/// A rejection the backend sent, with its `reason` when it gave one.
class _BackendRejection extends HttpException {
  _BackendRejection(super.message, this.reason);

  final String? reason;
}

/// {@template auth_error}
/// Raised when a request could not be authenticated.
///
/// Thrown when the [GenUITokenProvider] itself fails and when the server
/// returns `401 Unauthorized`. Subclass of [HttpException] so existing
/// `catch on HttpException` continues to handle auth failures. UI code
/// that needs to distinguish auth failures (for example to ask for
/// the Gemini key again) catches `on AuthError` instead.
/// {@endtemplate}
class AuthError extends HttpException {
  /// {@macro auth_error}
  AuthError(super.message);

  @override
  String toString() => 'AuthError: $message';
}

/// {@template empty_response_exception}
/// Raised when the server answers on-contract but the reply carries no text.
///
/// Not an [HttpException]: the request succeeded and the body was well formed,
/// so nothing failed at the transport level. The turn is still treated as a
/// failure, because the server rejects history entries with empty content and
/// persisting one would break the next request.
/// {@endtemplate}
class EmptyResponseException implements Exception {
  /// {@macro empty_response_exception}
  EmptyResponseException(this.message);

  /// The human-readable description of the failure.
  final String message;

  @override
  String toString() => 'EmptyResponseException: $message';
}
