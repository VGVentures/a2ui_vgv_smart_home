import 'package:home_catalog/home_catalog.dart';
import 'package:test/test.dart';

void main() {
  const five = GridCell(5, 1);

  group('GridCell', () {
    test('measures itself on the 12 column grid', () {
      // The sizes, in logical pixels, of the cells on the Figma component
      // catalog: what the renderer draws, never what the prompt says.
      const widths = {
        3: 258.0,
        4: 352.0,
        5: 446.0,
        7: 634.0,
        8: 728.0,
        12: 1104.0,
      };
      for (final entry in widths.entries) {
        expect(GridCell(entry.key, 1).width, entry.value);
      }
      expect(const GridCell(5, 1).height, 260);
      expect(const GridCell(5, 2).height, 544);
      expect(const GridCell(12, 2).isFullHeight, isTrue);
      expect(five.isFullHeight, isFalse);
    });

    test('rows of cards add up to the area', () {
      expect(GridCell.widthOf(gridColumns), gridAreaWidth);
      // 5 + 7 columns, and the gutter between them, is the whole width.
      expect(
        GridCell.widthOf(5) + gridGutter + GridCell.widthOf(7),
        gridAreaWidth,
      );
      expect(
        gridRows * gridRowHeight + gridGutter,
        const GridCell(1, 2).height,
      );
    });

    test('says itself for the prompt', () {
      expect(five.label, '5 of 12 columns, half tall');
      expect(five.toString(), five.label);
      expect(
        const GridCell(8, 2).label,
        '8 of 12 columns, full height',
      );
    });

    test('compares by value', () {
      expect(five, const GridCell(5, 1));
      expect(five.hashCode, const GridCell(5, 1).hashCode);
      expect(five, isNot(const GridCell(5, 2)));
      expect(five, isNot(const GridCell(4, 1)));
    });
  });

  group('CardFit', () {
    test('lists the best cell first', () {
      const fit = CardFit(best: five, also: [GridCell(4, 1)]);

      expect(fit.cells, [five, const GridCell(4, 1)]);
      expect(
        fit.describe(),
        'best 5 of 12 columns, half tall; also 4 of 12 columns, half tall',
      );
    });

    test('adds its note', () {
      const fit = CardFit(best: five, note: 'Drops the hero.');

      expect(
        fit.describe(),
        'best 5 of 12 columns, half tall. Drops the hero.',
      );
    });

    test('knows the cells it is built for', () {
      const fit = CardFit(best: five, also: [GridCell(4, 1)]);

      expect(fit.fits(5, 1), isTrue);
      expect(fit.fits(4, 1), isTrue);
      expect(fit.fits(5, 2), isFalse);
      expect(fit.fits(7, 1), isFalse);
    });
  });

  group('the catalog', () {
    final cards = {
      for (final c in homeCatalog.components.values)
        if (c.fit != null) c.name: c.fit!,
    };

    test('declares a fit for every home card, and only for them', () {
      expect(cards.keys.toSet(), {
        'CountdownCard',
        'PlanTimeline',
        'DeviceCard',
        'TripCard',
        'ChargeCard',
        'SceneCard',
        'HeadsUpCard',
        'ChangeSummary',
        'ShoppingList',
      });
    });

    test('sizes every card as the Figma component catalog does', () {
      List<String> cells(String card) => [
        for (final cell in cards[card]!.cells) '${cell.columns}x${cell.rows}',
      ];

      expect(cells('CountdownCard'), ['5x1', '4x1']);
      expect(cells('PlanTimeline'), ['4x2', '4x1', '5x1']);
      expect(cells('DeviceCard'), ['4x1', '3x1', '5x1']);
      expect(cells('TripCard'), ['7x1']);
      expect(cells('ChargeCard'), ['4x1', '5x1']);
      expect(cells('SceneCard'), ['5x1', '4x1']);
      expect(cells('HeadsUpCard'), ['7x1', '5x1', '8x2']);
      expect(cells('ChangeSummary'), ['8x1']);
      expect(cells('ShoppingList'), ['5x2']);
    });

    test('never lists a cell twice', () {
      for (final entry in cards.entries) {
        final cells = entry.value.cells;
        expect(cells.toSet(), hasLength(cells.length), reason: entry.key);
      }
    });

    test('only builds cards for cells inside the grid', () {
      for (final entry in cards.entries) {
        for (final cell in entry.value.cells) {
          expect(cell.columns, inInclusiveRange(1, gridColumns));
          expect(cell.rows, inInclusiveRange(1, gridRows));
        }
      }
    });

    test('has no half tall span that no other span completes to a row', () {
      final spans = {
        for (final fit in cards.values)
          for (final cell in fit.cells)
            if (!cell.isFullHeight) cell.columns,
      };
      for (final span in spans) {
        final completes =
            spans.any((other) => span + other == gridColumns) ||
            spans.any((a) => spans.any((b) => span + a + b == gridColumns));
        expect(completes, isTrue, reason: '$span columns');
      }
    });

    test('renders one line per card for the prompt', () {
      final rendered = renderCardFits(homeCatalog.components.values);

      expect(rendered.split('\n'), hasLength(cards.length));
      expect(
        rendered,
        contains(
          '- `DeviceCard`: best 4 of 12 columns, half tall; '
          'also 3 of 12 columns, half tall; 5 of 12 columns, half tall. '
          'Always half tall',
        ),
      );
      expect(rendered, isNot(contains('`Row`')));
      expect(rendered, isNot(contains('..')));
      for (final line in rendered.split('\n')) {
        expect(line, endsWith('.'));
      }
    });
  });
}
