import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:home_frontend/src/a2ui/a2ui.dart';
import 'package:home_frontend/src/agent/genui_agent.dart';
import 'package:home_frontend/src/agent/genui_agent_event.dart';
import 'package:home_frontend/src/zone/controller/genui_zone_item.dart';
import 'package:home_frontend/src/zone/controller/genui_zone_state.dart';

/// {@template gen_u_i__zone_controller}
/// Drives a [GenUIAgent] and exposes its progress as a [GenUIZoneState].
///
/// The host constructs one controller per [GenUIAgent], calls [start] once to
/// wire up the agent stream, and drives the zone with [sendMessage]. The
/// controller does not own the agent. Whoever constructed the agent is
/// responsible for disposing it.
/// {@endtemplate}
class GenUIZoneController extends ChangeNotifier {
  /// {@macro gen_u_i__zone_controller}
  GenUIZoneController({required this._agent});

  final GenUIAgent _agent;

  final List<GenUIZoneItem> _items = [];
  StreamSubscription<GenUIAgentEvent>? _eventsSub;
  bool _started = false;
  bool _disposed = false;
  bool _sending = false;
  bool _discarding = false;
  int _failedTurns = 0;

  GenUIZoneState _state = const GenUIZoneInitial();

  /// The current state of the zone.
  GenUIZoneState get state => _state;

  /// Whether a message is in flight and has not yet produced a surface.
  ///
  /// True from the moment [sendMessage] is called until a surface is added to
  /// the zone (or the request ends). Hosts can use this to reflect the
  /// in-flight state, such as disabling input or showing a progress indicator
  /// while the agent responds.
  ///
  /// A press on a generated surface counts too, even though it never passes
  /// through [sendMessage]; that turn clears the flag when it ends rather than
  /// when a surface arrives.
  bool get isSending => _sending;

  /// How many surface presses have failed so far.
  ///
  /// Grows each time a `UiInteractionCompleted` arrives with `succeeded` false.
  /// The host feeds it to an `OptimisticScope` so switches, steppers and
  /// checkboxes that flipped ahead of the backend reset themselves.
  int get failedTurns => _failedTurns;

  /// Stops the turn in flight from changing the zone: its surface and its
  /// error are dropped when they arrive. The agent still finishes the turn, so
  /// [isSending] stays true until it does.
  void discardTurn() {
    if (_sending) _discarding = true;
  }

  /// Subscribes to [GenUIAgent.events] and starts the agent. Must be called
  /// exactly once before [sendMessage]. The state stays [GenUIZoneInitial]
  /// until the agent emits its first item.
  Future<void> start() async {
    assert(!_started, 'GenUIZoneController.start() called more than once');
    assert(!_disposed, 'GenUIZoneController used after dispose');
    if (_started) return;
    _started = true;

    _eventsSub = _agent.events.listen((event) {
      switch (event) {
        case ConversationEventReceived(:final event):
          switch (event) {
            case ConversationSurfaceAdded() || ConversationError()
                when _discarding:
              break;
            case ConversationSurfaceAdded(:final surfaceId):
              _items.add(SurfaceItem(surfaceId));
              _sending = false;
              _emitItemsUpdated();
            case ConversationError(:final error):
              // A turn the SDK started for us reports its failure here rather
              // than throwing back to sendMessage. Recorded as an item so one
              // failed turn does not erase the conversation before it.
              _sending = false;
              _addErrorItem(error);
            case ConversationEvent():
              // Nothing else changes the item list.
              break;
          }
        case UserMessageAdded(:final text):
          _items.add(UserMessageItem(text));
          _emitItemsUpdated();
        case UiInteractionAdded(:final label):
          // The recorded item is also what locks the surfaces behind it, since
          // the view keys locking off the latest user item.
          _items.add(UserMessageItem(label));
          _sending = true;
          _emitItemsUpdated();
        case UiInteractionCompleted(:final succeeded):
          if (!succeeded) {
            _failedTurns++;
            if (!_disposed) notifyListeners();
          }
          _setSending(false);
        case UserTurnRolledBack():
          _markCurrentTurnFailed();
      }
    });

    try {
      await _agent.start();
    } on Exception catch (error) {
      _emit(GenUIZoneError(error: error.toString()));
    }
  }

  /// Sends [text] as a user message through the underlying agent.
  Future<void> sendMessage(String text) async {
    assert(_started, 'GenUIZoneController.sendMessage before start()');
    _discarding = false;
    _setSending(true);
    try {
      await _agent.sendMessage(text);
    } on Exception catch (error) {
      if (!_discarding) _addErrorItem(error);
    } finally {
      _discarding = false;
      _setSending(false);
    }
  }

  void _addErrorItem(Object error) {
    _items.add(ErrorItem(error));
    _emitItemsUpdated();
  }

  /// Marks the message that started the current turn as failed.
  ///
  /// The message stays on screen so the user still sees what they sent, but a
  /// failed message no longer counts as the newest turn, so the surfaces before
  /// it are not aged out by a turn the model never saw.
  ///
  /// Scans back only as far as the last surface: anything before that belongs
  /// to a turn that already succeeded. An [ErrorItem] may already sit on top
  /// when the failure threw back to [sendMessage] rather than arriving as an
  /// event, so trailing items are skipped rather than requiring an exact match.
  void _markCurrentTurnFailed() {
    for (var i = _items.length - 1; i >= 0; i--) {
      final item = _items[i];
      if (item is SurfaceItem) return;
      if (item is UserMessageItem) {
        if (item.failed) return;
        _items[i] = item.asFailed();
        _emitItemsUpdated();
        return;
      }
    }
  }

  void _setSending(bool value) {
    if (_disposed || _sending == value) return;
    _sending = value;
    notifyListeners();
  }

  void _emitItemsUpdated() {
    _emit(
      GenUIZoneItemsUpdated(
        controller: _agent.controller,
        items: List.unmodifiable(_items),
      ),
    );
  }

  void _emit(GenUIZoneState newState) {
    if (_disposed) return;
    _state = newState;
    notifyListeners();
  }

  @override
  void dispose() {
    _disposed = true;
    _eventsSub?.cancel().ignore();
    super.dispose();
  }
}
