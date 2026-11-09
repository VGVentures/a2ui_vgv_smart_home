import 'package:a2ui_vgv_smart_home/action_toast/cubit/action_toast_cubit.dart';
import 'package:a2ui_vgv_smart_home/action_toast/view/action_glow.dart';
import 'package:a2ui_vgv_smart_home/action_toast/view/action_toast.dart';
import 'package:a2ui_vgv_smart_home/l10n/l10n.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group(ActionGlow, () {
    Future<void> pump(WidgetTester tester, ActionToastStatus status) =>
        tester.pumpWidget(
          Directionality(
            textDirection: TextDirection.ltr,
            child: ActionGlow(status: status),
          ),
        );

    RadialGradient gradient(WidgetTester tester) =>
        (tester
                        .widget<AnimatedContainer>(
                          find.byType(AnimatedContainer),
                        )
                        .decoration!
                    as BoxDecoration)
                .gradient!
            as RadialGradient;

    testWidgets('grows and turns green on success, then fades', (
      tester,
    ) async {
      await pump(tester, ActionToastStatus.loading);
      final small = gradient(tester);
      expect(small.colors.first.a, lessThan(0.3));

      await pump(tester, ActionToastStatus.success);
      await tester.pump(const Duration(seconds: 1));
      final big = gradient(tester);
      expect(big.radius, greaterThan(small.radius));
      expect(big.colors.first.a, greaterThan(small.colors.first.a));
      expect(big.colors.first.g, greaterThan(big.colors.first.r));

      await pump(tester, ActionToastStatus.idle);
      await tester.pump(const Duration(seconds: 1));
      final gone = gradient(tester);
      expect(gone.colors.first.a, 0);
      expect(gone.radius, big.radius);
    });
  });

  group('ActionToast', () {
    var cancelled = 0;

    setUp(() => cancelled = 0);

    Future<void> pump(
      WidgetTester tester,
      ActionToastState state, {
      bool reduceMotion = false,
    }) {
      return tester.pumpWidget(
        MaterialApp(
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          home: MediaQuery(
            data: MediaQueryData(disableAnimations: reduceMotion),
            child: Scaffold(
              body: Center(
                child: ActionToast(state: state, onCancel: () => cancelled++),
              ),
            ),
          ),
        ),
      );
    }

    const loading = ActionToastState(
      status: ActionToastStatus.loading,
      label: 'Turn off oven',
    );
    const success = ActionToastState(
      status: ActionToastStatus.success,
      label: 'Turn off oven',
    );
    const error = ActionToastState(
      status: ActionToastStatus.error,
      label: 'Turn off oven',
    );

    testWidgets('loading shows the label and a sparkle', (tester) async {
      await pump(tester, loading);
      expect(find.text('Turn off oven'), findsOneWidget);
      expect(find.byKey(const ValueKey('loading')), findsOneWidget);
      expect(find.text('Cancel'), findsNothing);
    });

    testWidgets('a cancellable command offers a way out', (tester) async {
      await pump(
        tester,
        const ActionToastState(
          status: ActionToastStatus.loading,
          label: 'Delay dinner',
          cancellable: true,
        ),
      );
      await tester.tap(find.text('Cancel'));
      expect(cancelled, 1);
    });

    testWidgets('success says completed and shows the check', (tester) async {
      await pump(tester, loading);
      await pump(tester, success);
      await tester.pump(const Duration(milliseconds: 100));
      expect(find.text('Completed'), findsOneWidget);
      expect(find.text('Turn off oven'), findsNothing);
      await tester.pump(const Duration(seconds: 1));
      expect(find.byKey(const ValueKey('success')), findsOneWidget);
      expect(find.byKey(const ValueKey('loading')), findsNothing);
      expect(find.byKey(const ValueKey('reason')), findsNothing);
    });

    testWidgets('error keeps the label, shakes and says why', (tester) async {
      await pump(tester, loading);
      await pump(tester, error);
      await tester.pump(const Duration(milliseconds: 50));
      final shaken = tester.getTopLeft(find.text('Turn off oven')).dx;
      await tester.pump(const Duration(seconds: 1));
      final still = tester.getTopLeft(find.text('Turn off oven')).dx;

      expect(shaken, isNot(still));
      expect(find.byKey(const ValueKey('error')), findsOneWidget);
      expect(find.text('Something went wrong. Try again.'), findsOneWidget);
    });

    testWidgets('error shows the backend reason when there is one', (
      tester,
    ) async {
      await pump(
        tester,
        const ActionToastState(
          status: ActionToastStatus.error,
          label: 'Turn off oven',
          reason: 'The oven is offline',
        ),
      );
      await tester.pump(const Duration(seconds: 1));
      expect(find.text('The oven is offline'), findsOneWidget);
      expect(find.text('Something went wrong. Try again.'), findsNothing);
    });

    testWidgets('reduced motion skips the shake', (tester) async {
      await pump(tester, loading, reduceMotion: true);
      await pump(tester, error, reduceMotion: true);
      await tester.pump(const Duration(milliseconds: 50));
      final shaken = tester.getTopLeft(find.text('Turn off oven')).dx;
      await tester.pump(const Duration(seconds: 1));
      expect(tester.getTopLeft(find.text('Turn off oven')).dx, shaken);

      await pump(tester, success, reduceMotion: true);
      await tester.pump();
      expect(find.byKey(const ValueKey('success')), findsOneWidget);
    });
  });
}
