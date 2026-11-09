import 'package:app_ui/app_ui.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../helpers/pump_component.dart';

const _four = [
  PlanEntry(
    time: '6:00 PM',
    title: 'Preheat oven',
    detail: '400 °F',
    icon: 'oven',
  ),
  PlanEntry(time: '7:00 PM', title: 'Guests arrive', icon: 'guests'),
  PlanEntry(time: '7:30 PM', title: 'Rain', icon: 'rain'),
  PlanEntry(time: '8:00 PM', title: 'Charge', icon: 'car'),
  PlanEntry(time: '9:00 PM', title: 'Fifth', icon: 'unknown'),
];

Widget _in(Size size, Widget child) =>
    SizedBox(width: size.width, height: size.height, child: child);

const _tall = Size(352, 544);
const _short = Size(352, 260);

void main() {
  group(PlanTimeline, () {
    testWidgets('a tall cell shows header, tag, icon bubbles and detail', (
      tester,
    ) async {
      await tester.pumpComponent(
        _in(
          _tall,
          const PlanTimeline(
            title: "Tonight's plan",
            subtitle: 'Friday, Oct 2',
            tag: StatusTag(label: 'Now 4:30'),
            entries: _four,
          ),
        ),
      );

      expect(find.text("Tonight's plan"), findsOneWidget);
      expect(find.text('Friday, Oct 2'), findsOneWidget);
      expect(find.byType(StatusTag), findsOneWidget);
      expect(find.text('400 °F'), findsOneWidget);
      expect(find.byIcon(AppIcons.byName('oven')), findsOneWidget);
      // Four rows at most: the fifth entry is dropped.
      expect(find.text('Charge'), findsOneWidget);
      expect(find.text('Fifth'), findsNothing);
      expect(find.text('6:00'), findsOneWidget);
      expect(find.text('PM'), findsNWidgets(4));
    });

    testWidgets('a tall cell draws icons whatever the density says', (
      tester,
    ) async {
      await tester.pumpComponent(
        _in(
          _tall,
          const PlanTimeline(
            density: PlanDensity.compact,
            title: 'Tonight',
            entries: [
              PlanEntry(time: '7:00 PM', title: 'Preheat the oven'),
              PlanEntry(time: '7:15 PM', title: 'Chill the wine'),
              PlanEntry(time: '7:30 PM', title: 'Dining scene'),
              PlanEntry(time: '7:45 PM', title: 'Marco brings the cake'),
            ],
          ),
        ),
      );

      expect(find.byIcon(AppIcons.byName('oven')), findsOneWidget);
      expect(find.byIcon(AppIcons.byName('wine')), findsOneWidget);
      expect(find.byIcon(AppIcons.byName('scene')), findsOneWidget);
      expect(find.byIcon(AppIcons.byName('cake')), findsOneWidget);
    });

    testWidgets('derives an icon from the words of an entry', (tester) async {
      await tester.pumpComponent(
        _in(
          const Size(352, 700),
          const PlanTimeline(
            entries: [
              PlanEntry(time: '1:00 PM', title: 'Serve', detail: '6 guests'),
              PlanEntry(time: '2:00 PM', title: 'Leave', detail: 'Drive'),
              PlanEntry(time: '3:00 PM', title: 'Lock up'),
              PlanEntry(time: '4:00 PM', title: 'Coffee'),
            ],
          ),
        ),
      );

      expect(find.byIcon(AppIcons.byName('guests')), findsOneWidget);
      expect(find.byIcon(AppIcons.byName('car')), findsOneWidget);
      expect(find.byIcon(AppIcons.byName('lock')), findsOneWidget);
      expect(find.byIcon(AppIcons.byName('coffee')), findsOneWidget);
    });

    testWidgets('falls back to a clock for an entry it cannot read', (
      tester,
    ) async {
      await tester.pumpComponent(
        _in(
          _tall,
          const PlanTimeline(
            entries: [PlanEntry(time: '1:00 PM', title: 'Mystery')],
          ),
        ),
      );

      expect(find.byIcon(AppIcons.byName('clock')), findsOneWidget);
    });

    testWidgets('spreads the rows over the whole height of the cell', (
      tester,
    ) async {
      await tester.pumpComponent(
        _in(
          const Size(352, 700),
          const PlanTimeline(
            title: 'Tonight',
            entries: [
              PlanEntry(time: '6:00 PM', title: 'One', icon: 'oven'),
              PlanEntry(time: '7:00 PM', title: 'Two', icon: 'cake'),
              PlanEntry(time: '8:00 PM', title: 'Three', icon: 'scene'),
            ],
          ),
        ),
      );

      final card = tester.getRect(find.byType(AppCard));
      final last = tester.getRect(find.text('Three'));
      // The last row ends near the bottom padding, not halfway down.
      expect(card.bottom - last.bottom, lessThan(100));
    });

    testWidgets('a short cell draws the compact rows, three at most', (
      tester,
    ) async {
      await tester.pumpComponent(
        _in(
          _short,
          const PlanTimeline(
            title: 'Tonight',
            subtitle: 'Hidden',
            entries: [
              PlanEntry(time: '7:00 PM', title: 'One', icon: 'oven'),
              PlanEntry(time: '7:45 PM', title: 'Two'),
              PlanEntry(time: '8:00 PM', title: 'Three'),
              PlanEntry(time: '9:00 PM', title: 'Four'),
            ],
          ),
        ),
      );

      expect(find.text('Hidden'), findsNothing);
      expect(find.byIcon(AppIcons.byName('oven')), findsNothing);
      expect(find.text('Three'), findsOneWidget);
      expect(find.text('Four'), findsNothing);
    });

    testWidgets('shows was, changed by, unchanged and detail lines', (
      tester,
    ) async {
      await tester.pumpComponent(
        _in(
          const Size(446, 260),
          const PlanTimeline(
            title: 'Tonight',
            entries: [
              PlanEntry(
                time: '7:00 PM',
                title: 'Moved',
                previousTime: '6:00',
                changedBy: 'Ana',
              ),
              PlanEntry(
                time: '7:45 PM',
                title: 'Same',
                status: PlanEntryStatus.unchanged,
              ),
              PlanEntry(
                time: '8:00 PM',
                title: 'Moved alone',
                previousTime: '7',
              ),
            ],
          ),
        ),
      );

      expect(find.text('was 6:00 · Ana'), findsOneWidget);
      expect(find.text('Unchanged'), findsOneWidget);
      expect(find.text('was 7'), findsOneWidget);
    });

    testWidgets('shows only changed by without a previous time', (
      tester,
    ) async {
      await tester.pumpComponent(
        const PlanTimeline(
          entries: [PlanEntry(time: '24:00', title: 'Late', changedBy: 'Ana')],
        ),
      );

      expect(find.text('Ana'), findsOneWidget);
      expect(find.text('24:00'), findsOneWidget);
    });

    testWidgets('an unbounded height honors the density', (tester) async {
      await tester.pumpComponent(
        const PlanTimeline(
          density: PlanDensity.compact,
          subtitle: 'Hidden',
          entries: [PlanEntry(time: '1:00 PM', title: 'One', icon: 'oven')],
        ),
      );

      expect(find.text('Hidden'), findsNothing);
      expect(find.byIcon(AppIcons.byName('oven')), findsNothing);
    });

    testWidgets('renders without a header', (tester) async {
      final time = ['1:00'].first;
      await tester.pumpComponent(
        PlanTimeline(
          entries: [PlanEntry(time: time, title: 'One')],
        ),
      );

      expect(find.text('One'), findsOneWidget);
    });

    testWidgets('lays out in a Row without bounded width', (tester) async {
      await tester.pumpComponent(
        const Row(
          children: [
            PlanTimeline(
              entries: [PlanEntry(time: '1:00 PM', title: 'One')],
            ),
          ],
        ),
      );

      expect(tester.takeException(), isNull);
    });

    test('maps names to densities and statuses', () {
      expect(PlanDensity.byName('compact'), PlanDensity.compact);
      expect(PlanDensity.byName(null), PlanDensity.detailed);
      expect(PlanEntryStatus.byName('unchanged'), PlanEntryStatus.unchanged);
      expect(PlanEntryStatus.byName('moved'), PlanEntryStatus.moved);
      expect(PlanEntryStatus.byName('new'), PlanEntryStatus.isNew);
      expect(PlanEntryStatus.byName('x'), isNull);
    });
  });
}
