import 'dart:convert';
import 'dart:math' as math;

import 'package:home_catalog/home_catalog.dart';

/// Cards to add to a screen the model's own cards leave short, given the ids of
/// the devices it already shows. See [LayoutComposer.compose].
typedef FillCards =
    List<Map<String, Object?>> Function(Set<String> shownDeviceIds);

/// {@template layout_composer}
/// Packs the cards of a reply onto the panel grid, whatever arrangement the
/// model wrote for them.
/// {@endtemplate}
///
/// The model is good at choosing and ranking cards and bad at adding up
/// columns: a row of cards has to span exactly 12, from the few spans each
/// card is built for. So when its arrangement is off the grid, this keeps its
/// cards, in its order, and lays them out again. Nothing is invented: a card
/// the grid has no room for is left out, last ranked first, and a card keeps
/// every prop it was sent but its `weight`.
///
/// What it builds is what `LayoutValidator` accepts and the frontend draws, in
/// one of the two shapes of the layout prompt:
///
/// - two rows of up to three half tall cards, each row spanning 12; or
/// - a full height card, and beside it one `Column` of up to two such rows
///   spanning what the card leaves.
///
/// Only one card is full height. When several are, the most urgent keeps it (an
/// urgent heads-up, then the shopping list, then the plan) and the others lose
/// what makes them tall: a plan becomes compact, a heads-up stops being urgent,
/// and a second list is left out.
class LayoutComposer {
  /// {@macro layout_composer}
  ///
  /// Creates a composer that reads the cells of [catalog].
  LayoutComposer(GenUiComponentCatalog catalog) : _catalog = catalog;

  final GenUiComponentCatalog _catalog;

  // The prompt instructs the LLM to fence A2UI messages with ```json ... ```.
  static final _fenceRegExp = RegExp(r'```json\b(.*?)```', dotAll: true);

  static const _footer = 'ActionChips';

  /// The reply with its cards laid out on the grid, or null when it holds no
  /// screen to lay out: no components, no `root`, or no card in it.
  ///
  /// When the model's own cards cannot fill the grid, [fill] is asked for cards
  /// to add. It is given the ids of the devices the reply already shows, and
  /// returns `DeviceCard`s for others. Only as many are used as the grid needs,
  /// and they come after every card the model sent: the model's choice is never
  /// given up for them.
  String? compose(String reply, {FillCards? fill}) {
    final messages = <Map<String, Object?>>[];
    final components = <String, Map<String, Object?>>{};
    String? surfaceId;
    for (final match in _fenceRegExp.allMatches(reply)) {
      final Object? decoded;
      try {
        decoded = jsonDecode(match.group(1)!);
      } on FormatException {
        continue;
      }
      if (decoded is! Map<String, Object?>) continue;
      messages.add(decoded);
      final update = decoded['updateComponents'];
      if (update is! Map<String, Object?>) continue;
      surfaceId ??= update['surfaceId'] as String?;
      for (final entry in update['components'] as List? ?? const []) {
        if (entry is Map<String, Object?> && entry['id'] is String) {
          components[entry['id']! as String] = {...entry};
        }
      }
    }
    final root = components['root'];
    if (root == null || surfaceId == null) return null;

    final order = _readingOrder(components, root);
    final footer = order.footer;
    final cards = [for (final id in order.cards) components[id]!];
    final shown = {
      for (final card in cards)
        if (card['component'] == 'DeviceCard' && card['deviceId'] is String)
          card['deviceId']! as String,
    };
    final screen = _Screen(
      _catalog,
      cards,
      fill == null ? const [] : fill(shown),
    ).pack();
    if (screen == null) return null;

    final built = <Map<String, Object?>>[
      ...screen.layout,
      ...screen.cards,
      if (footer != null && !screen.urgent) components[footer]!,
    ];
    final rootChildren = [
      ...screen.rootChildren,
      if (footer != null && !screen.urgent) footer,
    ];
    final update = <String, Object?>{
      'version': _version(messages),
      'updateComponents': {
        'surfaceId': surfaceId,
        'components': [
          {
            ...root,
            'children': rootChildren,
          },
          ...built,
        ],
      },
    };

    var placed = false;
    final out = <String>[];
    for (final message in messages) {
      if (message['updateComponents'] != null) {
        if (!placed) out.add(_fence(update));
        placed = true;
      } else {
        out.add(_fence(message));
      }
    }
    return out.join('\n');
  }

