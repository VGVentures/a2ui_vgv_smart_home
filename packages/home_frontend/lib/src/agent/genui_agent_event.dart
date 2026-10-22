import 'package:home_frontend/src/a2ui/a2ui.dart';

/// {@template gen_u_i__agent_event}
/// Events emitted by a `GenUIAgent` as a conversation progresses.
///
/// Wraps SDK-level [ConversationEvent]s alongside synthetic events the agent
/// raises locally (such as user messages), so a single subscription can drive
/// the zone's interleaved item list.
/// {@endtemplate}
sealed class GenUIAgentEvent {
  /// {@macro gen_u_i__agent_event}
  const GenUIAgentEvent();
}

/// {@template conversation_event_received}
/// An SDK [ConversationEvent] forwarded by the agent.
/// {@endtemplate}
final class ConversationEventReceived extends GenUIAgentEvent {
  /// {@macro conversation_event_received}
  ///
  /// Wraps [event] for downstream subscribers.
  const ConversationEventReceived(this.event);

  /// The underlying SDK conversation event.
  final ConversationEvent event;
}

/// {@template user_message_added}
/// A user message accepted by the agent's `sendMessage` entry point.
///
/// Emitted before the transport is invoked so the zone can render the bubble
/// immediately, before the agent's buffered response arrives.
/// {@endtemplate}
final class UserMessageAdded extends GenUIAgentEvent {
  /// {@macro user_message_added}
  const UserMessageAdded(this.text);

  /// The text the user sent.
  final String text;
}

/// {@template ui_interaction_added}
/// A user action dispatched from a generated surface.
///
/// A surface component submits through the transport, not
/// `GenUIAgent.sendMessage`, so it raises no [UserMessageAdded]. This event
/// brackets that turn with [UiInteractionCompleted]. Client-raised validation
/// reports share the same path but are not reported.
/// {@endtemplate}
final class UiInteractionAdded extends GenUIAgentEvent {
  /// {@macro ui_interaction_added}
  const UiInteractionAdded(this.label);

  /// The visible label of the component that raised the action, or, when that
  /// cannot be resolved, the action's name.
  final String label;
}

/// {@template ui_interaction_completed}
/// The end of the turn a [UiInteractionAdded] event started.
///
/// Emitted on every exit path, including a failed or empty turn.
/// {@endtemplate}
final class UiInteractionCompleted extends GenUIAgentEvent {
  /// {@macro ui_interaction_completed}
  const UiInteractionCompleted({this.succeeded = true, this.reason});

  /// Whether the turn produced a reply. False on every failure: an HTTP or
  /// auth error, an empty or malformed reply, a network error.
  final bool succeeded;

  /// The backend's own `message` when a press (`POST /action`) was answered
  /// with a non-2xx status and a `{"message": ...}` body, so the UI can show it
  /// as is. Null otherwise: on success, on an auth error, on a network error
  /// and on any failure without a parseable message, where the UI falls back to
  /// its own generic line.
  final String? reason;
}

/// {@template user_turn_rolled_back}
/// A user turn the agent discarded because it produced no model reply.
///
/// The agent drops the user message from its history on a failed or empty turn,
/// because the server rejects a history ending on two user messages. The zone
/// keeps showing the message but stops treating it as the newest turn, so the
/// surfaces before it are not aged out by a turn the model never saw.
/// {@endtemplate}
final class UserTurnRolledBack extends GenUIAgentEvent {
  /// {@macro user_turn_rolled_back}
  const UserTurnRolledBack();
}
