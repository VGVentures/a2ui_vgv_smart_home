import 'package:app_ui/app_ui.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../helpers/pump_component.dart';

void main() {
  group(SceneCard, () {
    testWidgets('ready shows the Start pill and runs the scene', (
      tester,
    ) async {
      var ran = false;
      await tester.pumpComponent(
        SceneCard(
          name: 'Dinner party scene',
          description: 'Dining Room · Starts 6:45 PM · 4 devices',
          settings: const ['Pendants 40 %', 'Jazz on Nest Audio', '70 °F'],
          onRun: () => ran = true,
        ),
      );

      expect(find.text('Dinner party scene'), findsOneWidget);
      expect(find.text('Pendants 40 %'), findsOneWidget);
      expect(find.text('On'), findsNothing);
      await tester.tap(find.text('Start'));
      expect(ran, isTrue);
    });

    testWidgets('running swaps the pill for the On tag', (tester) async {
      await tester.pumpComponent(
        const SceneCard(name: 'Quiet', state: SceneState.running),
      );

      expect(find.text('Start'), findsNothing);
      expect(find.text('On'), findsOneWidget);
    });

    testWidgets('uses a custom action label and caps settings at four', (
      tester,
    ) async {
      await tester.pumpComponent(
        const SceneCard(
          name: 'Quiet',
          actionLabel: 'Run',
          settings: ['a', 'b', 'c', 'd', 'e'],
        ),
      );

      expect(find.text('Run'), findsOneWidget);
      expect(find.text('d'), findsOneWidget);
      expect(find.text('e'), findsNothing);
    });

    testWidgets('a bounded ready card pins the chips to the bottom', (
      tester,
    ) async {
      await tester.pumpComponent(
        const SizedBox(
          width: 446,
          height: 260,
          child: SceneCard(
            name: 'Dinner party scene',
            description: 'Dining Room · Starts 6:45 PM · 4 devices',
            settings: ['Pendants 40%', 'Jazz on Nest Audio', '70°F'],
          ),
        ),
      );

      expect(tester.takeException(), isNull);
      final card = tester.getRect(find.byType(SceneCard));
      expect(
        tester.getBottomLeft(find.text('Pendants 40%')).dy,
        lessThan(card.bottom - AppSpacing.cardPadding + 1),
      );
      // The pill sits at the card padding.
      expect(
        tester.getTopRight(find.byType(ActionPill)).dx,
        card.right - AppSpacing.cardPadding,
      );
      expect(
        tester.getTopRight(find.byType(ActionPill)).dy,
        card.top + AppSpacing.cardPadding,
      );
    });

    testWidgets('a running card keeps its text under the top row', (
      tester,
    ) async {
      await tester.pumpComponent(
        const SizedBox(
          width: 352,
          height: 260,
          child: SceneCard(
            name: 'Dinner party scene',
            description: 'Dining Room · since 7:45 PM',
            state: SceneState.running,
            settings: ['Pendants 40%', 'Candle mode'],
          ),
        ),
      );

      expect(tester.takeException(), isNull);
      expect(find.text('Pendants 40%'), findsOneWidget);
      expect(
        tester.getTopLeft(find.text('Dinner party scene')).dy,
        lessThan(120),
      );
    });

    testWidgets('a cell too short for the chips drops them', (tester) async {
      await tester.pumpComponent(
        const SizedBox(
          width: 270,
          height: 200,
          child: SceneCard(
            name: 'Dinner party scene',
            description: 'Dining Room',
            settings: ['Pendants 40%'],
          ),
        ),
      );

      expect(tester.takeException(), isNull);
      expect(find.text('Pendants 40%'), findsNothing);
      expect(find.text('Start'), findsOneWidget);
    });

    testWidgets('draws without a description or settings', (tester) async {
      await tester.pumpComponent(
        const SizedBox(width: 352, height: 260, child: SceneCard(name: 'Q')),
      );
      expect(tester.takeException(), isNull);
      await tester.pumpComponent(const SceneCard(name: 'Q'));
      expect(tester.takeException(), isNull);
    });

    testWidgets('repaints its glow when the tone changes', (tester) async {
      await tester.pumpComponent(const SceneCard(name: 'Q'));
      await tester.pumpComponent(
        const SceneCard(name: 'Q', tone: AppTone.energy),
      );
      expect(tester.takeException(), isNull);
    });

    test('maps names to a state', () {
      expect(SceneState.byName('running'), SceneState.running);
      expect(SceneState.byName(null), SceneState.ready);
    });
  });
}
