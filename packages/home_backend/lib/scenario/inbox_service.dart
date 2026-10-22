import 'package:home_backend/data/mock_database.dart';

/// {@template inbox_service}
/// The household inbox: what one person changed that another one has to know.
/// {@endtemplate}
///
/// A change that reaches past the person who made it (the host moves the
/// dinner, so the person driving to the bakery needs a new plan) is written
/// here, addressed to each person it concerns. The model reads a person's
/// inbox when it composes their screen, so it can lead with what changed and
/// offer the best way out, and the UI is told the moment an item lands.
///
/// It only keeps notifications. Acting on one is the model's job, through the
/// same tools as any other request.
class InboxService {
  /// {@macro inbox_service}
  ///
  /// Creates an inbox over the mock database. `onPosted` is told about every
  /// item right after it is written, for the live connection to push.
  InboxService(this._database, {this._onPosted});

  final MockDatabase _database;
  final void Function(Map<String, Object?>)? _onPosted;

  /// Writes a notification for [to], sent by [from], as of the scenario clock.
  ///
  /// [suggestion] is the option the sender's change makes best for [to], as
  /// `{tool, label, reason}`: the model proposes it and a person decides.
  /// {@macro throws_unknown_user}
  Map<String, Object?> post({
    required String to,
    required String from,
    required String kind,
    required String title,
    required String body,
    Map<String, Object?>? suggestion,
  }) {
    _database
      ..requireUser(to)
      ..requireUser(from);
    final item = <String, dynamic>{
      'id': 'inbox_${_database.inboxItems.length + 1}',
      'userId': to,
      'from': from,
      'at': _database.clock.nowIso,
      'kind': kind,
      'title': title,
      'body': body,
      'suggestion': ?suggestion,
      'read': false,
    };
    _database.inboxItems.add(item);
    _onPosted?.call({...item});
    return {
      'service': 'inbox',
      'action': 'notify',
      'to': to,
      'itemId': item['id'],
      'title': title,
    };
  }

  /// Marks the unread items of [userId] as read, or only [itemId] when given.
  ///
  /// Throws [MockDataNotFound] for an unknown user or for an item that is not
  /// in that user's inbox.
  Map<String, Object?> markRead(String userId, {String? itemId}) {
    _database.requireUser(userId);
    final mine = [
      for (final item in _database.inboxItems)
        if (item['userId'] == userId) item,
    ];
    if (itemId != null && !mine.any((item) => item['id'] == itemId)) {
      throw MockDataNotFound(
        'No inbox item "$itemId" for $userId. Available: '
        '${mine.map((item) => item['id']).join(', ')}.',
      );
    }
    var changed = 0;
    for (final item in mine) {
      if ((itemId == null || item['id'] == itemId) && item['read'] != true) {
        item['read'] = true;
        changed++;
      }
    }
    return {'userId': userId, 'markedRead': changed};
  }
}
