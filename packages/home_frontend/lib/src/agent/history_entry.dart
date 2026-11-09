import 'package:flutter/foundation.dart' show immutable;

/// Who wrote a [HistoryEntry].
enum HistoryRole {
  /// The person: typed or spoken text, or a press on a surface.
  user,

  /// The model: the reply text of an earlier turn.
  assistant,
}

/// {@template history_entry}
/// One turn of the conversation as the backend is told about it.
///
/// The backend keeps no state, so every request carries the entries before it.
/// [content] is exactly what goes on the wire: the typed text, the JSON of a
/// press, or the reply the model wrote.
/// {@endtemplate}
@immutable
final class HistoryEntry {
  /// {@macro history_entry}
  const HistoryEntry(this.role, this.content);

  /// A turn the person took.
  const HistoryEntry.user(String content) : this(HistoryRole.user, content);

  /// A reply the model wrote.
  const HistoryEntry.assistant(String content)
    : this(HistoryRole.assistant, content);

  /// Who wrote the turn.
  final HistoryRole role;

  /// What was said, as sent on the wire.
  final String content;

  /// The wire name of [role].
  String get wireRole => switch (role) {
    HistoryRole.user => 'user',
    HistoryRole.assistant => 'assistant',
  };

  @override
  bool operator ==(Object other) =>
      other is HistoryEntry && other.role == role && other.content == content;

  @override
  int get hashCode => Object.hash(role, content);

  @override
  String toString() => 'HistoryEntry(${role.name}: $content)';
}
