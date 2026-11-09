import 'package:app_ui/app_ui.dart';
import 'package:app_ui/src/widgets/glow_surface.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../helpers/pump_component.dart';

void main() {
  group(HeadsUpCard, () {
    testWidgets('renders the eyebrow, headline, body and actions', (
      tester,
    ) async {
      var pressed = '';
      await tester.pumpComponent(
        HeadsUpCard(
          title: 'Rain starting in 20 min.',
          message: 'Garage door is open',
          source: 'Weather',
          timestamp: 'Just now',
          actions: [
            HeadsUpActionData(
              label: 'Close garage',
              isPrimary: true,
              onPressed: () => pressed = 'garage',
            ),
            HeadsUpActionData(
              label: 'Close blinds',
              icon: 'blinds',
              onPressed: () => pressed = 'blinds',
            ),
          ],
        ),
      );

      expect(find.textContaining('Heads up'), findsOneWidget);
      expect(find.textContaining('Weather'), findsOneWidget);
      expect(find.text('Just now'), findsOneWidget);
      expect(find.text('Garage door is open'), findsOneWidget);
      await tester.tap(find.text('Close blinds'));
      expect(pressed, 'blinds');
      await tester.tap(find.text('Close garage'));
      expect(pressed, 'garage');
    });

    for (final variant in HeadsUpVariant.values) {
      testWidgets('renders $variant with its border', (tester) async {
        await tester.pumpComponent(
          HeadsUpCard(title: 'Fridge door open', variant: variant),
        );

        expect(find.text('Fridge door open'), findsOneWidget);
        expect(find.textContaining('Heads up'), findsOneWidget);
        expect(
          tester.widget<GlowSurface>(find.byType(GlowSurface)).border?.width,
          2,
        );
      });
    }

    testWidgets('an urgent card is red and a heads up is amber', (
      tester,
    ) async {
      await tester.pumpComponent(const HeadsUpCard(title: 'A'));
      final amber = tester.widget<GlowSurface>(find.byType(GlowSurface));
      expect(amber.color, AppColors.surfaceRaised);
      expect(amber.border?.color, const Color(0x99EBB727));

      await tester.pumpComponent(
        const HeadsUpCard(title: 'A', variant: HeadsUpVariant.urgent),
      );
      final red = tester.widget<GlowSurface>(find.byType(GlowSurface));
      expect(red.color, const Color(0xFFFFE0DE));
      expect(red.border?.color, const Color(0xFFF0443A));
    });

    for (final variant in HeadsUpVariant.values) {
      testWidgets('$variant keeps the timestamp at the right padding', (
        tester,
      ) async {
        await tester.pumpComponent(
          HeadsUpCard(
            title: 'Urgent',
            variant: variant,
            timestamp: 'Just now',
            source: 'Entry',
          ),
        );

        final card = tester.getRect(find.byType(GlowSurface));
        final stamp = tester.getRect(find.text('Just now'));
        // The border and the card padding, as in the design.
        expect(card.right - stamp.right, 2 + AppSpacing.cardPadding);
      });
    }

    testWidgets('pins the actions to the bottom of a tall card', (
      tester,
    ) async {
      await tester.pumpComponent(
        SizedBox(
          height: 400,
          child: HeadsUpCard(
            title: 'Rain',
            message: 'Garage door is open',
            actions: [HeadsUpActionData(label: 'Close', onPressed: () {})],
          ),
        ),
      );

      final card = tester.getRect(find.byType(GlowSurface));
      final pill = tester.getRect(find.byType(ActionPill));
      expect(card.height, 400);
      expect(card.bottom - pill.bottom, closeTo(2 + 32, 0.5));
    });

    testWidgets('shows only the primary action in a narrow cell', (
      tester,
    ) async {
      await tester.pumpComponent(
        SizedBox(
          width: 400,
          child: HeadsUpCard(
            title: 'Rain',
            actions: [
              HeadsUpActionData(label: 'First', onPressed: () {}),
              HeadsUpActionData(
                label: 'Second',
                isPrimary: true,
                onPressed: () {},
              ),
            ],
          ),
        ),
      );

      expect(find.text('First'), findsNothing);
      expect(find.text('Second'), findsOneWidget);
    });

    testWidgets('an urgent card reads its message in the brown ink', (
      tester,
    ) async {
      await tester.pumpComponent(
        const HeadsUpCard(
          title: 'A',
          message: 'Fresh thyme is missing',
          variant: HeadsUpVariant.urgent,
        ),
      );

      final text = tester.widget<Text>(find.text('Fresh thyme is missing'));
      expect(text.style?.color?.a, closeTo(0.78, 0.01));
    });

    test('reads a variant by name and falls back to heads up', () {
      expect(HeadsUpVariant.byName('urgent'), HeadsUpVariant.urgent);
      expect(HeadsUpVariant.byName('headsUp'), HeadsUpVariant.headsUp);
      expect(HeadsUpVariant.byName('other'), HeadsUpVariant.headsUp);
      expect(HeadsUpVariant.byName(null), HeadsUpVariant.headsUp);
    });

    testWidgets('a done action shows a check and ignores presses', (
      tester,
    ) async {
      var pressed = false;
      await tester.pumpComponent(
        HeadsUpCard(
          title: 'Rain',
          actions: [
            HeadsUpActionData(
              label: 'Blinds closed',
              isDone: true,
              onPressed: () => pressed = true,
            ),
          ],
        ),
      );

      await tester.tap(find.text('Blinds closed'));
      expect(pressed, isFalse);
      expect(find.byIcon(AppIcons.byName('check')), findsOneWidget);
    });
  });
}
