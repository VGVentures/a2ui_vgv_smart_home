import 'dart:convert';

import 'package:home_backend/validation/layout_composer.dart';
import 'package:home_backend/validation/llm_response_validator.dart';
import 'package:home_catalog/home_catalog.dart';

/// {@template layout_validator}
/// Validates that the screen in the LLM response sits on the panel grid.
/// {@endtemplate}
///
/// The grid is the one of the Figma component catalog: 12 columns by 2 rows.
/// Every card is built for the cells its `GenUiComponent.fit` lists, which is
/// the same data the layout prompt is rendered from and the frontend draws, so
/// a reply that passes here is drawn at exactly the proportions of the design:
/// nothing dropped, nothing stretched.
///
/// It reads the components of the reply, merged by id, and follows the tree
/// from `root`:
///
/// - the root is a `Column` that holds one or two `Row`s and ends with one
///   `ActionChips` (none with an urgent heads-up);
/// - beside a full height card, the rest of the area is a `Column` of one or
///   two `Row`s, or of one or two cards, with the `weight` of the columns that
///   are left;
/// - the `weight`s of a `Row` are columns and add up to exactly 12;
/// - a card has a `weight` it is built for (none means the one it is best built
///   for), at half tall, or both rows for the
///   full height cards, which only a single `Row` of a screen may hold, beside
///   `Column`s of one or two cards;
/// - every id a `Row` or `Column` lists is defined.
///
/// A reply without a `root` is left alone: it holds no screen to judge. Each
/// error line is written for the retry prompt.
///
/// A reply that is off the grid is also mended: [repair] lays the model's own
/// cards out again with a [LayoutComposer], so the model chooses the cards and
/// code adds up the columns.
class LayoutValidator implements LlmResponseValidator, LlmResponseRepairer {
  /// {@macro layout_validator}
  ///
  /// Creates a [LayoutValidator] that reads the cells of [catalog].
  LayoutValidator(GenUiComponentCatalog catalog)
    : _catalog = catalog,
      _composer = LayoutComposer(catalog);

  final GenUiComponentCatalog _catalog;
  final LayoutComposer _composer;

  // The prompt instructs the LLM to fence A2UI messages with ```json ... ```.
  static final _fenceRegExp = RegExp(r'```json\b(.*?)```', dotAll: true);

  static const _footer = 'ActionChips';

  /// The most cards on one screen: two rows of three.
  static const _maxCards = 6;

  static const _rowSums = '7 and 5, 8 and 4, three of 4, or 3, 4 and 5';

  @override
  List<String>? validate(String response) {
    final components = _components(response);
    final root = components['root'];
    if (root == null) return null;
    final errors = <String>[];
    _Screen(_catalog, components, errors).check(root);
    return errors.isEmpty ? null : errors;
  }

  @override
  String repair(String response) {
    if (validate(response) == null) return response;
    return _composer.compose(response) ?? response;
  }

  Map<String, Map<String, Object?>> _components(String response) {
    final byId = <String, Map<String, Object?>>{};
    for (final match in _fenceRegExp.allMatches(response)) {
      final Object? decoded;
      try {
        decoded = jsonDecode(match.group(1)!);
      } on FormatException {
        continue;
      }
      if (decoded is! Map<String, Object?>) continue;
      final update = decoded['updateComponents'];
      final list = update is Map<String, Object?> ? update['components'] : null;
      if (list is! List) continue;
      for (final entry in list) {
        if (entry is Map<String, Object?> && entry['id'] is String) {
          byId[entry['id']! as String] = entry;
        }
      }
    }
    return byId;
  }
}

/// One screen under check: the components by id, the catalog's cells and the
/// errors found.
class _Screen {
  _Screen(this._catalog, this._components, this._errors);

  final GenUiComponentCatalog _catalog;
  final Map<String, Map<String, Object?>> _components;
  final List<String> _errors;

  /// The cards placed in a cell, to count what the screen shows.
  final _placed = <Map<String, Object?>>[];

  CardFit? _fit(Map<String, Object?> component) =>
      _catalog.components[component['component']]?.fit;

  /// Whether the card is the one built for both rows: the plan unless it is
  /// compact, the shopping list, and the urgent heads-up.
  bool _isFullHeight(Map<String, Object?> component) =>
      switch (component['component']) {
        'PlanTimeline' => component['density'] != 'compact',
        'ShoppingList' => true,
        'HeadsUpCard' => component['variant'] == 'urgent',
        _ => false,
      };

  /// The ids [parent] lists, or null when it lists none.
  List<String>? _children(Map<String, Object?> parent) {
    final children = parent['children'];
    return children is List ? children.whereType<String>().toList() : null;
  }

  /// The component [id], or null after an error that it is not defined.
  Map<String, Object?>? _defined(String id, String parent) {
    final component = _components[id];
    if (component == null) {
      _errors.add('`$parent` lists the id "$id", which is not defined.');
    }
    return component;
  }

  int? _weight(Map<String, Object?> component) {
    final weight = component['weight'];
    return weight is num && weight == weight.truncate()
        ? weight.truncate()
        : null;
  }

