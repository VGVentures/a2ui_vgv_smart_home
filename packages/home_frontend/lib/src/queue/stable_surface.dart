import 'dart:convert';

/// {@template rejected_reply}
/// A reply that must not reach the renderer, with the reasons.
/// {@endtemplate}
class RejectedReply implements Exception {
  /// {@macro rejected_reply}
  const RejectedReply(this.reasons);

  /// What is wrong with the reply, one line each.
  final List<String> reasons;

  @override
  String toString() => 'RejectedReply: ${reasons.join('; ')}';
}

/// {@template stable_surface}
/// Keeps every reply of one dashboard on a single long lived surface, the way
/// an A2UI 1.0 agent updates a surface instead of replacing it.
///
/// The model still writes a full dashboard each turn, under a surface id of its
/// own choosing. [admit] reads those messages and returns what the renderer
/// should see instead:
///
/// - every message is addressed to [id];
/// - `createSurface` goes through once. Later ones are dropped, so the screen
///   rebuilds in place rather than swapping to a new surface. A different
///   catalog is the one reason to recreate: it becomes `deleteSurface` and
///   `createSurface`, as the spec requires;
/// - the reply is checked as a whole before anything is returned: a `root`
///   exists and no component points at one that does not. A reply that fails
///   is rejected whole, so the screen never shows half of a turn.
///
/// Once the model sends diffs (an `updateComponents` with only the cards that
/// changed), this class has nothing left to do. It validates them the same way,
/// against the components the surface already holds. Delete it when moving to
/// the official A2UI client.
/// {@endtemplate}
class StableSurface {
  /// {@macro stable_surface}
  StableSurface(this.id);

  /// The one surface id the renderer sees.
  final String id;

  final _known = <String>{};
  String? _catalogId;

  // The prompt makes the model fence every message with ```json ... ```.
  static final _fence = RegExp(r'```json\b(.*?)```', dotAll: true);

  static const _messageKeys = [
    'createSurface',
    'updateComponents',
    'updateDataModel',
    'deleteSurface',
  ];

  /// [message] addressed to [id], for a message that did not come in a reply:
  /// an update the backend sends to the dashboard on screen. A map that is not
  /// a message is returned as it is.
  Map<String, Object?> address(Map<String, Object?> message) {
    final key = _messageKeys.where(message.containsKey).firstOrNull;
    final body = key == null ? null : message[key];
    if (key == null || body is! Map<String, Object?>) return message;
    return {
      ...message,
      key: {...body, 'surfaceId': id},
    };
  }

  /// The messages in [reply], addressed to [id], or a [RejectedReply].
  ///
  /// Nothing is kept when it throws: the next reply is judged against the last
  /// surface that was accepted.
  List<Map<String, Object?>> admit(String reply) {
    final out = <Map<String, Object?>>[];
    final known = {..._known};
    var catalogId = _catalogId;
    final added = <Map<String, Object?>>[];

    for (final match in _fence.allMatches(reply)) {
      final Object? decoded;
      try {
        decoded = jsonDecode(match.group(1)!);
      } on FormatException {
        throw const RejectedReply(['a message is not valid JSON']);
      }
      if (decoded is! Map<String, Object?>) continue;
      final key = _messageKeys.where(decoded.containsKey).firstOrNull;
      final body = key == null ? null : decoded[key];
      if (key == null || body is! Map<String, Object?>) continue;

      final message = <String, Object?>{
        ...decoded,
        key: {...body, 'surfaceId': id},
      };
      switch (key) {
        case 'createSurface':
          final next = body['catalogId'] as String?;
          if (catalogId != null && next == catalogId) continue;
          if (catalogId != null) {
            out.add({
              'version': decoded['version'],
              'deleteSurface': {'surfaceId': id},
            });
            known.clear();
          }
          catalogId = next;
        case 'updateComponents':
          final components = body['components'];
          if (components is List<Object?>) {
            added.addAll(components.whereType<Map<String, Object?>>());
          }
        case 'deleteSurface':
          known.clear();
          catalogId = null;
      }
      out.add(message);
    }

    for (final component in added) {
      if (component['id'] case final String componentId) {
        known.add(componentId);
      }
    }
    final reasons = _problems(out, added, known, catalogId);
    if (reasons.isNotEmpty) throw RejectedReply(reasons);

    _known
      ..clear()
      ..addAll(known);
    _catalogId = catalogId;
    return out;
  }

  static List<String> _problems(
    List<Map<String, Object?>> out,
    List<Map<String, Object?>> added,
    Set<String> known,
    String? catalogId,
  ) {
    if (out.isEmpty) return const ['the reply holds no A2UI message'];
    final reasons = <String>[];
    if (catalogId == null) reasons.add('there is no createSurface');
    if (!known.contains('root')) {
      reasons.add('no component has the id "root"');
    }
    final missing = {
      for (final component in added)
        for (final ref in _references(component))
          if (!known.contains(ref)) ref,
    };
    if (missing.isNotEmpty) {
      reasons.add('components reference ids that do not exist: $missing');
    }
    return reasons;
  }

  // The ids a component points at: `child`, a `children` list, or the
  // `componentId` of a `children` template.
  static Iterable<String> _references(Map<String, Object?> component) sync* {
    if (component['child'] case final String child) yield child;
    switch (component['children']) {
      case final List<Object?> list:
        yield* list.whereType<String>();
      case {'componentId': final String template}:
        yield template;
    }
  }
}
