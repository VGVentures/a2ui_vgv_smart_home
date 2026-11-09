import 'dart:math' as math;

import 'package:app_ui/app_ui.dart';
import 'package:flutter/widgets.dart';
import 'package:home_catalog/home_catalog.dart';
import 'package:home_frontend/src/a2ui/a2ui.dart';
import 'package:home_frontend/src/widgets/rebuild.dart';

/// The panel grid the model's `Row` and `Column` are drawn on.
///
/// The card area is 12 columns by 2 rows, the one on the Figma component
/// catalog. A card's width is the number of columns it spans, which is its
/// `weight`, and its height is one row, or both rows for the cards built for
/// them. Every card is drawn at exactly its cell and nothing is dropped: what
/// a screen may hold is checked on the backend, against the same
/// `GenUiComponent.fit` this reads its sizes from, before it is sent.
///
/// A screen is a root `Column` that holds the cards and ends with the
/// `ActionChips` footer:
///
/// - one `Row` or two, each of half height; or
/// - a single `Row` that holds a full height card. Its other children are
///   `Column`s, bands of up to two cards that share one span.
///
/// `ActionChips` is not a cell. It is the footer of the `Column` that holds it:
/// natural height, always last.
const String _footerType = 'ActionChips';

/// The props the renderer resolved for [node], read without subscribing.
ComponentProps _propsOf(ComponentNode<ComponentImplementation> node) =>
    ComponentProps(node.props.peek());

/// The children [node] was given, in order; a template is already expanded.
List<ComponentNode<ComponentImplementation>> _childrenOf(
  ComponentNode<ComponentImplementation> node,
) => _propsOf(node).children('children');

/// The columns [node] spans in a row of [count]: its own `weight`, when that
/// is a whole number of columns, then what its card is best built for, then an
/// even share.
int _span(ComponentNode<ComponentImplementation> node, int count) {
  final weight = _propsOf(node).value('weight');
  if (weight is int && weight >= 1 && weight <= gridColumns) return weight;
  // A `Column` of rows spans what its first row does.
  if (node.type == 'Column') {
    final first = _childrenOf(node).firstOrNull;
    if (first != null && first.type == 'Row') {
      final cards = _childrenOf(first);
      final spans = [for (final card in cards) _span(card, cards.length)];
      if (spans.isNotEmpty) {
        return math.min(gridColumns, spans.fold(0, (a, b) => a + b));
      }
    }
  }
  return _bestSpan(node) ?? math.max(1, gridColumns ~/ count);
}

int? _bestSpan(ComponentNode<ComponentImplementation> node, {int depth = 3}) {
  final fit = homeCatalog.components[node.type]?.fit;
  if (fit != null) return fit.best.columns;
  if (depth == 0) return null;
  for (final child in _childrenOf(node)) {
    final span = _bestSpan(child, depth: depth - 1);
    if (span != null) return span;
  }
  return null;
}

/// Whether the card [node] is built for both rows of the grid.
///
/// The plan is full height unless it is `density: compact`: the catalog lists
/// a cell of both rows for it, and the prop says which one the card is drawn
/// for.
bool _isFullHeightCard(ComponentNode<ComponentImplementation> node) {
  final props = _propsOf(node);
  return switch (node.type) {
    'PlanTimeline' => props.value('density') != 'compact',
    'ShoppingList' => true,
    _ => false,
  };
}

/// Whether [node] has the whole area: it is a full height card, or a `Row` that
/// holds one or a band, so it is as tall as the two rows and the gutter.
bool _isTall(ComponentNode<ComponentImplementation> node) {
  if (_isFullHeightCard(node)) return true;
  if (node.type != 'Row') return false;
  return _childrenOf(
    node,
  ).any((child) => child.type == 'Column' || _isFullHeightCard(child));
}

/// [nodes] and everything under them.
Iterable<ComponentNode<ComponentImplementation>> _withDescendants(
  Iterable<ComponentNode<ComponentImplementation>> nodes,
) sync* {
  for (final node in nodes) {
    yield node;
    yield* _withDescendants(_childrenOf(node));
  }
}

