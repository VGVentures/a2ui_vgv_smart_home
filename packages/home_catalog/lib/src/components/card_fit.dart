import 'package:meta/meta.dart';

/// The columns of the panel grid. A card is placed by how many it spans.
const int gridColumns = 12;

/// The rows of the panel grid. A card is half tall (one row) or full height
/// (both rows).
const int gridRows = 2;

/// The gap between cells, in logical pixels.
const double gridGutter = 24;

/// The width of the card area, in logical pixels.
const double gridAreaWidth = 1104;

/// The height of one row, in logical pixels.
const double gridRowHeight = 260;

/// {@template grid_cell}
/// One cell of the panel grid, by the columns it spans and the rows it takes.
///
/// The area is 12 columns by 2 rows. A cell is `columns` wide and either one
/// row (half tall) or both (full height). A cell shorter than one row does not
/// exist: no card is built for it.
/// {@endtemplate}
@immutable
class GridCell {
  /// {@macro grid_cell}
  ///
  /// Spans [columns] and takes [rows].
  const GridCell(this.columns, this.rows)
    : assert(columns > 0 && columns <= gridColumns, 'columns out of the grid'),
      assert(rows > 0 && rows <= gridRows, 'rows out of the grid');

  /// How many of the [gridColumns] the cell spans.
  final int columns;

  /// How many of the [gridRows] the cell takes: 1 is half tall, 2 is full
  /// height.
  final int rows;

  /// Whether the cell has both rows.
  bool get isFullHeight => rows == gridRows;

  /// The cell's width in the card area, in logical pixels.
  double get width => widthOf(columns);

  /// The cell's height in the card area, in logical pixels.
  double get height => rows * gridRowHeight + (rows - 1) * gridGutter;

  /// The width of a cell that spans [columns], in logical pixels.
  ///
  /// A column is the area's width plus one gutter, over [gridColumns], and the
  /// cell gives the last gutter back: 5 columns are 446, 7 are 634.
  static double widthOf(int columns) =>
      (gridAreaWidth + gridGutter) * columns / gridColumns - gridGutter;

  /// The cell as the prompt says it, in proportions: "5 of 12 columns, half
  /// tall" or "8 of 12 columns, full height".
  String get label =>
      '$columns of $gridColumns columns, '
      '${isFullHeight ? 'full height' : 'half tall'}';

  @override
  bool operator ==(Object other) =>
      other is GridCell && other.columns == columns && other.rows == rows;

  @override
  int get hashCode => Object.hash(columns, rows);

  @override
  String toString() => label;
}

/// {@template card_fit}
/// Which cells of the grid a component is built for.
///
/// The component draws well in [best] and in each of [also], and in no other
/// cell. It is the one place the size of a card is written down: the layout
/// prompt is rendered from it, the backend checks a reply against it, and the
/// frontend tests draw every component in every cell it lists. The sizes are
/// the ones on the Figma component catalog.
/// {@endtemplate}
@immutable
class CardFit {
  /// {@macro card_fit}
  ///
  /// The component is built best for [best].
  const CardFit({required this.best, this.also = const [], this.note});

  /// The cell the component is made for. The model picks it first.
  final GridCell best;

  /// Other cells it is also drawn for.
  final List<GridCell> also;

  /// When each cell applies, if the component has more than one.
  final String? note;

  /// Every cell it fits, [best] first.
  List<GridCell> get cells => [best, ...also];

  /// Whether the component is built for a cell [columns] wide and [rows] tall.
  bool fits(int columns, int rows) =>
      cells.any((cell) => cell.columns == columns && cell.rows == rows);

  /// The fit as one line of the prompt.
  String describe() {
    final buffer = StringBuffer('best ${best.label}');
    if (also.isNotEmpty) {
      buffer.write('; also ${also.map((cell) => cell.label).join('; ')}');
    }
    if (note != null) buffer.write('. $note');
    return buffer.toString();
  }
}
