/// {@template reply_outcome}
/// What the reply pipeline made of the model's reply: the A2UI messages to send
/// to the panel, or the errors to send back to the model.
/// {@endtemplate}
class ReplyOutcome {
  /// {@macro reply_outcome}
  ///
  /// A reply that passed: [messages] are validated A2UI 1.0 messages for the
  /// dashboard surface.
  const ReplyOutcome.accepted(this.messages) : errors = const [];

  /// {@macro reply_outcome}
  ///
  /// A reply that failed: [errors] are lines written for the retry prompt.
  const ReplyOutcome.rejected(this.errors) : messages = const [];

  /// The messages for the panel, in the order it applies them.
  final List<Map<String, Object?>> messages;

  /// Why the reply was rejected, one line each, or empty for an accepted one.
  final List<String> errors;

  /// Whether the reply passed.
  bool get isAccepted => errors.isEmpty;
}
