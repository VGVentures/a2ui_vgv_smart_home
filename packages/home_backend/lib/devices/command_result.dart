/// {@template state_change}
/// One value the state machine changed.
/// {@endtemplate}
class StateChange {
  /// {@macro state_change}
  const StateChange({
    required this.deviceId,
    required this.trait,
    required this.field,
    required this.from,
    required this.to,
  });

  /// The device, scene or list id the value belongs to.
  final String deviceId;

  /// The trait the value sits in, for example `OperationalState`.
  final String trait;

  /// The field inside the trait, for example `state`.
  final String field;

  /// The value before the command.
  final Object? from;

  /// The value after the command.
  final Object? to;

  /// The change as JSON, for tool results.
  Map<String, Object?> toJson() => {
    'deviceId': deviceId,
    'trait': trait,
    'field': field,
    'from': from,
    'to': to,
  };
}

/// {@template command_result}
/// What a command did: a one-line [summary] and the exact [changes].
/// {@endtemplate}
///
/// An empty [changes] list means nothing moved, either because the state
/// already matched (a no-op) or because the press was only an acknowledgement.
class CommandResult {
  /// {@macro command_result}
  const CommandResult({required this.summary, this.changes = const []});

  /// A plain-text description of what happened.
  final String summary;

  /// Every value that changed, in order.
  final List<StateChange> changes;

  /// Whether any value changed.
  bool get changed => changes.isNotEmpty;

  /// The result as JSON, for tool results.
  Map<String, Object?> toJson() => {
    'summary': summary,
    'changed': changed,
    'changes': [for (final change in changes) change.toJson()],
  };
}