  String _version(List<Map<String, Object?>> messages) =>
      messages.map((m) => m['version']).whereType<String>().firstOrNull ??
      'v0.9';

  String _fence(Map<String, Object?> message) =>
      '```json\n${jsonEncode(message)}\n```';

  /// The ids of the cards below `root`, in the order the model wrote them
  /// (rows left to right, top to bottom), and the `ActionChips` it sent.
  ({List<String> cards, String? footer}) _readingOrder(
    Map<String, Map<String, Object?>> components,
    Map<String, Object?> root,
  ) {
    final cards = <String>[];
    String? footer;
    final seen = <String>{};
    void walk(String id) {
      final component = components[id];
      if (component == null || !seen.add(id)) return;
      if (component['component'] == _footer) {
        footer ??= id;
      } else if (_catalog.components[component['component']]?.fit != null) {
        cards.add(id);
      } else {
        final children = component['children'];
        if (children is List) children.whereType<String>().forEach(walk);
      }
    }

    final children = root['children'];
    if (children is List) children.whereType<String>().forEach(walk);
    return (cards: cards, footer: footer);
  }
}

/// The most cards on one half tall row.
const _perRow = 3;

/// A card as the packer sees it: its component and the spans it is built for.
class _Card {
  _Card(this.component, this.fit);

  final Map<String, Object?> component;
  final CardFit fit;

  String get id => component['id']! as String;

  /// The spans of a half tall cell, best first.
  List<int> get spans => [
    for (final cell in fit.cells)
      if (!cell.isFullHeight) cell.columns,
  ];

  int get best => spans.isEmpty ? 0 : spans.first;

  /// Whether the card leads the screen, so it goes in the top row: a heads-up
  /// and the summary of a request.
  bool get isLead =>
      component['component'] == 'ChangeSummary' ||
      component['component'] == 'HeadsUpCard';
}

/// A row of cards and the span each one takes.
class _Row {
  _Row(this.cards, this.spans);

  final List<_Card> cards;
  final List<int> spans;
}

/// What a screen is made of once packed.
class _Packed {
  _Packed({
    required this.layout,
    required this.cards,
    required this.rootChildren,
    required this.urgent,
  });

  /// The `Row`s and `Column`s of the grid.
  final List<Map<String, Object?>> layout;

  /// The cards, each with its `weight`.
  final List<Map<String, Object?>> cards;

  /// The ids the root lists before the chips.
  final List<String> rootChildren;

  /// Whether the screen has an urgent heads-up, which has no chips.
  final bool urgent;
}

/// A screen's cards read against the catalog, with the fillers that may pad it.
class _Screen {
  _Screen(
    GenUiComponentCatalog catalog,
    List<Map<String, Object?>> cards,
    List<Map<String, Object?>> fillers,
  ) : _cards = _read(catalog, cards),
      _fillers = _read(catalog, fillers);

  static List<_Card> _read(
    GenUiComponentCatalog catalog,
    List<Map<String, Object?>> cards,
  ) => [
    for (final card in cards)
      if (catalog.components[card['component']]?.fit case final fit?)
        _Card({...card}, fit),
  ];

  final List<_Card> _cards;

  /// Cards that may be added to fill a gap, after every card of the model.
  final List<_Card> _fillers;

  /// Whether a card is built for both rows as it was sent: the plan unless it
  /// is compact, the shopping list, and the urgent heads-up.
  static bool _isFullHeight(Map<String, Object?> card) =>
      switch (card['component']) {
        'PlanTimeline' => card['density'] != 'compact',
        'ShoppingList' => true,
        'HeadsUpCard' => card['variant'] == 'urgent',
        _ => false,
      };