  void check(Map<String, Object?> root) {
    if (root['component'] != 'Column') {
      _errors.add('The component with the id "root" must be a `Column`.');
      return;
    }
    final children = _children(root);
    if (children == null) {
      _errors.add('The root `Column` must list its children by id.');
      return;
    }
    final footers = <String>[];
    final rows = <String>[];
    for (final id in children) {
      final child = _defined(id, 'root');
      if (child == null) continue;
      if (child['component'] == LayoutValidator._footer) {
        footers.add(id);
      } else if (child['component'] == 'Row') {
        rows.add(id);
      } else {
        _errors.add(
          'The root lists the ${child['component']} "$id" directly. Put every '
          'card in a `Row`.',
        );
      }
    }
    _checkFooter(root, children, footers);
    _checkRows(rows);
    _checkCounts();
  }

  void _checkFooter(
    Map<String, Object?> root,
    List<String> children,
    List<String> footers,
  ) {
    final urgent = _components.values.any(
      (c) => c['component'] == 'HeadsUpCard' && c['variant'] == 'urgent',
    );
    if (urgent) {
      if (footers.isNotEmpty) {
        _errors.add(
          'A screen with an urgent `HeadsUpCard` has no `ActionChips`: remove '
          '"${footers.first}" from the root.',
        );
      }
      return;
    }
    if (footers.length != 1) {
      _errors.add(
        'The root must list exactly one `ActionChips`, as its last child. It '
        'lists ${footers.length}.',
      );
    } else if (children.last != footers.single) {
      _errors.add(
        'The `ActionChips` "${footers.single}" must be the last child of the '
        'root.',
      );
    }
  }

  void _checkRows(List<String> rowIds) {
    final rows = {
      for (final id in rowIds) id: _children(_components[id]!),
    };
    for (final MapEntry(:key, :value) in rows.entries) {
      if (value == null || value.isEmpty) {
        _errors.add('The `Row` "$key" must list its cards by id.');
      }
    }
    final usable = {
      for (final MapEntry(:key, :value) in rows.entries)
        if (value != null && value.isNotEmpty) key: value,
    };
    if (usable.isEmpty) {
      _errors.add('The screen has no `Row` of cards.');
      return;
    }
    final tall = usable.entries.where((e) => _holdsTall(e.value)).toList();
    if (tall.isNotEmpty) {
      if (usable.length != 1) {
        _errors.add(
          'A screen with a full height card has a single `Row` with the whole '
          'area. It has ${usable.length} rows.',
        );
      }
      _checkTallRow(tall.first.key, tall.first.value);
      return;
    }
    if (usable.length > gridRows) {
      _errors.add(
        'A screen without a full height card has at most two `Row`s, one for '
        'each row of the grid. It has ${usable.length}.',
      );
    }
    for (final MapEntry(:key, :value) in usable.entries) {
      _checkHalfRow(key, value);
    }
  }

  /// Whether a row has the whole area: a full height card or a band in it.
  bool _holdsTall(List<String> ids) => ids.any((id) {
    final child = _components[id];
    return child != null &&
        (child['component'] == 'Column' || _isFullHeight(child));
  });

  /// Checks a row of half tall cards that spans [target] columns: all 12 of
  /// the grid, or what a `Column` beside a full height card leaves.
  void _checkHalfRow(String id, List<String> ids, {int target = gridColumns}) {
    var total = 0;
    for (final cardId in ids) {
      final card = _defined(cardId, id);
      if (card == null) continue;
      final span = _checkCard(cardId, card, rows: 1, weight: _weight(card));
      total += span ?? 0;
    }
    _checkSum(id, ids.length, total, target);
  }

  void _checkTallRow(String id, List<String> ids) {
    var total = 0;
    var tall = 0;
    for (final childId in ids) {
      final child = _defined(childId, id);
      if (child == null) continue;
      if (child['component'] == 'Column') {
        total += _checkBand(childId, child);
      } else if (_isFullHeight(child)) {
        tall++;
        total +=
            _checkCard(childId, child, rows: 2, weight: _weight(child)) ?? 0;
      } else {
        _errors.add(
          'The ${child['component']} "$childId" is directly in the `Row` of a '
          'screen with a full height card. Put it in a `Column`, and give that '
          '`Column` the `weight` of the columns it spans.',
        );
        total += _weight(child) ?? 0;
      }
    }
    if (tall == 0) {
      _errors.add(
        'The `Row` "$id" holds `Column`s but no full height card. `Column`s '
        'are only for a screen with a full height card; otherwise put the '
        'cards in two `Row`s.',
      );
    } else if (tall > 1) {
      _errors.add(
        'The `Row` "$id" holds $tall full height cards. It holds exactly one.',
      );
    }
    _checkSum(id, ids.length, total);
  }

