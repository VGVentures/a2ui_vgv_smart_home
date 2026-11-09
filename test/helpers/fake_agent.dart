import 'dart:async';

import 'package:a2ui_vgv_smart_home/dashboard/agent_factory.dart';
import 'package:flutter/widgets.dart' show SizedBox;
import 'package:home_frontend/home_frontend.dart';
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

  /// A real processor over a catalog of one empty `Row`, so a surface the fake
  /// emits has a root and is drawn by the real `SurfaceView`.
  final _processor = MessageProcessor<ComponentImplementation>(
    catalogs: [
      CatalogImplementation(
        id: homeCatalog.id,
        protocolVersion: A2uiProtocolVersion.v1_0,
        components: [
          ComponentImplementation(
            name: 'Row',
            schema: homeCatalog.components['Row']!.schema,
            builder: (context, node, props, buildChild) => const SizedBox(),
          ),
        ],
      ),
    ],
    defaultVersion: A2uiProtocolVersion.v1_0,
  );

  @override
  SurfaceGroupModel<ComponentImplementation> get surfaces => _processor.model;

  @override
  List<HistoryEntry> get history => const [];

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
      _processor.processMessages([
        {
          'version': '1.0',
          'createSurface': {
            'surfaceId': 'surface',
            'catalogId': homeCatalog.id,
            'components': [
              {'id': 'root', 'component': 'Row', 'children': <String>[]},
            ],
          },
        },
      ]);
      _events.add(SurfaceAdded(_processor.model.getSurface('surface')!));
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
    _processor.model.dispose();
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
