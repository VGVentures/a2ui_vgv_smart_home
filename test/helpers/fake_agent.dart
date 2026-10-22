import 'dart:async';

import 'package:a2ui_vgv_smart_home/dashboard/agent_factory.dart';
import 'package:genui/genui.dart';
import 'package:home_frontend/home_frontend.dart';
import 'package:home_frontend/src/agent/genui_agent_event.dart';
import 'package:home_repository/home_repository.dart';

class FakeAgent implements GenUIAgent {
  FakeAgent(
    this.user, {
    this.failWith,
    this.emitSurface = false,
    this.gate,
  });

  final HomeUser user;
  final Object? failWith;
  final bool emitSurface;

  /// Holds the request open until completed.
  final Completer<void>? gate;

  /// Holds the next request open until completed, after [gate] has opened.
  Completer<void>? hold;

  /// Fails the next request after it was held, once.
  Object? failNext;
  final sent = <String>[];
  bool disposed = false;
  final _events = StreamController<GenUIAgentEvent>.broadcast();

  @override
  Stream<GenUIAgentEvent> get events => _events.stream;

  @override
  final SurfaceController controller = SurfaceController(catalogs: const []);

  @override
  List<ChatMessage> get history => const [];

  @override
  Future<void> start() async {}

  @override
  Future<void> sendMessage(String text) async {
    sent.add(text);
    _events.add(UserMessageAdded(text));
    await gate?.future;
    await hold?.future;
    final failure = failNext ?? failWith;
    failNext = null;
    if (failure != null) {
      // The real agent drops the turn before it throws.
      _events.add(const UserTurnRolledBack());
      // An Error or an Exception, to exercise both paths.
      // ignore: only_throw_errors
      throw failure;
    }
    if (emitSurface) {
      _events.add(
        ConversationEventReceived(
          ConversationSurfaceAdded(
            'surface',
            SurfaceDefinition(surfaceId: 'surface'),
          ),
        ),
      );
    }
  }

  /// The messages [apply] was given.
  final applied = <Map<String, Object?>>[];

  @override
  void apply(Map<String, Object?> message) => applied.add(message);

  /// What [refresh] was asked for.
  final refreshed = <String>[];

  /// Holds the next [refresh] open until completed.
  Completer<void>? refreshHold;

  /// Fails the next [refresh], once.
  Object? refreshFailure;

  @override
  Future<void> refresh(String text) async {
    refreshed.add(text);
    await refreshHold?.future;
    final failure = refreshFailure;
    refreshFailure = null;
    // An Error or an Exception, as the real agent may throw either.
    // ignore: only_throw_errors
    if (failure != null) throw failure;
  }

  /// Pushes an event as the real agent would.
  void emit(GenUIAgentEvent event) => _events.add(event);

  @override
  void dispose() {
    disposed = true;
    unawaited(_events.close());
  }
}

class FakeAgentFactory implements AgentFactory {
  /// [failWith] and [gate] apply to the first agent only, [failLater] and
  /// [holdLater] to every agent after it.
  FakeAgentFactory({
    this.failWith,
    this.emitSurface = false,
    this.gate,
    this.failLater,
    this.holdLater,
  });

  final Object? failWith;
  final bool emitSurface;
  final Completer<void>? gate;
  final Object? failLater;
  final Completer<void>? holdLater;
  final agents = <FakeAgent>[];

  @override
  GenUIAgent create(HomeUser user) {
    final first = agents.isEmpty;
    final agent = FakeAgent(
      user,
      failWith: first ? failWith : failLater,
      emitSurface: emitSurface,
      gate: first ? gate : holdLater,
    );
    agents.add(agent);
    return agent;
  }
}
