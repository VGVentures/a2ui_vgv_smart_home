import 'package:app_ui/app_ui.dart';
import 'package:app_ui/src/widgets/glow_surface.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../helpers/load_fonts.dart';

/// The cells of the panel grid, in logical pixels: the card area is 1104 by
/// 544 with a 24 gutter, so a third is 352 wide, a half 540 and two thirds
/// 728; a row is 260 tall and a full height cell 544.
const _third = Size(352, 260);
const _half = Size(540, 260);
const _twoThirds = Size(728, 260);
const _wide = Size(1104, 260);
const _thirdTall = Size(352, 544);
const _halfTall = Size(540, 544);

Widget _device() => const DeviceCard(
  name: 'Upstairs Office',
  room: 'Entry',
  status: 'Heating to 70 °F · until 9 PM',
  icon: 'thermostat',
  tone: AppTone.climate,
  value: '68',
  unit: '°F',
  delta: '↑ from 66 °F',
  isActive: true,
  controlType: DeviceControlType.stepper,
);

Widget _alert() => HeadsUpCard(
  title: 'Rain starting in 20 min, and the garage door is open.',
  message: 'Garage door is open · Living room blinds are up',
  source: 'Weather',
  timestamp: 'Just now',
  actions: [
    HeadsUpActionData(
      label: 'Close garage when I leave',
      icon: 'garage',
      isPrimary: true,
      onPressed: () {},
    ),
    HeadsUpActionData(
      label: 'Close living room blinds',
      icon: 'blinds',
      onPressed: () {},
    ),
  ],
);

Widget _trip() => const TripCard(
  leaveBy: '4:50 PM',
  previousLeaveBy: '5:00 PM',
  tag: 'Updated just now',
  footer: TripFooter(
    text: 'Traffic building on Elm Ave, +10 min',
    icon: 'traffic',
    tone: TripFooterTone.warning,
  ),
  stops: [
    TripStop(
      icon: 'school',
      title: 'School pickup',
      subtitle: 'Lincoln Elementary',
      time: '5:15 PM',
    ),
    TripStop(
      icon: 'cake',
      title: 'Grab the cake',
      subtitle: 'Rise Bakery · ready',
      time: '5:40 PM',
    ),
    TripStop(
      icon: 'home',
      title: 'Home',
      subtitle: 'Rivera Home',
      time: '6:15 PM',
    ),
  ],
);

Widget _fivePlan() => const PlanTimeline(
  title: "Tonight's plan",
  subtitle: 'Saturday, Oct 10',
  tag: StatusTag(label: 'Now 4:30'),
  entries: [
    PlanEntry(
      time: '6:00 PM',
      title: 'Prep the rack',
      detail: 'Rack of lamb · 25 min at 400 °F',
      icon: 'restaurant',
    ),
    PlanEntry(
      time: '6:30 PM',
      title: 'Preheat the oven',
      detail: 'Oven · 400 °F for the roast',
      icon: 'oven',
    ),
    PlanEntry(
      time: '6:45 PM',
      title: 'Roast goes in',
      detail: 'Done at 7:10 PM',
      icon: 'flame',
    ),
    PlanEntry(
      time: '6:45 PM',
      title: 'Dining scene',
      detail: 'Dining Room lights and music',
      icon: 'scene',
    ),
    PlanEntry(
      time: '7:15 PM',
      title: 'Serve',
      detail: '6 confirmed',
      icon: 'guests',
    ),
  ],
);

Widget _plan({PlanDensity density = PlanDensity.detailed}) => PlanTimeline(
  title: "Tonight's plan",
  subtitle: 'Friday, Oct 2',
  density: density,
  tag: const StatusTag(label: 'Updated'),
  entries: const [
    PlanEntry(time: '4:30 PM', title: 'Pick up cake', icon: 'cake'),
    PlanEntry(
      time: '7:00 PM',
      title: 'Preheat oven',
      icon: 'oven',
      previousTime: '6:00',
      changedBy: 'Ana',
    ),
    PlanEntry(time: '7:45 PM', title: 'Guest scene', icon: 'scene'),
    PlanEntry(time: '8:00 PM', title: 'Guests arrive', icon: 'guests'),
    PlanEntry(time: '9:00 PM', title: 'Dessert', icon: 'restaurant'),
  ],
);

