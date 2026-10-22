import 'dart:async';

import 'package:app_ui/app_ui.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:home_frontend/home_frontend.dart';

import '../helpers/fake_agent.dart';
import '../helpers/helpers.dart';

Future<void> settle(WidgetTester tester) async {
  await tester.pump(const Duration(seconds: 1));
  await tester.pump(const Duration(seconds: 1));
}

void main() {
  group('DashboardSurface', () {
    testWidgets('shows the skeleton until the surface arrives', (
      tester,
    ) async {
      final gate = Completer<void>();
      await tester.pumpApp(FakeAgentFactory(emitSurface: true, gate: gate));
      await settle(tester);

      expect(find.byType(SkeletonSurface), findsOneWidget);
      expect(find.byType(Surface, skipOffstage: false), findsNothing);

      gate.complete();
      await settle(tester);

      expect(find.byType(SkeletonSurface), findsNothing);
      expect(find.byType(Surface, skipOffstage: false), findsOneWidget);
    });

    testWidgets('keeps the surface on screen while a command is answered', (
      tester,
    ) async {
      final factory = FakeAgentFactory(emitSurface: true);
      await tester.pumpApp(factory);
      await settle(tester);
      final agent = factory.agents.single
        ..emit(const UiInteractionAdded('Delay dinner'));
      await settle(tester);

      expect(find.byType(SkeletonSurface), findsNothing);
      expect(find.byType(Surface, skipOffstage: false), findsOneWidget);

      agent.emit(const UiInteractionCompleted());
      await settle(tester);
      expect(find.byType(SkeletonSurface), findsNothing);
      expect(find.byType(Surface, skipOffstage: false), findsOneWidget);
    });

    testWidgets('a press shows one pill that turns green and leaves', (
      tester,
    ) async {
      final factory = FakeAgentFactory(emitSurface: true);
      await tester.pumpApp(factory);
      await settle(tester);
      final agent = factory.agents.single
        ..emit(const UiInteractionAdded('Turn off oven'));
      await tester.pump(const Duration(milliseconds: 400));
      expect(find.text('Turn off oven'), findsOneWidget);
      expect(find.byKey(const ValueKey('loading')), findsOneWidget);

      agent.emit(const UiInteractionCompleted());
      await tester.pump(const Duration(milliseconds: 600));
      expect(find.text('Completed'), findsOneWidget);
      expect(find.byKey(const ValueKey('success')), findsOneWidget);

      await tester.pump(const Duration(seconds: 2));
      await tester.pump(const Duration(seconds: 1));
      expect(find.text('Completed'), findsNothing);
    });

    testWidgets('a failed press shows the backend reason, then leaves', (
      tester,
    ) async {
      final factory = FakeAgentFactory(emitSurface: true);
      await tester.pumpApp(factory);
      await settle(tester);
      factory.agents.single
        ..emit(const UiInteractionAdded('Turn off oven'))
        ..emit(
          const UiInteractionCompleted(
            succeeded: false,
            reason: 'The oven is offline',
          ),
        );
      await tester.pump(const Duration(milliseconds: 600));
      expect(find.byKey(const ValueKey('error')), findsOneWidget);
      expect(find.text('Turn off oven'), findsOneWidget);
      expect(find.text('The oven is offline'), findsOneWidget);

      await tester.pump(const Duration(seconds: 3));
      await tester.pump(const Duration(seconds: 1));
      expect(find.text('Turn off oven'), findsNothing);
    });

    testWidgets('a failed press bumps the optimistic revision', (
      tester,
    ) async {
      final factory = FakeAgentFactory(emitSurface: true);
      await tester.pumpApp(factory);
      await settle(tester);
      int revision() => OptimisticScope.of(
        tester.element(find.byType(Surface, skipOffstage: false)),
      );
      expect(revision(), 0);

      factory.agents.single
        ..emit(const UiInteractionAdded('Turn off oven'))
        ..emit(const UiInteractionCompleted(succeeded: false));
      await tester.pump(const Duration(milliseconds: 100));
      expect(revision(), 1);
      await settle(tester);
    });

    testWidgets('reports a turn that failed with nothing to show', (
      tester,
    ) async {
      await tester.pumpApp(FakeAgentFactory(failWith: Exception('boom')));
      await settle(tester);

      expect(find.text('Could not build the dashboard.'), findsOneWidget);
      expect(find.byType(SkeletonSurface), findsNothing);
    });
  });
}
