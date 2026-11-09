import 'dart:async';
import 'dart:convert';
import 'dart:developer' as developer;

import 'package:home_catalog/home_catalog.dart';
import 'package:home_frontend/src/a2ui/a2ui.dart';
import 'package:home_frontend/src/agent/generate_response.dart';
import 'package:home_frontend/src/agent/genui_agent.dart';
import 'package:home_frontend/src/agent/genui_agent_event.dart';
import 'package:home_frontend/src/agent/history_entry.dart';
import 'package:home_frontend/src/catalog/genui_catalog.dart';
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
/// buffered JSON body `{"messages": [...], "reply": ...}` on `2xx`: the whole
/// dashboard as validated A2UI 1.0 messages, which the agent applies in one
/// `processMessages` call, and the model's own text, which it keeps as the
/// history. Each request carries `metadata` with the renderer's capabilities
/// and the data model of its surfaces, so the stateless backend knows whether
/// the dashboard exists. Failures arrive
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
  /// The backend owns the system prompt, but the local [MessageProcessor] still
  /// needs both to render surfaces.
  ///
  /// `baseUri` defaults to `http://localhost:8080`, matching the Dart Frog
  /// dev server. Pass a custom [client] in tests.
  ///
  /// `sessionId`, when given, is sent as `X-Session-Id` so the backend answers
  /// from this visitor's own demo world.
  ///
  /// `tokenProvider` is invoked on every request and its result is sent as
  /// `Authorization: Bearer <token>`. A `null` or empty result throws
  /// [AuthError] before the request leaves the client.
  HttpGenUIAgent({
    required this._catalog,
    required this._widgetBuilders,
    required this._tokenProvider,
    this._sessionId,
    Uri? baseUri,
    http.Client? client,
  }) : _baseUri = baseUri ?? Uri.parse('http://localhost:8080'),
       _client = client ?? http.Client(),
       _ownsClient = client == null;

  final GenUiComponentCatalog _catalog;
  final Map<String, ComponentWidgetBuilder> _widgetBuilders;
  final Uri _baseUri;
  final http.Client _client;
  final bool _ownsClient;
  final GenUITokenProvider _tokenProvider;
  final String? _sessionId;
  final _queue = TurnQueue();

  /// The latest data model update that came for each path, outside a reply.
  ///
  /// A reply carries the values its devices had when it was written. One may
  /// have changed since, and the update that said so may have come first, so
  /// these are put back once a reply lands.
  final _latest = <String, Map<String, Object?>>{};

  late final MessageProcessor<ComponentImplementation> _processor;
  final _eventsController = StreamController<GenUIAgentEvent>.broadcast();
  final List<HistoryEntry> _history = [];
  final List<void Function()> _unsubscribes = [];
  bool _started = false;

  @override
  SurfaceGroupModel<ComponentImplementation> get surfaces => _processor.model;

  @override
  Stream<GenUIAgentEvent> get events => _eventsController.stream;

  @override
  List<HistoryEntry> get history => List.unmodifiable(_history);

  @override
  Future<void> start() async {
    if (_started) {
      throw StateError('GenUIAgent.start can only be called once.');
    }

    final catalog = buildCatalog(
      catalog: _catalog,
      widgetBuilders: _widgetBuilders,
    );
    _processor = MessageProcessor<ComponentImplementation>(
      catalogs: [catalog],
      defaultVersion: A2uiProtocolVersion.v1_0,
    );
    final model = _processor.model;
    _unsubscribes.addAll([
      model.onSurfaceCreated
          .subscribe((surface) => _eventsController.add(SurfaceAdded(surface)))
          .unsubscribe,
      model.onAction.subscribe(_onAction).unsubscribe,
      model.onError.subscribe(_onRendererError).unsubscribe,
    ]);
    _started = true;
  }

  @override
  Future<void> sendMessage(String text) async {
    if (!_started) {
      throw StateError('GenUIAgent.sendMessage requires start() first.');
    }
    _eventsController.add(UserMessageAdded(text));
    await _queue.interaction(() => _runTurn(content: text));
  }

  // A press on a surface. It has no caller to throw to, so a failed turn is
  // reported as an event.
  void _onAction(A2uiRendererAction action) {
    unawaited(
      _queue
          .interaction(
            () => _runTurn(content: _wireContent(action), press: action),
          )
          .then<void>(
            (_) {},
            onError: (Object error) => _eventsController.add(TurnFailed(error)),
          ),
    );
  }

  // The renderer reports a component it found invalid. Answered, it would be
  // one more model run with no dashboard to go on, whose reply (an apology, a
  // lone card) would replace the whole screen a moment after the real one, so
  // it is only logged.
  void _onRendererError(A2uiRendererError error) {
    developer.log(
      'Dropped a renderer error report: ${error.message}',
      name: 'home_frontend',
      level: 900,
    );
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
      _deliver(reply.messages);
      _history
        ..clear()
        ..add(HistoryEntry.user(text))
        ..add(HistoryEntry.assistant(reply.reply));
    });
  }

  @override
  void apply(Map<String, Object?> message) {
    if (!_started) return;
    try {
      _processor.processMessages([message]);
    } on Object catch (error) {
      developer.log(
        'Ignored a message the renderer cannot apply: $error',
        name: 'home_frontend',
        level: 900,
      );
      return;
    }
    if (message['updateDataModel'] case {
      'surfaceId': final String surfaceId,
      'path': final String path,
    }) {
      _latest['$surfaceId$path'] = message;
    }
  }

  // Hands the messages of a reply to the renderer in one call, so the panel
  // never shows a half applied dashboard. A reply the renderer rejects reaches
  // no one.
  void _deliver(List<Map<String, Object?>> messages) {
    // What the reply says of a value is as old as the reply: the newest word on
    // each is the last update that came for it.
    _processor.processMessages([...messages, ..._latest.values]);
  }

  Future<void> _runTurn({
    required String content,
    A2uiRendererAction? press,
  }) async {
    final priorHistory = List<HistoryEntry>.from(_history);
    _history.add(HistoryEntry.user(content));

    String? interactionLabel;
    String? failureReason;
    var modelMessageAppended = false;
    try {
      // A surface component bypasses sendMessage, so its turn is reported here
      // instead. Inside the try so the finally clause rolls history back if
      // resolving the label throws.
      if (press != null) {
        interactionLabel = _userActionLabel(press);
        _eventsController.add(UiInteractionAdded(interactionLabel));
      }

      final reply = await _fetch(priorHistory, content, press);
      _deliver(reply.messages);
      _history.add(HistoryEntry.assistant(reply.reply));
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

  // Asks the backend for a reply. Throws on every failure, before anything is
  // kept: the caller owns the history.
  Future<GenerateResponse> _fetch(
    List<HistoryEntry> priorHistory,
    String content,
    A2uiRendererAction? press,
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
            {'role': m.wireRole, 'content': m.content},
          {'role': 'user', 'content': content},
        ],
        if (isCommand) 'action': {'name': press.name, 'context': press.context},
        'metadata': _metadata(),
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

    // An empty reply is treated as a failed turn: the server rejects history
    // entries with empty content, so persisting an empty assistant entry would
    // break the next request. Throwing leaves `modelMessageAppended` false, so
    // the finally block rolls the user message back too, and it reaches the
    // zone as the same failure notice every other error path produces rather
    // than a turn that silently went nowhere.
    if (generated.reply.isEmpty) {
      throw EmptyResponseException('the model returned an empty reply');
    }
    return generated;
  }

  // What an A2UI 1.0 renderer sends with a request: its capabilities, and the
  // data model of each surface created with `sendDataModel`. The backend keeps
  // no state, so the surface ids in it tell it whether the dashboard exists.
  Map<String, Object?> _metadata() {
    final capabilities = _processor.getRendererCapabilities(
      const CapabilitiesOptions(versions: [A2uiProtocolVersion.v1_0]),
    );
    final dataModel = _processor.getRendererDataModel(
      version: A2uiProtocolVersion.v1_0,
    );
    return {
      'a2uiRendererCapabilities': capabilities.toJson(),
      'a2uiRendererDataModel': ?dataModel,
    };
  }

  // Label for a press, which becomes the user's row while it runs. The
  // agent-authored `context.progressLabel` wins; the visible text of the
  // component and then the action name are fallbacks.
  String _userActionLabel(A2uiRendererAction action) {
    final progress = action.context['progressLabel'];
    if (progress is String && progress.trim().isNotEmpty) {
      return progress.trim();
    }
    return _componentLabel(action.surfaceId, action.sourceComponentId) ??
        action.name;
  }

  // First literal text at or under the component that raised the action. Null
  // when the surface is gone or the text is a data binding, not a literal.
  String? _componentLabel(String surfaceId, String componentId) {
    final components = _processor.model.getSurface(surfaceId)?.componentsModel;
    if (components == null) return null;

    final pending = <String>[componentId];
    final visited = <String>{};
    while (pending.isNotEmpty) {
      final id = pending.removeAt(0);
      if (!visited.add(id)) continue;
      final properties = components.get(id)?.properties;
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
  static String _errorMessage(String body) => _backendMessage(body) ?? body;

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

  // The wire `content` of a press: the plain `context.text` of an `ask`, which
  // is a typed request, and the JSON of the action otherwise. The backend
  // rejects empty content with 422, so a press never goes out as nothing.
  static String _wireContent(A2uiRendererAction action) {
    if (action.name == HomeActions.ask) {
      final text = action.context['text'];
      if (text is String && text.trim().isNotEmpty) return text.trim();
    }
    return jsonEncode({'action': action.toJson()});
  }

  @override
  void dispose() {
    for (final unsubscribe in _unsubscribes) {
      unsubscribe();
    }
    _unsubscribes.clear();
    unawaited(_eventsController.close());
    if (_ownsClient) _client.close();
    if (!_started) return;
    _processor.model.dispose();
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
