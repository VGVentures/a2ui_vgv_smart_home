import 'dart:async';

import 'package:a2ui_vgv_smart_home/dashboard/view/dashboard_page.dart';
import 'package:a2ui_vgv_smart_home/shell/device_frame.dart';
import 'package:a2ui_vgv_smart_home/timeline/day_phase.dart';
import 'package:a2ui_vgv_smart_home/timeline/view/timeline_bar.dart';
import 'package:app_ui/app_ui.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:genui/genui.dart';
import 'package:home_repository/home_repository.dart';

import '../helpers/fake_agent.dart';
import '../helpers/helpers.dart';

Finder _button(String label) => find.ancestor(
  of: find.text(label),
  matching: find.byWidgetPredicate((widget) => widget is TextButton),
);

Future<void> _play(WidgetTester tester) async {
  await tester.pump();
  await tester.pump(const Duration(seconds: 3));
  await tester.pump();
  await tester.pump();
}

/// Lets a refresh finish: the reply and the turn after it.
Future<void> _drain(WidgetTester tester) async {
  for (var i = 0; i < 4; i++) {
    await tester.pump(const Duration(milliseconds: 50));
  }
}

void main() {
  group('Dashboard timeline', () {
    testWidgets('starts the demo over when it opens, once', (tester) async {
      final repository = FakeScenarioRepository();
      final factory = FakeAgentFactory();

      await tester.pumpApp(factory, scenarioRepository: repository);

      expect(repository.resets, 1);
      expect(factory.agents, hasLength(1));
      expect(find.text('7:30'), findsOneWidget);
    });

    testWidgets('shows the skeleton until the backend is reset', (
      tester,
    ) async {
      final gate = Completer<void>();
      final factory = FakeAgentFactory();

      await tester.pumpApp(
        factory,
        scenarioRepository: FakeScenarioRepository(gate: gate),
      );

      expect(find.byType(SkeletonSurface), findsOneWidget);
      expect(factory.agents, isEmpty);

      gate.complete();
      await tester.pump();
      await tester.pump();
      expect(factory.agents, hasLength(1));
    });

    testWidgets('puts the timeline below the tablet, outside its screen', (
      tester,
    ) async {
      await tester.pumpApp(FakeAgentFactory());

      expect(
        find.descendant(
          of: find.byType(DashboardPage),
          matching: find.byType(TimelineBar),
        ),
        findsNothing,
      );
      expect(
        tester.getTopLeft(find.byType(TimelineBar)).dy,
        greaterThanOrEqualTo(tester.getBottomLeft(find.byType(DeviceFrame)).dy),
      );
    });

    testWidgets('jumps to the time at once, with a skeleton until it settles', (
      tester,
    ) async {
      final live = FakeLiveRepository(answers: false);
      final factory = FakeAgentFactory(emitSurface: true);
      await tester.pumpApp(factory, liveRepository: live);
      await tester.pump();
      expect(find.byType(Surface), findsOneWidget);

      await tester.tap(_button('Day'));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 500));

      // The time is already the new one, and the old surface is gone. The new
      // agent waits for the backend before it asks.
      expect(find.text('4:30'), findsWidgets);
      expect(find.byType(SkeletonSurface), findsOneWidget);
      expect(factory.agents, hasLength(2));
      expect(factory.agents.last.sent, isEmpty);
      expect(factory.agents.first.disposed, isTrue);
      expect(live.moves.last, DayPhase.day.on(saturdayStart));

      await _play(tester);
      await tester.pump(const Duration(seconds: 1));

      expect(factory.agents, hasLength(2));
      expect(factory.agents.last.user, ana);
      expect(factory.agents.last.sent, [ana.prompt]);
      expect(find.byType(SkeletonSurface), findsNothing);
      expect(find.byType(Surface), findsOneWidget);
      expect(factory.agents.last.disposed, isFalse);
    });

    testWidgets('keeps the skeleton while the new reply is on its way', (
      tester,
    ) async {
      final factory = FakeAgentFactory(
        emitSurface: true,
        holdLater: Completer<void>(),
      );
      await tester.pumpApp(factory);
      for (var i = 0; i < 4; i++) {
        await tester.pump(const Duration(milliseconds: 200));
      }
      expect(find.byType(SkeletonSurface), findsNothing);

      await tester.tap(_button('Day'));
      await _play(tester);

      expect(factory.agents, hasLength(2));
      expect(factory.agents.last.sent, [ana.prompt]);
      expect(find.byType(SkeletonSurface), findsOneWidget);
      expect(find.byType(Surface), findsNothing);
    });

    testWidgets('reports a new dashboard that fails', (tester) async {
      final factory = FakeAgentFactory(
        emitSurface: true,
        failLater: Exception('boom'),
      );
      await tester.pumpApp(factory);
      await tester.pump();

      await tester.tap(_button('Day'));
      await _play(tester);

      expect(factory.agents, hasLength(2));
      expect(find.text('Could not build the dashboard.'), findsOneWidget);
      expect(find.byType(Surface), findsNothing);
    });

    testWidgets('keeps the skeleton when the new request breaks', (
      tester,
    ) async {
      final factory = FakeAgentFactory(
        emitSurface: true,
        failLater: StateError('closed'),
      );
      await tester.pumpApp(factory);
      await tester.pump();

      await tester.tap(_button('Day'));
      await _play(tester);

      expect(factory.agents.last.disposed, isFalse);
      expect(find.byType(SkeletonSurface), findsOneWidget);
      expect(tester.takeException(), isNull);
    });

    testWidgets('a refresh that was on its way does not outlive a jump', (
      tester,
    ) async {
      final hold = Completer<void>();
      final live = FakeLiveRepository();
      final factory = FakeAgentFactory(emitSurface: true);
      await tester.pumpApp(factory, liveRepository: live);
      await tester.pump();
      factory.agents.single.refreshHold = hold;
      live.emit(const DataChanged(users: ['ana']));
      await tester.pump();
      expect(factory.agents.single.refreshed, [ana.prompt]);

      live.answers = false;
      await tester.tap(_button('Day'));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 500));
      hold.complete();
      await _drain(tester);

      // The refresh of the time left behind did not bring its surface back.
      expect(factory.agents, hasLength(2));
      expect(factory.agents.first.disposed, isTrue);
      expect(find.byType(Surface), findsNothing);
      // Let the backend's silence run out.
      await tester.pump(const Duration(seconds: 4));
    });

    testWidgets('refreshes the agent on screen, never a new one', (
      tester,
    ) async {
      final live = FakeLiveRepository();
      final factory = FakeAgentFactory(emitSurface: true);
      await tester.pumpApp(factory, liveRepository: live);
      await tester.pump();

      live
        ..emit(const DataChanged(users: ['ana']))
        ..emit(const DataChanged(users: ['ana']));
      await tester.pump();
      live.emit(const InboxReceived(userId: 'ana', unread: 1));
      await _drain(tester);

      // Folding the triggers into one request is the agent's queue's job.
      expect(factory.agents, hasLength(1));
      expect(factory.agents.single.refreshed, isNotEmpty);
      expect(factory.agents.single.refreshed.toSet(), {ana.prompt});
      expect(factory.agents.single.disposed, isFalse);
    });

    testWidgets('only the changed user refreshes', (tester) async {
      final live = FakeLiveRepository();
      final factory = FakeAgentFactory(emitSurface: true);
      await tester.pumpApp(factory, liveRepository: live);
      await tester.pump();

      live.emit(const DataChanged(users: ['marco']));
      await _drain(tester);
      expect(factory.agents.single.refreshed, isEmpty);

      live.emit(const DataChanged(users: ['ana']));
      await _drain(tester);
      expect(factory.agents.single.refreshed, [ana.prompt]);
    });

    testWidgets('keeps the surface when a refresh fails', (tester) async {
      final live = FakeLiveRepository();
      final factory = FakeAgentFactory(emitSurface: true);
      await tester.pumpApp(factory, liveRepository: live);
      await tester.pump();
      factory.agents.single.refreshFailure = Exception('boom');

      live.emit(const DataChanged(users: ['ana']));
      await _drain(tester);

      expect(factory.agents.single.refreshed, [ana.prompt]);
      expect(find.byType(Surface), findsOneWidget);
      expect(tester.takeException(), isNull);
    });

    testWidgets('leaves the skeleton to ask for itself', (tester) async {
      final live = FakeLiveRepository(answers: false);
      final factory = FakeAgentFactory(emitSurface: true);
      await tester.pumpApp(factory, liveRepository: live);
      await tester.pump();

      await tester.tap(_button('Day'));
      await tester.pump();
      live.emit(const DataChanged(users: ['ana']));
      await _drain(tester);

      expect(factory.agents.last.refreshed, isEmpty);
      expect(find.byType(SkeletonSurface), findsOneWidget);
      // Let the backend's silence run out.
      await tester.pump(const Duration(seconds: 4));
    });

    testWidgets('a refresh that lands after the user left is dropped', (
      tester,
    ) async {
      final hold = Completer<void>();
      final live = FakeLiveRepository();
      final factory = FakeAgentFactory(emitSurface: true);
      await tester.pumpApp(factory, liveRepository: live);
      await tester.pump();
      factory.agents.single.refreshHold = hold;
      live.emit(const DataChanged(users: ['ana']));
      await tester.pump();

      await tester.tap(find.text(marco.name));
      await tester.pump();
      hold.complete();
      await _drain(tester);

      expect(factory.agents.first.disposed, isTrue);
      expect(tester.takeException(), isNull);
    });

    testWidgets('disposes the session fading out when the page goes', (
      tester,
    ) async {
      final live = FakeLiveRepository(answers: false);
      final factory = FakeAgentFactory(emitSurface: true);
      await tester.pumpApp(factory, liveRepository: live);
      await tester.pump();

      await tester.tap(_button('Day'));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 50));
      expect(factory.agents.first.disposed, isFalse);

      await tester.pumpWidget(const SizedBox());

      expect(factory.agents.first.disposed, isTrue);
      expect(factory.agents.last.disposed, isTrue);
      // Let the backend's silence run out.
      await tester.pump(const Duration(seconds: 4));
    });

    testWidgets('connects the live connection and hangs up with the page', (
      tester,
    ) async {
      final live = FakeLiveRepository();
      await tester.pumpApp(FakeAgentFactory(), liveRepository: live);

      expect(live.connects, 1);
      expect(live.closes, 0);

      await tester.pumpWidget(const SizedBox());

      expect(live.closes, greaterThan(0));
    });

    testWidgets('keeps the clock on the panel on the scenario time', (
      tester,
    ) async {
      await tester.pumpApp(FakeAgentFactory(emitSurface: true));

      await tester.tap(_button('Day'));
      await _play(tester);

      expect(find.text('4:30'), findsOneWidget);
      expect(find.text('Sat, Oct 10'), findsOneWidget);
    });

    testWidgets('shows an error with retry when the demo cannot start', (
      tester,
    ) async {
      final repository = FakeScenarioRepository(failures: 1);
      final factory = FakeAgentFactory();
      await tester.pumpApp(factory, scenarioRepository: repository);

      expect(find.text('Try again'), findsOneWidget);
      expect(factory.agents, isEmpty);

      await tester.tap(find.text('Try again'));
      await tester.pump();
      await tester.pump();
      await tester.pump();

      expect(repository.resets, 1);
      expect(factory.agents, hasLength(1));
    });
  });
}
