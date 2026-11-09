import 'package:app_ui/app_ui.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../helpers/pump_component.dart';

void main() {
  group(formatCountdown, () {
    final start = DateTime(2026, 10, 2, 19);

    String at(DateTime now) => formatCountdown(start, now);

    test('hours and minutes', () {
      expect(at(DateTime(2026, 10, 2, 16, 30)), '2h 30m');
      expect(at(DateTime(2026, 10, 2, 16, 30, 20)), '2h 30m');
      expect(at(DateTime(2026, 10, 2, 18)), '1h 0m');
    });

    test('minutes under an hour', () {
      expect(at(DateTime(2026, 10, 2, 18, 15)), '45m');
      expect(at(DateTime(2026, 10, 2, 18, 58)), '2m');
    });

    test('Now within the last minute', () {
      expect(at(DateTime(2026, 10, 2, 18, 59, 30)), 'Now');
      expect(at(start), 'Now');
    });

    test('Started after the start', () {
      expect(at(DateTime(2026, 10, 2, 19, 0, 1)), 'Started');
      expect(at(DateTime(2026, 10, 2, 20)), 'Started');
    });

    test('counts in local minutes for a UTC start', () {
      final utc = DateTime.utc(2026, 10, 2, 19);
      expect(
        formatCountdown(
          utc,
          utc.toLocal().subtract(const Duration(minutes: 90)),
        ),
        '1h 30m',
      );
    });

    test('uses custom labels', () {
      expect(
        formatCountdown(start, start, nowLabel: 'Ahora'),
        'Ahora',
      );
      expect(
        formatCountdown(
          start,
          DateTime(2026, 10, 2, 20),
          startedLabel: 'Empezó',
        ),
        'Empezó',
      );
    });
  });

  group(CountdownCard, () {
    final start = DateTime(2026, 10, 2, 19);
    var now = DateTime(2026, 10, 2, 16, 30, 15);

    setUp(() => now = DateTime(2026, 10, 2, 16, 30, 15));

    Widget event({DateTime Function()? clock}) => CountdownCard(
      startsAt: start,
      now: clock ?? () => now,
      tag: const StatusTag(label: 'Dinner party · 6 guests'),
      eyebrow: 'Guests in',
      subtitle: 'Dinner at 7:00 PM · Dining Room',
    );

    testWidgets('shows the tag, eyebrow, countdown and subtitle', (
      tester,
    ) async {
      await tester.pumpComponent(event());

      expect(find.text('Dinner party · 6 guests'), findsOneWidget);
      expect(find.text('Guests in'), findsOneWidget);
      expect(find.text('2h 30m'), findsOneWidget);
      expect(find.text('Dinner at 7:00 PM · Dining Room'), findsOneWidget);
    });

    testWidgets('ticks on the minute boundary', (tester) async {
      await tester.pumpComponent(event());
      expect(find.text('2h 30m'), findsOneWidget);

      // 45 s to the boundary: not yet.
      now = DateTime(2026, 10, 2, 16, 31);
      await tester.pump(const Duration(seconds: 44));
      expect(find.text('2h 30m'), findsOneWidget);

      await tester.pump(const Duration(seconds: 1));
      expect(find.text('2h 29m'), findsOneWidget);
    });

    testWidgets('keeps ticking and reads Now, then Started', (tester) async {
      now = DateTime(2026, 10, 2, 18, 58, 30);
      await tester.pumpComponent(event());
      expect(find.text('1m'), findsNothing);
      expect(find.text('2m'), findsOneWidget);

      now = DateTime(2026, 10, 2, 18, 59, 30);
      await tester.pump(const Duration(seconds: 30));
      expect(find.text('Now'), findsOneWidget);

      now = DateTime(2026, 10, 2, 19, 1);
      await tester.pump(const Duration(seconds: 30));
      expect(find.text('Started'), findsOneWidget);
    });

    testWidgets('recomputes at once when startsAt changes', (tester) async {
      await tester.pumpComponent(event());
      await tester.pumpComponent(
        CountdownCard(startsAt: DateTime(2026, 10, 2, 20), now: () => now),
      );

      expect(find.text('3h 30m'), findsOneWidget);
    });

    testWidgets('stops its timer when disposed', (tester) async {
      await tester.pumpComponent(event());
      await tester.pumpWidget(const SizedBox());

      expect(tester.hasRunningAnimations, isFalse);
      // A leaked timer would fail the test at teardown.
    });

    testWidgets('reads the nearest NowScope', (tester) async {
      await tester.pumpComponent(
        NowScope(
          now: () => DateTime(2026, 10, 2, 18, 15),
          child: CountdownCard(startsAt: start),
        ),
      );

      expect(find.text('45m'), findsOneWidget);
    });

    testWidgets('follows a changed NowScope clock', (tester) async {
      Widget scoped(DateTime Function() clock) => NowScope(
        now: clock,
        child: CountdownCard(startsAt: start),
      );
      await tester.pumpComponent(scoped(() => DateTime(2026, 10, 2, 18, 15)));
      await tester.pumpComponent(scoped(() => DateTime(2026, 10, 2, 18, 30)));

      expect(find.text('30m'), findsOneWidget);
    });

    testWidgets('falls back to the device clock', (tester) async {
      await tester.pumpComponent(
        CountdownCard(startsAt: DateTime.now().add(const Duration(days: 1))),
      );

      expect(find.textContaining('h '), findsOneWidget);
      await tester.pumpWidget(const SizedBox());
    });

    testWidgets('fills a bounded cell and draws the tag in the tone ink', (
      tester,
    ) async {
      await tester.pumpComponent(
        SizedBox(width: 446, height: 260, child: event()),
      );

      expect(tester.takeException(), isNull);
      final tag = tester.widget<StatusTag>(find.byType(StatusTag));
      expect(tag.ink, AppTone.lighting.ink);
      expect(tag.tint, AppTone.lighting.wash);
      // The tag sits at the top and the text group at the bottom.
      final card = tester.getRect(find.byType(AppCard));
      expect(
        tester.getTopLeft(find.byType(StatusTag)).dy,
        card.top + AppSpacing.cardPaddingCompact,
      );
      expect(
        tester.getBottomLeft(find.text('Dinner at 7:00 PM · Dining Room')).dy,
        lessThanOrEqualTo(card.bottom - AppSpacing.cardPaddingCompact),
      );
    });

    testWidgets('keeps the ink and tint a tag names itself', (tester) async {
      await tester.pumpComponent(
        SizedBox(
          width: 446,
          height: 260,
          child: CountdownCard(
            startsAt: start,
            now: () => now,
            tag: const StatusTag(
              label: 'Own',
              tint: Color(0xFF123456),
              ink: Color(0xFF654321),
            ),
          ),
        ),
      );

      final tag = tester.widget<StatusTag>(find.byType(StatusTag));
      expect(tag.ink, const Color(0xFF654321));
      expect(tag.tint, const Color(0xFF123456));
    });

    testWidgets('scales down in a cell too short for its text', (
      tester,
    ) async {
      await tester.pumpComponent(
        SizedBox(width: 270, height: 200, child: event()),
      );
      expect(tester.takeException(), isNull);

      await tester.pumpComponent(
        SizedBox(
          width: 270,
          height: 200,
          child: CountdownCard(startsAt: start, now: () => now),
        ),
      );
      expect(tester.takeException(), isNull);
      expect(find.text('2h 30m'), findsOneWidget);
    });

    testWidgets('renders narrow and unbounded and without optional parts', (
      tester,
    ) async {
      await tester.pumpComponent(
        SizedBox(
          width: 352,
          child: CountdownCard(startsAt: start, now: () => now),
        ),
      );
      expect(find.text('2h 30m'), findsOneWidget);

      await tester.pumpComponent(
        Row(
          children: [CountdownCard(startsAt: start, now: () => now)],
        ),
      );
      expect(tester.takeException(), isNull);

      await tester.pumpComponent(
        Row(children: [event()]),
      );
      expect(tester.takeException(), isNull);
    });
  });
}
