import 'package:app_ui/app_ui.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../helpers/pump_component.dart';

Color? _fillOf(WidgetTester tester, String label) {
  final material = tester.widget<Material>(
    find.ancestor(of: find.text(label), matching: find.byType(Material)).first,
  );
  return material.color;
}

void main() {
  group(ActionChips, () {
    testWidgets('renders the Suggested label and taps a chip', (tester) async {
      String? tapped;
      await tester.pumpComponent(
        ActionChips(
          chips: [
            ActionChipData(
              label: 'Preheat now',
              icon: 'flame',
              onPressed: () => tapped = 'preheat',
            ),
            const ActionChipData(label: 'Chill wine'),
          ],
        ),
      );

      expect(find.text('Suggested'), findsOneWidget);
      expect(find.text('Chill wine'), findsOneWidget);
      await tester.tap(find.text('Preheat now'));
      expect(tapped, 'preheat');
    });

    testWidgets('keeps its height without suggestions', (tester) async {
      await tester.pumpComponent(const ActionChips(chips: []));

      expect(find.text('Suggested'), findsNothing);
      expect(
        tester.getSize(find.byType(SizedBox).last).height,
        ActionPill.height,
      );
    });

    testWidgets('lines the chips up on the right', (tester) async {
      await tester.pumpComponent(
        const ActionChips(
          chips: [
            ActionChipData(label: 'Preheat now'),
            ActionChipData(label: 'Chill wine'),
          ],
        ),
      );

      // The component helper pads the screen by s4 on each side.
      final contentRight =
          tester.getSize(find.byType(Scaffold)).width - AppSpacing.s4;
      expect(
        tester.getTopRight(find.byType(ActionPill).last).dx,
        contentRight,
      );
    });

    testWidgets('uses a custom label', (tester) async {
      await tester.pumpComponent(
        const ActionChips(
          label: 'Next',
          chips: [ActionChipData(label: 'Go')],
        ),
      );

      expect(find.text('Next'), findsOneWidget);
    });

    testWidgets('makes the first chip primary by default', (tester) async {
      await tester.pumpComponent(
        const ActionChips(
          chips: [
            ActionChipData(label: 'One'),
            ActionChipData(label: 'Two'),
          ],
        ),
      );

      expect(_fillOf(tester, 'One'), AppColors.ink);
      expect(_fillOf(tester, 'Two'), AppColors.surfaceRaised);
    });

    testWidgets('honors isPrimary on another chip', (tester) async {
      await tester.pumpComponent(
        const ActionChips(
          chips: [
            ActionChipData(label: 'One'),
            ActionChipData(label: 'Two', isPrimary: true),
          ],
        ),
      );

      expect(_fillOf(tester, 'One'), AppColors.surfaceRaised);
      expect(_fillOf(tester, 'Two'), AppColors.ink);
    });

    testWidgets('colors the primary icon spark and others by kind', (
      tester,
    ) async {
      await tester.pumpComponent(
        const ActionChips(
          chips: [
            ActionChipData(label: 'One', icon: 'flame'),
            ActionChipData(label: 'Two', icon: 'wine'),
            ActionChipData(label: 'Three', icon: 'scene'),
          ],
        ),
      );

      final icons = tester
          .widgetList<Icon>(
            find.descendant(
              of: find.byType(ActionPill),
              matching: find.byType(Icon),
            ),
          )
          .toList();
      expect(icons.map((i) => i.color), [
        AppColors.spark,
        AppColors.accent,
        AppTone.lighting.ink,
      ]);
    });
  });
}