/// Rebuilds [builder] whenever the props of any of [nodes] change.
///
/// A node's props do not change when a child's do, but the grid reads the
/// `weight` and `variant` of the cards under it to place them, so the grid
/// listens to the cards itself.
class _Watching extends StatefulWidget {
  const _Watching({required this.nodes, required this.builder});

  final List<ComponentNode<ComponentImplementation>> nodes;
  final WidgetBuilder builder;

  @override
  State<_Watching> createState() => _WatchingState();
}

class _WatchingState extends State<_Watching> {
  final List<void Function()> _unsubscribes = [];

  @override
  void initState() {
    super.initState();
    _subscribe();
  }

  @override
  void didUpdateWidget(_Watching oldWidget) {
    super.didUpdateWidget(oldWidget);
    _unsubscribe();
    _subscribe();
  }

  @override
  void dispose() {
    _unsubscribe();
    super.dispose();
  }

  void _subscribe() {
    for (final node in widget.nodes) {
      var primed = false;
      final unsubscribe = node.props.subscribe((_) {
        if (primed) _changed();
      });
      primed = true;
      _unsubscribes.add(unsubscribe);
    }
  }

  void _unsubscribe() {
    for (final unsubscribe in _unsubscribes) {
      unsubscribe();
    }
    _unsubscribes.clear();
  }

  void _changed() => rebuild(this);

  @override
  Widget build(BuildContext context) => widget.builder(context);
}

/// The width of a cell that spans [span] columns, in a row that is [width]
/// wide and spans [columns] columns of the grid, holding [total] of them.
///
/// A row the width of the card area gives the Figma widths: 5 columns are 446,
/// 7 are 634. A row that holds fewer columns than it spans leaves the rest
/// empty rather than stretch its cards, and one that holds more is scaled to
/// fit rather than drop one.
double _cellWidth(double width, int span, int total, int columns) =>
    ((width + AppSpacing.gutter) * span / math.max(columns, total) -
            AppSpacing.gutter)
        .clamp(0, width);

/// Marks the cells of a `Row`, so a `Column` in one is a band and not the root
/// of the screen.
class _Cell extends InheritedWidget {
  const _Cell({required super.child});

  static bool isIn(BuildContext context) =>
      context.getInheritedWidgetOfExactType<_Cell>() != null;

  @override
  bool updateShouldNotify(_Cell oldWidget) => false;
}

/// How many columns of the grid the cell around a widget spans.
///
/// A `Row` in the cell of a `Column` that spans 7 columns lays its cards out
/// against those 7, not against all 12, so two rows beside a tall card keep
/// the proportions of the board.
class _Columns extends InheritedWidget {
  const _Columns({required this.count, required super.child});

  final int count;

  static int of(BuildContext context) =>
      context.dependOnInheritedWidgetOfExactType<_Columns>()?.count ??
      gridColumns;

  @override
  bool updateShouldNotify(_Columns oldWidget) => count != oldWidget.count;
}

/// [nodes] side by side, each as wide as the columns it spans.
Widget _row(
  List<ComponentNode<ComponentImplementation>> nodes,
  ChildWidgetBuilder buildChild,
) {
  final spans = [for (final node in nodes) _span(node, nodes.length)];
  final total = spans.fold(0, (sum, span) => sum + span);
  return LayoutBuilder(
    builder: (layoutContext, constraints) {
      final columns = _Columns.of(layoutContext);
      return _Cell(
        child: Row(
          crossAxisAlignment: constraints.hasBoundedHeight
              ? CrossAxisAlignment.stretch
              : CrossAxisAlignment.start,
          spacing: AppSpacing.gutter,
          children: [
            for (var i = 0; i < nodes.length; i++)
              _Columns(
                count: spans[i],
                child: SizedBox(
                  width: _cellWidth(
                    constraints.maxWidth,
                    spans[i],
                    total,
                    columns,
                  ),
                  child: buildChild(nodes[i]),
                ),
              ),
          ],
        ),
      );
    },
  );
}

