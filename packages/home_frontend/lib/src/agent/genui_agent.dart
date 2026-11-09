import 'package:home_frontend/src/a2ui/a2ui.dart';
import 'package:home_frontend/src/agent/genui_agent_event.dart';
import 'package:home_frontend/src/agent/history_entry.dart';

/// {@template gen_u_i__agent}
/// Drives a single GenUI conversation against a backend LLM.
///
/// Implementations are constructed once per GenUIZone and own the lifecycle
/// of their [MessageProcessor] and the surfaces it holds. The catalog
/// components the LLM is allowed to render are supplied to the implementation
/// at construction.
/// {@endtemplate}
abstract class GenUIAgent {
  /// The surfaces produced during the conversation.
  ///
  /// Exposed so the view can find the model of a surface by id and render it
  /// with `A2uiSurface`. Only valid after [start] completes.
  SurfaceGroupModel<ComponentImplementation> get surfaces;

  /// Stream of agent events: a [SurfaceAdded] when a surface is created, the
  /// turn events a press raises, and [UserMessageAdded] on [sendMessage] entry.
  Stream<GenUIAgentEvent> get events;

  /// Conversation history captured across calls to [sendMessage].
  ///
  /// Each call appends the user message and, once the response arrives, the
  /// model message. Returned as an unmodifiable view.
  List<HistoryEntry> get history;

  /// Wires up the catalog and the message processor. No request is sent to the
  /// LLM until [sendMessage] is called.
  Future<void> start();

  /// Sends [text] as a user message to the LLM and waits for the response.
  /// Must be called after [start].
  Future<void> sendMessage(String text);

  /// Asks for the surface again because the data behind it changed, without a
  /// person asking. Must be called after [start].
  ///
  /// The reply updates the surface in place. It is dropped when something the
  /// person did is running or waiting, which is answered from fresh data
  /// already, and when one is asked while this runs.
  Future<void> refresh(String text);

  /// Applies an A2UI 1.0 [message] that did not come in a reply, such as an
  /// `updateDataModel` the backend sends as a device changes, to the surface.
  ///
  /// The cards bound to the value change in place, with no model run. A message
  /// the renderer cannot read is ignored.
  void apply(Map<String, Object?> message);

  /// Releases stream subscriptions and underlying resources.
  void dispose();
}
