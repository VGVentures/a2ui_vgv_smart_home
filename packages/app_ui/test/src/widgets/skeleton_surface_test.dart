import 'package:app_ui/app_ui.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group(SkeletonSurface, () {
    testWidgets('pulses without overflowing the dashboard area', (
      tester,
    ) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: SizedBox(
            width: 1104,
            height: 632,
            child: SkeletonSurface(),
          ),
        ),
      );

      final pulse = find.descendant(
        of: find.byType(SkeletonSurface),
        matching: find.byType(FadeTransition),
      );
      final first = tester.widget<FadeTransition>(pulse).opacity.value;
      await tester.pump(const Duration(milliseconds: 500));
      final later = tester.widget<FadeTransition>(pulse).opacity.value;

      expect(later, isNot(first));
      expect(tester.takeException(), isNull);
    });

    testWidgets('lines its pills up on the right, as the chips row does', (
      tester,
    ) async {
      tester.view
        ..physicalSize = const Size(
          AppSpacing.panelWidth,
          AppSpacing.panelHeight,
        )
        ..devicePixelRatio = 1;
      addTearDown(tester.view.reset);
      await tester.pumpWidget(
        const MaterialApp(
          home: Align(
            alignment: Alignment.topLeft,
            child: SizedBox(
              width: 1104,
              height: 632,
              child: SkeletonSurface(),
            ),
          ),
        ),
      );

      // The pill placeholders are the only 64 tall boxes.
      final pills = find.byWidgetPredicate(
        (widget) => widget is SizedBox && widget.height == ActionPill.height,
      );
      expect(pills, findsNWidgets(3));
      expect(tester.getTopRight(pills.last).dx, 1104);
    });
  });
}
