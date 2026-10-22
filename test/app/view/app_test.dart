import 'package:a2ui_vgv_smart_home/dashboard/view/dashboard_page.dart';
import 'package:a2ui_vgv_smart_home/shell/device_frame.dart';
import 'package:app_ui/app_ui.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../helpers/fake_agent.dart';
import '../../helpers/helpers.dart';

void main() {
  group('App', () {
    testWidgets('renders the dashboard inside the device frame', (
      tester,
    ) async {
      await tester.pumpApp(FakeAgentFactory());
      expect(
        find.descendant(
          of: find.byType(DeviceFrame),
          matching: find.byType(DashboardPage),
        ),
        findsOneWidget,
      );
    });

    testWidgets('puts the morning kitchen behind the frame', (tester) async {
      await tester.pumpApp(FakeAgentFactory());

      expect(
        tester.widget<KitchenBackdrop>(find.byType(KitchenBackdrop)).light,
        KitchenLight.morning,
      );
    });

    testWidgets('requests the first user dashboard on load', (tester) async {
      final factory = FakeAgentFactory();
      await tester.pumpApp(factory);
      expect(factory.agents, hasLength(1));
      expect(factory.agents.single.user, ana);
      expect(factory.agents.single.sent, [ana.prompt]);
    });

    testWidgets('switching user rebuilds and requests again', (tester) async {
      final factory = FakeAgentFactory();
      await tester.pumpApp(factory);

      await tester.tap(find.text(marco.name));
      await tester.pump();

      expect(factory.agents, hasLength(2));
      expect(factory.agents.first.disposed, isTrue);
      expect(factory.agents.last.user, marco);
      expect(factory.agents.last.sent, [marco.prompt]);
    });

    testWidgets('switching back requests the first user again', (
      tester,
    ) async {
      final factory = FakeAgentFactory();
      await tester.pumpApp(factory);

      await tester.tap(find.text(marco.name));
      await tester.pump();
      await tester.tap(find.text(ana.name));
      await tester.pump();

      expect(factory.agents, hasLength(3));
      expect(factory.agents.last.user, ana);
    });
  });

  group('DeviceFrame', () {
    Future<Size> frameSize(WidgetTester tester, Size window) async {
      tester.view
        ..physicalSize = window
        ..devicePixelRatio = 1;
      addTearDown(tester.view.reset);
      await tester.pumpWidget(
        const MaterialApp(home: DeviceFrame(child: SizedBox.expand())),
      );
      return tester.getSize(find.byType(AspectRatio));
    }

    testWidgets('never exceeds tablet size', (tester) async {
      final size = await frameSize(tester, const Size(3000, 2000));
      expect(size, const Size(DeviceFrame.maxWidth, DeviceFrame.maxHeight));
    });

    testWidgets('shrinks on a small window keeping its ratio', (tester) async {
      final size = await frameSize(tester, const Size(600, 900));
      expect(size.width, 600);
      expect(
        size.width / size.height,
        closeTo(DeviceFrame.maxWidth / DeviceFrame.maxHeight, 0.001),
      );
    });
  });
}