/// The `Row` builder: cards side by side on the 12 column grid, each as wide
/// as the columns it spans.
Widget gridRowBuilder(
  BuildContext context,
  ComponentNode<ComponentImplementation> node,
  ComponentProps props,
  ChildWidgetBuilder buildChild,
) {
  final children = props.children('children');
  return _Watching(
    nodes: _withDescendants(children).toList(),
    builder: (_) => _row(children, buildChild),
  );
}

/// The `Column` builder.
///
/// At the root of the screen it stacks the rows of cards, each half the area
/// tall, or one row that has the whole area, with the `ActionChips` footer
/// below them. Inside a row it is a band: two cells of one row each, top to
/// bottom.
Widget gridColumnBuilder(
  BuildContext context,
  ComponentNode<ComponentImplementation> node,
  ComponentProps props,
  ChildWidgetBuilder buildChild,
) {
  final children = props.children('children');
  return _Watching(
    nodes: _withDescendants(children).toList(),
    builder: (_) => _column(children, buildChild),
  );
}

Widget _column(
  List<ComponentNode<ComponentImplementation>> children,
  ChildWidgetBuilder buildChild,
) {
  bool isFooter(ComponentNode<ComponentImplementation> n) =>
      n.type == _footerType;
  final cards = children.where((n) => !isFooter(n)).toList();
  final footer = children.where(isFooter).take(1).toList();
  return LayoutBuilder(
    builder: (layoutContext, constraints) {
      final bounded = constraints.hasBoundedHeight;
      if (_Cell.isIn(layoutContext)) {
        return _band(cards, buildChild, bounded: bounded);
      }
      return Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        mainAxisSize: bounded ? MainAxisSize.max : MainAxisSize.min,
        spacing: AppSpacing.gutter,
        children: [
          if (bounded)
            Expanded(child: _rows(cards, buildChild))
          else
            for (final card in cards) buildChild(card),
          for (final node in footer) buildChild(node),
          // The screen keeps the room of the chips row when it sends none, so
          // the cards do not grow into it.
          if (footer.isEmpty && bounded)
            const SizedBox(height: ActionPill.height),
        ],
      );
    },
  );
}

/// The rows of the screen: the area is two rows, so a row of half height is
/// one of the two and a row with the whole area is all of it. Rows stack from
/// the top, and a row that was not sent leaves its place empty.
Widget _rows(
  List<ComponentNode<ComponentImplementation>> nodes,
  ChildWidgetBuilder buildChild,
) {
  Widget row(ComponentNode<ComponentImplementation> node) => node.type == 'Row'
      ? buildChild(node)
      // A card sent without a row is a row of one, as wide as its own span.
      : _row([node], buildChild);
  if (nodes.any(_isTall)) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      spacing: AppSpacing.gutter,
      children: [for (final node in nodes) Expanded(child: row(node))],
    );
  }
  return Column(
    crossAxisAlignment: CrossAxisAlignment.stretch,
    spacing: AppSpacing.gutter,
    children: [
      for (var i = 0; i < math.max(gridRows, nodes.length); i++)
        Expanded(
          child: i < nodes.length ? row(nodes[i]) : const SizedBox.shrink(),
        ),
    ],
  );
}

/// A band: its cards one under the other, a row each, from the top. A band of
/// one card leaves the second row empty rather than stretch the card.
Widget _band(
  List<ComponentNode<ComponentImplementation>> nodes,
  ChildWidgetBuilder card, {
  required bool bounded,
}) {
  if (!bounded) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      mainAxisSize: MainAxisSize.min,
      spacing: AppSpacing.gutter,
      children: [for (final node in nodes) card(node)],
    );
  }
  return Column(
    crossAxisAlignment: CrossAxisAlignment.stretch,
    spacing: AppSpacing.gutter,
    children: [
      for (var i = 0; i < math.max(gridRows, nodes.length); i++)
        Expanded(
          child: i < nodes.length ? card(nodes[i]) : const SizedBox.shrink(),
        ),
    ],
  );
}
