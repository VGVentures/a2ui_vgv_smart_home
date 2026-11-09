import 'package:app_ui/app_ui.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../helpers/pump_component.dart';

Color? _barColor(WidgetTester tester) => tester
    .widget<LinearProgressIndicator>(find.byType(LinearProgressIndicator))
    .color;

void main() {
  group(ChargeCard, () {
    testWidgets('shows status, level, range, summary and window', (
      tester,
    ) async {
      await tester.pumpComponent(
        const ChargeCard(
          percent: 82,
          status: 'Plugged in',
          range: '190 mi range',
          summary: 'Enough for both stops',
          window: 'Charging tonight 9 PM - 6 AM',
          tag: 'Not charging',
        ),
      );

      expect(find.text('Car · Plugged in'), findsOneWidget);
      expect(find.text('82%'), findsOneWidget);
      expect(find.text('190 mi range'), findsOneWidget);
      expect(find.text('Enough for both stops'), findsOneWidget);
      expect(find.text('Charging tonight 9 PM - 6 AM'), findsOneWidget);
      expect(find.text('Not charging'), findsOneWidget);
      expect(find.byIcon(AppIcons.byName('clock')), findsOneWidget);
    });

    testWidgets('uses the savings icon and a plain title', (tester) async {
      await tester.pumpComponent(
        const ChargeCard(
          percent: 50,
          window: 'Off-peak',
          windowIcon: 'savings',
        ),
      );

      expect(find.text('Car'), findsOneWidget);
      expect(find.byIcon(AppIcons.byName('savings')), findsOneWidget);
    });

    testWidgets('turns the bar warm under 30 percent', (tester) async {
      await tester.pumpComponent(const ChargeCard(percent: 29));
      expect(_barColor(tester), AppColors.danger);

      await tester.pumpComponent(const ChargeCard(percent: 30));
      expect(_barColor(tester), AppTone.energy.ink);
    });

    testWidgets('clamps an out of range level', (tester) async {
      await tester.pumpComponent(const ChargeCard(percent: 140));

      expect(find.text('100%'), findsOneWidget);
    });

    testWidgets('builds from runtime values', (tester) async {
      await tester.pumpComponent(ChargeCard(percent: int.parse('64')));

      expect(find.text('64%'), findsOneWidget);
    });
  });
}
