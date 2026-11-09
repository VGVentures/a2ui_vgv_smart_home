import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:home_frontend/src/zone/view/lockable_surface.dart';

void main() {
  group(LockableSurface, () {
    Widget wrap({
      required bool locked,
      required VoidCallback onTap,
      double? lockedOpacity,
    }) {
      return MaterialApp(
        home: Scaffold(
          body: LockableSurface(
            locked: locked,
            lockedOpacity: lockedOpacity ?? 0.6,
            child: GestureDetector(
              behavior: HitTestBehavior.opaque,
              onTap: onTap,
              child: const SizedBox(width: 100, height: 100),
            ),
          ),
        ),
      );
    }

    testWidgets('forwards pointer events to the child when not locked', (
      tester,
    ) async {
      var taps = 0;
      await tester.pumpWidget(wrap(locked: false, onTap: () => taps++));

      await tester.tap(find.byType(GestureDetector));

      expect(taps, 1);
    });

    testWidgets('drops pointer events when locked', (tester) async {
      var taps = 0;
      await tester.pumpWidget(wrap(locked: true, onTap: () => taps++));

      await tester.tap(find.byType(GestureDetector), warnIfMissed: false);

      expect(taps, 0);
    });

    testWidgets('mutes opacity to 0.6 when locked', (tester) async {
      await tester.pumpWidget(wrap(locked: true, onTap: () {}));

      final opacity = tester.widget<Opacity>(
        find.descendant(
          of: find.byType(LockableSurface),
          matching: find.byType(Opacity),
        ),
      );
      expect(opacity.opacity, 0.6);
    });

    testWidgets('honors a custom lockedOpacity when locked', (tester) async {
      await tester.pumpWidget(
        wrap(locked: true, onTap: () {}, lockedOpacity: 0.3),
      );

      final opacity = tester.widget<Opacity>(
        find.descendant(
          of: find.byType(LockableSurface),
          matching: find.byType(Opacity),
        ),
      );
      expect(opacity.opacity, 0.3);
    });

    testWidgets('keeps opacity at 1.0 when not locked', (tester) async {
      await tester.pumpWidget(wrap(locked: false, onTap: () {}));

      final opacity = tester.widget<Opacity>(
        find.descendant(
          of: find.byType(LockableSurface),
          matching: find.byType(Opacity),
        ),
      );
      expect(opacity.opacity, 1.0);
    });

    group('marks', () {
      testWidgets('Semantics as disabled when locked', (tester) async {
        await tester.pumpWidget(wrap(locked: true, onTap: () {}));

        final semantics = tester.widget<Semantics>(
          find
              .descendant(
                of: find.byType(LockableSurface),
                matching: find.byType(Semantics),
              )
              .first,
        );
        expect(semantics.properties.enabled, isFalse);
      });

      testWidgets('Semantics as enabled when not locked', (tester) async {
        await tester.pumpWidget(wrap(locked: false, onTap: () {}));

        final semantics = tester.widget<Semantics>(
          find
              .descendant(
                of: find.byType(LockableSurface),
                matching: find.byType(Semantics),
              )
              .first,
        );
        expect(semantics.properties.enabled, isTrue);
      });
    });
  });
}
