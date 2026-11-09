/// {@template gen_u_i__zone_item}
/// One item in a `GenUIZoneController`'s interleaved list.
///
/// The zone renders a chronological list of user messages and agent-produced
/// surfaces. Each item carries the minimum data the view needs to build its
/// row.
/// {@endtemplate}
sealed class GenUIZoneItem {
  /// {@macro gen_u_i__zone_item}
  const GenUIZoneItem();
}

/// {@template user_message_item}
/// A user message accepted by the controller's `sendMessage` call.
/// {@endtemplate}
final class UserMessageItem extends GenUIZoneItem {
  /// {@macro user_message_item}
  const UserMessageItem(this.text, {this.failed = false});

  /// The text the user sent.
  final String text;

  /// Whether the turn this message started ended without a model reply.
  ///
  /// A failed message stays on screen next to its [ErrorItem], but no longer
  /// counts as the newest turn, so the surfaces before it keep their state.
  final bool failed;

  /// Returns a copy of this item marked [failed].
  UserMessageItem asFailed() => UserMessageItem(text, failed: true);
}

/// {@template error_item}
/// A turn that failed, recorded in place in the conversation.
///
/// Held as an item rather than a `GenUIZoneError` state so the conversation
/// before the failure survives and later turns can carry on.
/// {@endtemplate}
final class ErrorItem extends GenUIZoneItem {
  /// {@macro error_item}
  const ErrorItem(this.error);

  /// The failure itself, not a rendering of it.
  ///
  /// Kept as the raw object so a host can switch on the type — `AuthError` to
  /// ask for the key again, `HttpException` to offer a retry — instead of
  /// matching on message text.
  final Object error;
}

/// {@template surface_item}
/// A surface produced by the agent.
/// {@endtemplate}
final class SurfaceItem extends GenUIZoneItem {
  /// {@macro surface_item}
  const SurfaceItem(this.surfaceId);

  /// The id of the surface in the agent's `SurfaceController`.
  final String surfaceId;
}
