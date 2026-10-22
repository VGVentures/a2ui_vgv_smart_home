import 'package:app_ui/app_ui.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:genui/genui.dart';
import 'package:home_frontend/src/catalog/builders/countdown_card_builder.dart';

import 'pump_builder.dart';

void main() {
  group('parseWallTime', () {
    test('keeps the wall time and drops the offset', () {
      final expected = DateTime(2026, 10, 10, 19);

      expect(parseWallTime('2026-10-10T19:00:00-05:00'), expected);
      expect(parseWallTime('2026-10-10T19:00:00Z'), expected);
      expect(parseWallTime('2026-10-10T19:00:00'), expected);
      expect(parseWallTime('2026-10-10 19:00'), expected);
      expect(parseWallTime(' 2026-10-10T19:00:00+02:00 '), expected);
    });

    test('is null for what is not a time', () {
      expect(parseWallTime('soon'), isNull);
    });
  });

  group('countdownCardBuilder', () {
    final now = DateTime(2026, 10, 2, 16, 30);
    final startsAt = DateTime(2026, 10, 2, 19).toIso8601String();

    Future<BuilderHarness> pump(
      WidgetTester tester,
      Map<String, Object?> component, {
      Map<String, Object?> model = const {},
    }) async {
      final h = await pumpBuilder(
        tester,
        (context) => NowScope(
          now: () => now,
          child: countdownCardBuilder(context),
        ),
        'CountdownCard',
        component,
        model: model,
      );
      return h;
    }

    testWidgets('renders literal props with the countdown', (tester) async {
      await pump(tester, {
        'startsAt': startsAt,
        'eyebrow': 'Guests in',
        'subtitle': 'Dinner at 7:00 PM',
        'tag': {'label': '6 guests', 'icon': 'guests', 'kind': 'info'},
        'tone': 'energy',
      });

      expect(find.text('2h 30m'), findsOneWidget);
      expect(find.text('Guests in'), findsOneWidget);
      expect(find.text('Dinner at 7:00 PM'), findsOneWidget);
      expect(find.text('6 guests'), findsOneWidget);
    });

    testWidgets('recomputes when the bound startsAt changes', (tester) async {
      final h = await pump(
        tester,
        {
          'startsAt': {'path': '/events/dinner/startsAt'},
          'subtitle': {'path': '/events/dinner/subtitle'},
        },
        model: {
          '/events/dinner/startsAt': startsAt,
          '/events/dinner/subtitle': 'Dinner at 7:00 PM',
        },
      );
      expect(find.text('2h 30m'), findsOneWidget);

      h.data
        ..update(
          DataPath('/events/dinner/startsAt'),
          DateTime(2026, 10, 2, 20).toIso8601String(),
        )
        ..update(DataPath('/events/dinner/subtitle'), 'Dinner at 8:00 PM');
      await tester.pump();

      expect(find.text('3h 30m'), findsOneWidget);
      expect(find.text('Dinner at 8:00 PM'), findsOneWidget);
    });

    testWidgets('renders nothing without a valid startsAt', (tester) async {
      await pump(tester, {'startsAt': 'soon'});
      expect(find.byType(CountdownCard), findsNothing);

      await pump(tester, {});
      expect(find.byType(CountdownCard), findsNothing);
      expect(find.byType(SizedBox), findsWidgets);
    });

    testWidgets('ignores a tag without a label', (tester) async {
      await pump(tester, {
        'startsAt': startsAt,
        'tag': {'kind': 'new'},
      });

      expect(find.byType(StatusTag), findsNothing);
    });
  });
}