Widget _charge() => const ChargeCard(
  percent: 62,
  status: 'Plugged in',
  range: '190 mi range',
  summary: 'Enough for both stops',
  window: 'Charging tonight 9 PM – 6 AM',
  tag: 'Not charging',
);

Widget _scene() => const SceneCard(
  name: 'Dinner party scene',
  description: 'Dining Room · Starts 6:45 PM · 4 devices',
  settings: ['Pendants 40 %', 'Jazz on Nest Audio', '70 °F', 'Blinds half'],
);

Widget _event() => CountdownCard(
  startsAt: DateTime(2026, 10, 2, 19),
  now: () => DateTime(2026, 10, 2, 16, 30),
  tag: const StatusTag(label: 'Dinner party · 6 guests'),
  eyebrow: 'Guests in',
  subtitle: 'Dinner at 7:00 PM · Dining Room',
);

Widget _summary() => const ChangeSummary(
  eyebrow: 'Done · from your request at 5:40 PM',
  title: 'Dinner moved to 8:00 PM',
  changes: [
    ChangeTileData(
      icon: 'oven',
      label: 'Oven preheat',
      value: '7:00 PM',
      previous: 'was 6:00 PM',
    ),
    ChangeTileData(
      icon: 'scene',
      label: 'Guest scene',
      value: '7:45 PM',
      previous: 'was 6:45 PM',
    ),
    ChangeTileData(
      icon: 'send',
      label: 'Notified',
      value: 'Marco',
      note: 'Sent 5:41 PM',
    ),
    ChangeTileData(
      icon: 'wine',
      label: 'Wine chill',
      value: '7:15 PM',
      note: 'Added',
    ),
  ],
);

Widget _todo() => ShoppingList(
  title: 'Shopping for tonight',
  subtitle: 'Missing from the fridge · dinner for 6',
  items: const [
    ShoppingItem(id: 'a', label: 'Short ribs', detail: '4 lb · bone-in'),
    ShoppingItem(id: 'b', label: 'Heavy cream', detail: '1 pint'),
    ShoppingItem(id: 'c', label: 'Shallots', detail: '6', checked: true),
    ShoppingItem(id: 'd', label: 'Thyme', detail: '1 bunch'),
    ShoppingItem(id: 'e', label: 'Red wine', detail: '2 bottles'),
    ShoppingItem(id: 'f', label: 'Parsley'),
  ],
  footerLabel: 'Share list with Marco',
  footerIcon: 'share',
  onFooter: () {},
);

/// Every card at every cell it is meant to fill, by the card's `fit`.
final _fits = <String, (Widget Function(), List<Size>)>{
  'DeviceCard': (_device, [_third, _half]),
  'HeadsUpCard': (_alert, [_third, _half, _twoThirds, _wide]),
  'TripCard': (_trip, [_third, _half, _twoThirds, _wide]),
  'PlanTimeline detailed': (_plan, [_thirdTall, _halfTall]),
  'PlanTimeline short': (_plan, [_third, _half]),
  'PlanTimeline with five entries': (_fivePlan, [_thirdTall, _halfTall]),
  'ChargeCard': (_charge, [_third, _half]),
  'SceneCard': (_scene, [_third, _half]),
  'CountdownCard': (_event, [_third, _half]),
  'ChangeSummary': (_summary, [_twoThirds, _wide]),
  'ShoppingList': (_todo, [_thirdTall]),
};

