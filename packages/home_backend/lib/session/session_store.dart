import 'dart:async';

import 'package:home_backend/session/demo_session.dart';

/// Builds a fresh [DemoSession] in the demo's first state.
typedef SessionFactory = Future<DemoSession> Function();

/// {@template session_limit_reached}
/// Thrown when every session slot is held by a visitor who is still connected.
/// {@endtemplate}
class SessionLimitReached implements Exception {
  /// {@macro session_limit_reached}
  ///
  /// Creates the exception.
  const SessionLimitReached();

  @override
  String toString() => 'SessionLimitReached';
}

/// One visitor's world, being built or ready, and when it was last used.
class _Entry {
  _Entry(this.session, this.lastUsed);

  final Future<DemoSession> session;
  DateTime lastUsed;
  DemoSession? ready;
}

/// {@template session_store}
/// The demo worlds of the visitors who are using it, by session id.
/// {@endtemplate}
///
/// A world is built on a visitor's first request and dropped once they have
/// been idle for [idleTimeout]. At most [maxSessions] exist at once, so memory
/// stays bounded. A world whose visitor still has a `/live` socket open is
/// never dropped.
class SessionStore {
  /// {@macro session_store}
  ///
  /// Creates a store that builds worlds with its factory.
  SessionStore({
    required this._factory,
    this.idleTimeout = const Duration(minutes: 30),
    this.maxSessions = 200,
    DateTime Function()? now,
  }) : _now = now ?? DateTime.now;

  final SessionFactory _factory;
  final DateTime Function() _now;

  /// How long a visitor can be silent before their world is dropped.
  final Duration idleTimeout;

  /// The most worlds kept at once.
  final int maxSessions;

  final _entries = <String, _Entry>{};

  /// How many worlds are kept.
  int get length => _entries.length;

  /// The world of the visitor [id], built if this is their first request.
  ///
  /// Throws [SessionLimitReached] when [id] is new and there is no room.
  Future<DemoSession> obtain(String id) {
    final now = _now();
    final existing = _entries[id];
    if (existing != null) {
      existing.lastUsed = now;
      return existing.session;
    }
    _evict(now);
    if (_entries.length >= maxSessions) throw const SessionLimitReached();

    final entry = _Entry(_factory(), now);
    _entries[id] = entry;
    unawaited(
      entry.session.then<void>(
        (session) => entry.ready = session,
        onError: (Object _) {
          if (_entries[id] == entry) _entries.remove(id);
        },
      ),
    );
    return entry.session;
  }

  // Drops what has been idle too long, then the longest idle while over the
  // limit. A world with a socket open stays.
  void _evict(DateTime now) {
    bool inUse(_Entry entry) => (entry.ready?.hub.listenerCount ?? 1) > 0;

    _entries.removeWhere(
      (_, entry) =>
          !inUse(entry) && now.difference(entry.lastUsed) >= idleTimeout,
    );
    if (_entries.length < maxSessions) return;
    final idle = _entries.entries.where((e) => !inUse(e.value)).toList()
      ..sort((a, b) => a.value.lastUsed.compareTo(b.value.lastUsed));
    if (idle.isNotEmpty) _entries.remove(idle.first.key);
  }
}
