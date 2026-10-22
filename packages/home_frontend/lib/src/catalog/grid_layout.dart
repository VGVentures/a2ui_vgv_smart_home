import 'dart:math' as math;

import 'package:app_ui/app_ui.dart';
import 'package:flutter/widgets.dart';
import 'package:home_catalog/home_catalog.dart';
import 'package:home_frontend/src/a2ui/a2ui.dart';

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

/// The columns [id] spans in a row of [count]: its own `weight`, when that is
/// a whole number of columns, then what its card is best built for, then an
/// even share.
int _span(CatalogItemContext context, String id, int count) {
  final component = context.getComponent(id);
  final weight = component?.properties['weight'];
  if (weight is int && weight >= 1 && weight <= gridColumns) return weight;
  // A `Column` of rows spans what its first row does.
  if (component?.type == 'Column') {
    final first =
        (_childIds(component!.properties) ?? const <String>[]).firstOrNull;
    if (first != null && context.getComponent(first)?.type == 'Row') {
      final cards =
          _childIds(context.getComponent(first)!.properties) ??
          const <String>[];
      final spans = [
        for (final card in cards) _span(context, card, cards.length),
      ];
      if (spans.isNotEmpty) {
        return math.min(gridColumns, spans.fold(0, (a, b) => a + b));
      }
    }
  }
  return _bestSpan(context, id) ?? math.max(1, gridColumns ~/ count);
}

int? _bestSpan(CatalogItemContext context, String id, {int depth = 3}) {
  final component = context.getComponent(id);
  if (component == null) return null;
  final fit = homeCatalog.components[component.type]?.fit;
  if (fit != null) return fit.best.columns;
  if (depth == 0) return null;
  for (final child in _childIds(component.properties) ?? const <String>[]) {
    final span = _bestSpan(context, child, depth: depth - 1);
    if (span != null) return span;
  }
  return null;
}

List<String>? _childIds(Object data) {
  if (data is! Map) return null;
  final children = data['children'];
  if (children is! List) return null;
  return children.whereType<String>().toList();
}

/// Whether the card [id] is built for both rows of the grid.
///
/// The plan is full height unless it is `density: compact`, and the heads-up
/// is full height only as `variant: urgent`: the catalog lists a cell of both
/// rows for each, and the prop says which one the card is drawn for.
bool _isFullHeightCard(CatalogItemContext context, String id) {
  final component = context.getComponent(id);
  if (component == null) return false;
  final properties = component.properties;
  return switch (component.type) {
    'PlanTimeline' => properties['density'] != 'compact',
    'HeadsUpCard' => properties['variant'] == 'urgent',
    'ShoppingList' => true,
    _ => false,
  };
}

/// Whether [id] has the whole area: it is a full height card, or a `Row` that
/// holds one or a band, so it is as tall as the two rows and the gutter.
bool _isTall(CatalogItemContext context, String id) {
  if (_isFullHeightCard(context, id)) return true;
  final component = context.getComponent(id);
  if (component?.type != 'Row') return false;
  return (_childIds(component!.properties) ?? const <String>[]).any(
    (child) =>
        context.getComponent(child)?.type == 'Column' ||
        _isFullHeightCard(context, child),
  );
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

/// [ids] side by side, each as wide as the columns it spans.
Widget _row(CatalogItemContext context, List<String> ids) {
  final spans = [for (final id in ids) _span(context, id, ids.length)];
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
            for (var i = 0; i < ids.length; i++)
              _Columns(
                count: spans[i],
                child: SizedBox(
                  width: _cellWidth(
                    constraints.maxWidth,
                    spans[i],
                    total,
                    columns,
                  ),
                  child: context.buildChild(ids[i], context.dataContext),
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
///
/// Children given as a template, not a list, keep the stock behavior.
Widget gridRowBuilder(CatalogItemContext context) {
  final ids = _childIds(context.data);
  if (ids == null) return BasicCatalogItems.row.widgetBuilder(context);
  return _row(context, ids);
}

/// The `Column` builder.
///
/// At the root of the screen it stacks the rows of cards, each half the area
/// tall, or one row that has the whole area, with the `ActionChips` footer
/// below them. Inside a row it is a band: two cells of one row each, top to
/// bottom.
///
/// Children given as a template, not a list, keep the stock behavior.
Widget gridColumnBuilder(CatalogItemContext context) {
  final ids = _childIds(context.data);
  if (ids == null) return BasicCatalogItems.column.widgetBuilder(context);
  bool isFooter(String id) => context.getComponent(id)?.type == _footerType;
  final cards = ids.where((id) => !isFooter(id)).toList();
  final footer = ids.where(isFooter).take(1).toList();
  return LayoutBuilder(
    builder: (layoutContext, constraints) {
      final bounded = constraints.hasBoundedHeight;
      if (_Cell.isIn(layoutContext)) {
        return _band(context, cards, bounded: bounded);
      }
      return Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        mainAxisSize: bounded ? MainAxisSize.max : MainAxisSize.min,
        spacing: AppSpacing.gutter,
        children: [
          if (bounded)
            Expanded(child: _rows(context, cards))
          else
            for (final id in cards) context.buildChild(id, context.dataContext),
          for (final id in footer) context.buildChild(id, context.dataContext),
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
Widget _rows(CatalogItemContext context, List<String> ids) {
  Widget row(String id) => context.getComponent(id)?.type == 'Row'
      ? context.buildChild(id, context.dataContext)
      // A card sent without a row is a row of one, as wide as its own span.
      : _row(context, [id]);
  if (ids.any((id) => _isTall(context, id))) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      spacing: AppSpacing.gutter,
      children: [for (final id in ids) Expanded(child: row(id))],
    );
  }
  return Column(
    crossAxisAlignment: CrossAxisAlignment.stretch,
    spacing: AppSpacing.gutter,
    children: [
      for (var i = 0; i < math.max(gridRows, ids.length); i++)
        Expanded(
          child: i < ids.length ? row(ids[i]) : const SizedBox.shrink(),
        ),
    ],
  );
}

/// A band: its cards one under the other, a row each, from the top. A band of
/// one card leaves the second row empty rather than stretch the card.
Widget _band(
  CatalogItemContext context,
  List<String> ids, {
  required bool bounded,
}) {
  Widget card(String id) => context.buildChild(id, context.dataContext);
  if (!bounded) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      mainAxisSize: MainAxisSize.min,
      spacing: AppSpacing.gutter,
      children: [for (final id in ids) card(id)],
    );
  }
  return Column(
    crossAxisAlignment: CrossAxisAlignment.stretch,
    spacing: AppSpacing.gutter,
    children: [
      for (var i = 0; i < math.max(gridRows, ids.length); i++)
        Expanded(
          child: i < ids.length ? card(ids[i]) : const SizedBox.shrink(),
        ),
    ],
  );
}
