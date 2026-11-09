import 'dart:convert';
import 'dart:io';
import 'dart:isolate';

import 'package:home_timeline/src/wall_time.dart';

/// {@template feed_rules}
/// The moments of the activity feed, as `feed_rules.json` declares them.
///
/// A rule turns the facts of one `source` (an order, a trip, a plan step) into
/// one moment. The JSON owns the words and the flags; the activity feed owns
/// reading the facts out of the data.
/// {@endtemplate}
class FeedRules {
  /// {@macro feed_rules}
  ///
  /// Creates the rules from their decoded JSON.
  FeedRules.fromJson(Map<String, dynamic> json)
    : recentWindow = Duration(minutes: json['recentMinutes'] as int),
      nextWindow = Duration(minutes: json['nextMinutes'] as int),
      rules = [
        for (final rule in (json['rules'] as List<dynamic>))
          FeedRule._(rule as Map<String, dynamic>),
      ];

  /// {@macro feed_rules}
  ///
  /// Reads the rules this package ships.
  ///
  /// An AOT build has no package config to find the file by, so it falls back
  /// to `assets/feed_rules.json` in the working directory, where the deploy
  /// copies it.
  factory FeedRules.bundled() {
    final uri = Isolate.resolvePackageUriSync(
      Uri.parse('package:home_timeline/src/feed_rules.json'),
    );
    final file = uri == null
        ? File('assets/feed_rules.json')
        : File.fromUri(uri);
    return FeedRules.fromJson(
      jsonDecode(file.readAsStringSync()) as Map<String, dynamic>,
    );
  }

  /// How far back a moment still counts as just happened.
  final Duration recentWindow;

  /// How far ahead a moment still counts as coming up.
  final Duration nextWindow;

  /// Every rule, in the order their moments are listed before sorting.
  final List<FeedRule> rules;
}

/// {@template feed_rule}
/// One rule of [FeedRules]: when a moment happens and what it says.
/// {@endtemplate}
class FeedRule {
  FeedRule._(Map<String, dynamic> json)
    : source = json['source'] as String,
      at = json['at'] as String,
      when = json['when'] as String?,
      kind = json['kind'] as String,
      _summary = switch (json['summary']) {
        final List<dynamic> parts => parts.join(),
        final Object text => text as String,
        _ => throw ArgumentError('A feed rule needs a summary: $json'),
      },
      _subject = json['subject'] as String? ?? 'household',
      _by = json['by'] as String?,
      _ids = {
        for (final key in const ['deviceId', 'stepId', 'listId', 'tripId'])
          if (json[key] case final String template) key: template,
      },
      _itinerary = json['itinerary'] as String?,
      pastOnly = json['pastOnly'] as bool? ?? false,
      urgent = json['urgent'] as bool? ?? false,
      alwaysNext = json['alwaysNext'] as bool? ?? false;

  /// The kind of fact set the rule reads: `oven`, `bakeryOrder`, `trip`...
  final String source;

  /// The fact that holds when the moment happens. A rule whose fact is absent
  /// (a roast with no start time) gives no moment.
  final String at;

  /// A fact that must be true (`atTheDoor`), or false when written `!atTheDoor`
  /// for the rule to apply.
  final String? when;

  /// What the moment is about: `oven`, `bakery`, `trip`...
  final String kind;

  /// Whether the moment only counts once the clock has reached it.
  final bool pastOnly;

  /// Whether the moment is something to act on right now.
  final bool urgent;

  /// Whether the moment is shown as coming up however far off it is.
  final bool alwaysNext;

  final String _summary;
  final String _subject;
  final String? _by;
  final Map<String, String> _ids;
  final String? _itinerary;

  /// The moment this rule gives for [facts], or `null` when it does not apply.
  Map<String, Object?>? moment(Map<String, Object?> facts) {
    final time = facts[at];
    if (time is! DateTime) return null;
    if (when case final condition?) {
      final negated = condition.startsWith('!');
      final value = facts[negated ? condition.substring(1) : condition];
      if ((value == true) == negated) return null;
    }
    return {
      'at': time,
      'kind': kind,
      'summary': _fill(_summary, facts),
      'subject': _fill(_subject, facts),
      'by': _by == null ? null : _fill(_by, facts),
      for (final MapEntry(:key, :value) in _ids.entries)
        key: _single(value, facts),
      'itinerary': _itinerary == null ? null : facts[_itinerary],
      'pastOnly': pastOnly,
      'urgent': urgent,
      'alwaysNext': alwaysNext,
    };
  }

  static final _slot = RegExp(r'\{(\w+)\}');

  /// A template made only of one `{fact}` gives that fact itself, so an absent
  /// id stays `null` rather than becoming an empty string.
  static Object? _single(String template, Map<String, Object?> facts) {
    final match = _slot.firstMatch(template);
    if (match != null && match.group(0) == template) {
      return facts[match.group(1)];
    }
    return _fill(template, facts);
  }

  static String _fill(String template, Map<String, Object?> facts) {
    return template.replaceAllMapped(_slot, (slot) {
      final value = facts[slot.group(1)];
      if (value is DateTime) return clock12(value);
      return value?.toString() ?? '';
    });
  }
}
