import 'dart:async';

import 'package:a2ui_vgv_smart_home/api_key/gemini_key_store.dart';
import 'package:a2ui_vgv_smart_home/clock/view/clock_view.dart';
import 'package:a2ui_vgv_smart_home/dashboard/agent_factory.dart';
import 'package:a2ui_vgv_smart_home/dashboard/view/dashboard_surface.dart';
import 'package:a2ui_vgv_smart_home/voice/view/voice_input.dart';
import 'package:app_ui/app_ui.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:home_frontend/home_frontend.dart';
import 'package:home_repository/home_repository.dart';

import '../helpers/fake_agent.dart';
import '../helpers/helpers.dart';

Future<void> settle(WidgetTester tester) async {
  for (var i = 0; i < 5; i++) {
    await tester.pump(const Duration(milliseconds: 20));
  }
}

void main() {
  group('MemberDashboard', () {
    testWidgets('renders the generated surface without the prompt bubble', (
      tester,
    ) async {
      await tester.pumpApp(FakeAgentFactory(emitSurface: true));
      await settle(tester);

      expect(find.byType(Surface, skipOffstage: false), findsOneWidget);
      expect(find.text(ana.prompt), findsNothing);
    });

    testWidgets('moves the surface with what the backend sends it', (
      tester,
    ) async {
      final live = FakeLiveRepository();
      final factory = FakeAgentFactory(emitSurface: true);
      await tester.pumpApp(factory, liveRepository: live);
      await settle(tester);

      const update = {
        'version': 'v0.9',
        'updateDataModel': {
          'surfaceId': 'dashboard',
          'path': '/devices/oven',
          'value': {'status': 'Preheating'},
        },
      };
      live.emit(const SurfaceMessageReceived(update));
      await settle(tester);

      // Only the agent on screen is told, once, and nothing is asked again.
      expect(factory.agents.single.applied, [update]);
      expect(factory.agents.single.sent, [ana.prompt]);
      expect(factory.agents.single.refreshed, isEmpty);
    });

    testWidgets('shows the VGV brand above the surface', (tester) async {
      await tester.pumpApp(FakeAgentFactory(emitSurface: true));
      await settle(tester);

      final lockup = find.byType(BrandLockup);
      expect(
        find.bySemanticsLabel('Very Good Ventures, A2UI Smart Home'),
        findsOneWidget,
      );
      expect(
        tester.getBottomLeft(lockup).dy,
        lessThan(tester.getTopLeft(find.byType(DashboardSurface)).dy),
      );
      // The ask bar stays on the right of the same row.
      final askBar = find.byType(VoiceInput);
      expect(
        tester.getCenter(lockup).dy,
        moreOrLessEquals(tester.getCenter(askBar).dy),
      );
      expect(
        tester.getTopLeft(askBar).dx,
        greaterThanOrEqualTo(tester.getTopRight(lockup).dx),
      );
      expect(
        tester.getTopRight(askBar).dx,
        moreOrLessEquals(tester.getTopRight(find.byType(DashboardSurface)).dx),
      );
    });

    testWidgets('puts the clock in the bottom-left corner of the surface', (
      tester,
    ) async {
      await tester.pumpApp(FakeAgentFactory(emitSurface: true));
      await settle(tester);

      expect(
        tester.getBottomLeft(find.byType(ClockView)),
        offsetMoreOrLessEquals(
          tester.getBottomLeft(find.byType(DashboardSurface)),
        ),
      );
    });

    testWidgets('gives the surface the app clock through NowScope', (
      tester,
    ) async {
      await tester.pumpApp(FakeAgentFactory(emitSurface: true));
      await settle(tester);

      final now = NowScope.maybeOf(
        tester.element(find.byType(Surface, skipOffstage: false)),
      );
      expect(now, isNotNull);
      expect(now!(), DateTime(2026, 10, 10, 7, 30));
    });

    testWidgets('surfaces an unexpected failure while still mounted', (
      tester,
    ) async {
      final errors = <Object>[];
      await runZonedGuarded(() async {
        await tester.pumpApp(FakeAgentFactory(failWith: StateError('boom')));
        await settle(tester);
      }, (error, _) => errors.add(error));

      expect(errors, [isA<StateError>()]);
    });

    testWidgets('ignores a failure after the user was switched away', (
      tester,
    ) async {
      final gate = Completer<void>();
      final factory = FakeAgentFactory(
        failWith: StateError('stream closed'),
        gate: gate,
      );
      await tester.pumpApp(factory);
      await tester.tap(find.text(marco.name));
      await tester.pump();

      gate.complete();
      await settle(tester);

      expect(factory.agents.first.disposed, isTrue);
      expect(tester.takeException(), isNull);
    });
  });

  group('HttpAgentFactory', () {
    test('creates an HTTP agent for a user', () {
      final factory = HttpAgentFactory(
        keys: GeminiKeyStore('key-1'),
        sessionId: 'visitor-0123456789abcdef',
        baseUri: Uri.parse('http://localhost:8080'),
      );
      expect(factory.create(ana), isA<HttpGenUIAgent>());
    });
  });
}