Future<void> _pump(WidgetTester tester, Size size, Widget child) async {
  tester.view
    ..devicePixelRatio = 1
    ..physicalSize = const Size(1400, 900);
  addTearDown(tester.view.reset);
  await tester.pumpWidget(
    MaterialApp(
      theme: AppTheme.light,
      home: Scaffold(
        body: Align(
          alignment: Alignment.topLeft,
          child: SizedBox.fromSize(size: size, child: child),
        ),
      ),
    ),
  );
}

void main() {
  setUpAll(loadFonts);

  group('a card in its cell', () {
    for (final MapEntry(key: name, value: (build, sizes)) in _fits.entries) {
      for (final size in sizes) {
        testWidgets('$name fills ${size.width} x ${size.height} without '
            'overflowing', (tester) async {
          await _pump(tester, size, build());

          expect(tester.takeException(), isNull);
          // ChangeSummary and the glowing cards draw their own shell; every
          // other card is an AppCard.
          final shell = find.byType(ChangeSummary).evaluate().isNotEmpty
              ? find.byType(ChangeSummary)
              : find.byType(SceneCard).evaluate().isNotEmpty
              ? find.byType(SceneCard)
              : find.byType(GlowSurface).evaluate().isNotEmpty
              ? find.byType(GlowSurface)
              : find.byType(AppCard).first;
          expect(tester.getSize(shell), size);
        });
      }
    }
  });

  group('adapting to the cell', () {
    testWidgets('PlanTimeline draws four of five entries in a tall cell', (
      tester,
    ) async {
      await _pump(tester, _thirdTall, _fivePlan());

      expect(find.text('Serve'), findsNothing);
      expect(find.text('Dining scene'), findsOneWidget);
      expect(find.text('Prep the rack'), findsOneWidget);
    });

    testWidgets('PlanTimeline keeps four rows with only four entries', (
      tester,
    ) async {
      await _pump(
        tester,
        _thirdTall,
        const PlanTimeline(
          title: 'Plan',
          entries: [
            PlanEntry(time: '6:00 PM', title: 'One', icon: 'oven'),
            PlanEntry(time: '6:10 PM', title: 'Two', icon: 'cake'),
            PlanEntry(time: '6:45 PM', title: 'Three', icon: 'scene'),
            PlanEntry(time: '7:00 PM', title: 'Four', icon: 'guests'),
          ],
        ),
      );

      expect(find.text('Four'), findsOneWidget);
    });

    testWidgets('PlanTimeline draws compact rows in a short cell', (
      tester,
    ) async {
      await _pump(tester, _third, _plan());

      expect(find.text('Friday, Oct 2'), findsNothing);
      expect(find.text('Pick up cake'), findsOneWidget);
      expect(find.text('Guests arrive'), findsNothing);
    });

    testWidgets('PlanTimeline draws the date line in a tall cell', (
      tester,
    ) async {
      await _pump(tester, _thirdTall, _plan());

      expect(find.text('Friday, Oct 2'), findsOneWidget);
      expect(find.text('Guests arrive'), findsOneWidget);
      expect(find.text('Dessert'), findsNothing);
    });

    testWidgets(
      'PlanTimeline draws icons in a tall cell whatever the density',
      (
        tester,
      ) async {
        await _pump(tester, _thirdTall, _plan(density: PlanDensity.compact));

        expect(find.text('Friday, Oct 2'), findsOneWidget);
        expect(find.byIcon(AppIcons.byName('oven')), findsOneWidget);
      },
    );

    testWidgets('HeadsUpCard shows both actions in two thirds', (tester) async {
      await _pump(tester, _twoThirds, _alert());

      expect(find.text('Close garage when I leave'), findsOneWidget);
      expect(find.text('Close living room blinds'), findsOneWidget);
    });

    for (final size in [_third, _half]) {
      testWidgets(
        'HeadsUpCard shows only the primary action in ${size.width}',
        (
          tester,
        ) async {
          await _pump(tester, size, _alert());

          expect(find.text('Close garage when I leave'), findsOneWidget);
          expect(find.text('Close living room blinds'), findsNothing);
        },
      );
    }

    testWidgets('HeadsUpCard without actions has no action row', (
      tester,
    ) async {
      await _pump(tester, _third, const HeadsUpCard(title: 'Fridge door open'));

      expect(find.byType(ActionPill), findsNothing);
    });

    testWidgets('TripCard shows the stops that fit', (tester) async {
      await _pump(tester, _twoThirds, _trip());
      expect(find.text('Home'), findsOneWidget);

      await _pump(tester, _half, _trip());
      expect(find.text('Grab the cake'), findsOneWidget);
      expect(find.text('Home'), findsNothing);

      await _pump(tester, _third, _trip());
      expect(find.text('School pickup'), findsNothing);
      expect(find.text('Updated just now'), findsOneWidget);
    });

    testWidgets('TripCard hero alone has no tag when it has none', (
      tester,
    ) async {
      await _pump(tester, _third, const TripCard(leaveBy: '5:00 PM'));

      expect(find.byType(StatusTag), findsNothing);
    });

    testWidgets('ChangeSummary shows the tiles that fit', (tester) async {
      await _pump(tester, _wide, _summary());
      expect(find.text('Wine chill'), findsOneWidget);

      await _pump(tester, _twoThirds, _summary());
      expect(find.text('Wine chill'), findsOneWidget);

      await _pump(tester, _half, _summary());
      expect(find.text('Notified'), findsOneWidget);
      expect(find.text('Wine chill'), findsNothing);

      await _pump(tester, _third, _summary());
      expect(find.text('Guest scene'), findsOneWidget);
      expect(find.text('Notified'), findsNothing);
    });

    testWidgets('ShoppingList shows five rows and the footer in a tall cell', (
      tester,
    ) async {
      await _pump(tester, _thirdTall, _todo());

      expect(find.text('Red wine'), findsOneWidget);
      expect(find.text('Parsley'), findsNothing);
      expect(find.text('Share list with Marco'), findsOneWidget);
    });

    testWidgets('ShoppingList keeps two rows and drops the footer when short', (
      tester,
    ) async {
      await _pump(tester, const Size(352, 360), _todo());

      expect(find.text('Share list with Marco'), findsNothing);
      expect(find.text('Short ribs'), findsOneWidget);
      expect(find.text('Heavy cream'), findsOneWidget);
      expect(find.text('Parsley'), findsNothing);
    });

    testWidgets('ShoppingList counts the open items, not only the visible', (
      tester,
    ) async {
      await _pump(tester, _thirdTall, _todo());

      expect(find.text('5'), findsOneWidget);
    });
  });

  group('without a bound', () {
    testWidgets('cards lay out in an unbounded height', (tester) async {
      tester.view
        ..devicePixelRatio = 1
        ..physicalSize = const Size(1400, 900);
      addTearDown(tester.view.reset);
      await tester.pumpWidget(
        MaterialApp(
          theme: AppTheme.light,
          home: Scaffold(
            body: SingleChildScrollView(
              child: Column(
                children: [
                  SizedBox(width: 540, child: _plan()),
                  SizedBox(width: 540, child: _todo()),
                  SizedBox(width: 540, child: _alert()),
                ],
              ),
            ),
          ),
        ),
      );

      expect(tester.takeException(), isNull);
      expect(find.text('Guests arrive'), findsOneWidget);
      expect(find.text('Parsley'), findsOneWidget);
    });

    testWidgets('cards lay out in an unbounded width', (tester) async {
      tester.view
        ..devicePixelRatio = 1
        ..physicalSize = const Size(1400, 900);
      addTearDown(tester.view.reset);
      await tester.pumpWidget(
        MaterialApp(
          theme: AppTheme.light,
          home: Scaffold(
            body: SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: Row(
                children: [
                  _plan(),
                  _summary(),
                  _trip(),
                  _alert(),
                ].map((card) => SizedBox(width: 600, child: card)).toList(),
              ),
            ),
          ),
        ),
      );

      expect(tester.takeException(), isNull);
    });
  });
}