  /// How urgent a full height card is: the lower, the sooner it keeps the tall
  /// cell.
  static int _priority(Map<String, Object?> card) =>
      switch (card['component']) {
        'HeadsUpCard' => 0,
        'ShoppingList' => 1,
        _ => 2,
      };

  _Packed? pack() {
    if (_cards.isEmpty) return null;
    final tall = _cards.where((c) => _isFullHeight(c.component)).toList()
      ..sort(
        (a, b) => _priority(a.component).compareTo(_priority(b.component)),
      );
    final winner = tall.firstOrNull;
    final half = <_Card>[];
    for (final card in _cards) {
      if (identical(card, winner)) continue;
      if (_isFullHeight(card.component)) {
        // It lost the tall cell: draw it for a half tall one, or leave it out
        // when it has none.
        if (!_demote(card)) continue;
      }
      half.add(card);
    }

    if (winner == null) return _twoRows(half);
    return _tallAndRest(winner, half);
  }

  /// Makes a full height card half tall, and says whether it could be.
  bool _demote(_Card card) {
    switch (card.component['component']) {
      case 'PlanTimeline':
        card.component['density'] = 'compact';
      case 'HeadsUpCard':
        card.component['variant'] = 'headsUp';
      default:
        return false;
    }
    return card.spans.isNotEmpty;
  }

  _Packed _twoRows(List<_Card> half) {
    final rows = _tile(half, gridColumns) ?? const <_Row>[];
    final layout = <Map<String, Object?>>[];
    final ids = <String>[];
    for (final (i, row) in rows.indexed) {
      final id = 'grid_row_${i + 1}';
      ids.add(id);
      layout.add({
        'id': id,
        'component': 'Row',
        'children': [for (final card in row.cards) card.id],
      });
    }
    return _Packed(
      layout: layout,
      cards: _weighted(rows),
      rootChildren: ids,
      urgent: false,
    );
  }

  _Packed _tallAndRest(_Card tall, List<_Card> half) {
    final cell = tall.fit.cells.firstWhere((c) => c.isFullHeight);
    final rest = gridColumns - cell.columns;
    final rows = _tile(half, rest) ?? const <_Row>[];
    final restRows = <Map<String, Object?>>[
      for (final (i, row) in rows.indexed)
        {
          'id': 'grid_rest_row_${i + 1}',
          'component': 'Row',
          'children': [for (final card in row.cards) card.id],
        },
    ];
    final layout = <Map<String, Object?>>[
      {
        'id': 'grid_body',
        'component': 'Row',
        'children': [tall.id, if (rows.isNotEmpty) 'grid_rest'],
      },
      if (rows.isNotEmpty)
        {
          'id': 'grid_rest',
          'component': 'Column',
          'weight': rest,
          'children': [for (final row in restRows) row['id']],
        },
      ...restRows,
    ];
    return _Packed(
      layout: layout,
      cards: [
        {...tall.component, 'weight': cell.columns},
        ..._weighted(rows),
      ],
      rootChildren: ['grid_body'],
      urgent:
          tall.component['component'] == 'HeadsUpCard' &&
          tall.component['variant'] == 'urgent',
    );
  }

  List<Map<String, Object?>> _weighted(List<_Row> rows) => [
    for (final row in rows)
      for (final (i, card) in row.cards.indexed)
        {...card.component, 'weight': row.spans[i]},
  ];