  /// Checks a band and returns the columns it spans: its `weight`, or what the
  /// first of its cards is built for.
  int _checkBand(String id, Map<String, Object?> band) {
    final ids = _children(band) ?? const <String>[];
    if (ids.any((child) => _components[child]?['component'] == 'Row')) {
      return _checkRest(id, band, ids);
    }
    final first = [
      for (final cardId in ids.take(1))
        if (_components[cardId] case final card? when _fit(card) != null)
          _defaultSpan(_fit(card)!, 1),
    ].firstOrNull;
    final span = _weight(band) ?? first ?? 0;
    if (ids.isEmpty || ids.length > 2) {
      _errors.add(
        'The `Column` "$id" holds ${ids.length} cards. It holds one or two, '
        'one above the other.',
      );
    }
    for (final cardId in ids) {
      final card = _defined(cardId, id);
      if (card == null) continue;
      _checkCard(cardId, card, rows: 1, weight: span);
    }
    return span;
  }

  /// Checks a `Column` of one or two `Row`s beside a full height card, and
  /// returns the columns it spans: its `weight`, or what its first row adds up
  /// to. Each row adds up to that, like a row of the whole grid adds up to 12.
  int _checkRest(String id, Map<String, Object?> rest, List<String> ids) {
    final rows = <String, List<String>>{};
    for (final childId in ids) {
      final child = _defined(childId, id);
      if (child == null) continue;
      final cards = child['component'] == 'Row' ? _children(child) : null;
      if (cards == null || cards.isEmpty) {
        _errors.add(
          'The `Column` "$id" mixes rows and cards, or holds a `Row` with no '
          'cards. It holds only `Row`s of cards here.',
        );
      } else {
        rows[childId] = cards;
      }
    }
    if (rows.length > gridRows) {
      _errors.add(
        'The `Column` "$id" holds ${rows.length} rows. It holds at most two, '
        'one for each row of the grid.',
      );
    }
    final firstSum = rows.values.firstOrNull
        ?.map(_spanOf)
        .fold<int>(0, (a, b) => a + b);
    final target = _weight(rest) ?? firstSum ?? 0;
    for (final MapEntry(:key, :value) in rows.entries) {
      _checkHalfRow(key, value, target: target);
    }
    return target;
  }

  /// The columns the card [id] spans in a half tall cell, as it is checked.
  int _spanOf(String id) {
    final card = _components[id];
    final fit = card == null ? null : _fit(card);
    if (card == null || fit == null) return 0;
    return _weight(card) ?? _defaultSpan(fit, 1);
  }

  /// The columns a card with no `weight` spans: what it is best built for in a
  /// cell [rows] tall. The frontend draws it the same way.
  int _defaultSpan(CardFit fit, int rows) => fit.cells
      .firstWhere((cell) => cell.rows == rows, orElse: () => fit.best)
      .columns;

  /// Checks a card at [weight] columns in a cell [rows] tall and returns the
  /// columns it spans. A card with no weight spans what it is best built for.
  int? _checkCard(
    String id,
    Map<String, Object?> card, {
    required int rows,
    required int? weight,
  }) {
    final name = card['component'];
    final fit = _fit(card);
    if (fit == null) {
      _errors.add(
        'The $name "$id" cannot be placed in a `Row`: only cards can. Use a '
        'card of the catalog.',
      );
      return weight;
    }
    _placed.add(card);
    if (_isFullHeight(card) && rows != 2) {
      _errors.add(
        'The $name "$id" is a full height card: it goes alone in the `Row` of '
        'a screen with a full height card, not in a half tall cell.',
      );
      return weight;
    }
    final span = weight ?? _defaultSpan(fit, rows);
    if (!fit.fits(span, rows)) {
      _errors.add(
        'The $name "$id" has weight $span, but ${_built(name, fit, rows)}',
      );
    }
    return span;
  }

  String _built(Object? name, CardFit fit, int rows) {
    final spans = [
      for (final cell in fit.cells)
        if (cell.rows == rows) cell.columns,
    ];
    final height = rows == 2 ? 'full height' : 'half tall';
    return spans.isEmpty
        ? '$name is not built for a $height cell.'
        : '$name is built for ${spans.join(', ')} of 12 columns, $height.';
  }

  void _checkSum(String id, int count, int total, [int target = gridColumns]) {
    if (count > 3) {
      _errors.add('The `Row` "$id" holds $count cards. It holds at most 3.');
    }
    if (total != target) {
      final example = target == gridColumns
          ? ', for example ${LayoutValidator._rowSums}'
          : ', the columns of the `Column` it is in';
      _errors.add(
        'The weights of the `Row` "$id" add up to $total. They must add up to '
        'exactly $target$example.',
      );
    }
  }

  void _checkCounts() {
    int count(String name) =>
        _placed.where((c) => c['component'] == name).length;
    for (final name in ['HeadsUpCard', 'ChangeSummary']) {
      if (count(name) > 1) _errors.add('There is at most one `$name`.');
    }
    if (_placed.length > LayoutValidator._maxCards) {
      _errors.add(
        'The screen has ${_placed.length} cards. It holds at most '
        '${LayoutValidator._maxCards}.',
      );
    }
  }
}