  /// Fills up to two rows spanning [width] with [model]'s cards, adding the
  /// fillers it takes, or null when not even one row can be filled.
  ///
  /// The model's choice comes first. It keeps every card it can, and a card is
  /// only left out, the last ranked first, when no layout holds it. Fillers are
  /// added only when the cards leave the grid short, as few as it takes, and
  /// two rows are preferred to one.
  List<_Row>? _tile(List<_Card> model, int width) {
    final usable = [
      for (final card in model)
        if (card.spans.isNotEmpty) card,
    ];
    final n = math.min(usable.length, _most);
    // From all the cards to none, dropping the last ranked first: the highest
    // bit of the mask is the first card.
    for (var mask = (1 << n) - 1; mask >= 0; mask--) {
      final chosen = [
        for (var i = 0; i < n; i++)
          if (mask & (1 << (n - 1 - i)) != 0) usable[i],
      ];
      for (final twoRows in const [true, false]) {
        final room = (twoRows ? gridRows : 1) * _perRow;
        final most = math.min(_fillers.length, room - chosen.length);
        for (var extra = 0; extra <= most; extra++) {
          final cards = [...chosen, ..._fillers.take(extra)];
          if (cards.isEmpty || (twoRows && cards.length < 2)) continue;
          final rows = _arrange(cards, width, twoRows: twoRows);
          if (rows != null) return rows;
        }
      }
    }
    return null;
  }

  /// The most of the model's cards looked at: the grid holds six.
  static const _most = 8;

  /// Lays [cards] out in two rows that each span [width], or in one, trying
  /// the order they were sent in first and then every other.
  List<_Row>? _arrange(
    List<_Card> cards,
    int width, {
    required bool twoRows,
  }) {
    final rows = twoRows ? gridRows : 1;
    var least = 0;
    var most = 0;
    for (final card in cards) {
      least += card.spans.reduce(math.min);
      most += card.spans.reduce(math.max);
    }
    if (least > rows * width || most < rows * width) return null;
    for (final order in _orders(cards.length)) {
      final ordered = [for (final i in order) cards[i]];
      final plan = twoRows ? _split(ordered, width) : _oneRow(ordered, width);
      if (plan != null) return plan;
    }
    return null;
  }

  /// Every order of [length] positions, the order they were sent in first.
  Iterable<List<int>> _orders(int length) sync* {
    final used = List.filled(length, false);
    final order = <int>[];
    Iterable<List<int>> from() sync* {
      if (order.length == length) {
        yield [...order];
        return;
      }
      for (var i = 0; i < length; i++) {
        if (used[i]) continue;
        used[i] = true;
        order.add(i);
        yield* from();
        order.removeLast();
        used[i] = false;
      }
    }

    yield* from();
  }

  /// Splits [cards] in two rows that each span [width], the cards that lead
  /// the screen in the top one.
  List<_Row>? _split(List<_Card> cards, int width) {
    final longest = math.min(_perRow, cards.length - 1);
    for (var k = longest; k >= 1; k--) {
      final top = cards.sublist(0, k);
      final bottom = cards.sublist(k);
      if (bottom.length > _perRow || bottom.any((card) => card.isLead)) {
        continue;
      }
      final topSpans = _assign(top, width);
      final bottomSpans = topSpans == null ? null : _assign(bottom, width);
      if (topSpans != null && bottomSpans != null) {
        return [_Row(top, topSpans), _Row(bottom, bottomSpans)];
      }
    }
    return null;
  }

  List<_Row>? _oneRow(List<_Card> cards, int width) {
    if (cards.length > _perRow) return null;
    final spans = _assign(cards, width);
    return spans == null ? null : [_Row(cards, spans)];
  }

  /// The spans that make [cards] fill [width], as close to what each is best
  /// built for as it can, or null when none do.
  List<int>? _assign(List<_Card> cards, int width) {
    List<int>? best;
    var bestCost = 1 << 30;
    void walk(int i, int left, List<int> chosen, int cost) {
      if (i == cards.length) {
        if (left == 0 && cost < bestCost) {
          best = [...chosen];
          bestCost = cost;
        }
        return;
      }
      for (final span in cards[i].spans) {
        if (span > left) continue;
        chosen.add(span);
        walk(i + 1, left - span, chosen, cost + (span - cards[i].best).abs());
        chosen.removeLast();
      }
    }

    walk(0, width, [], 0);
    return best;
  }
}
