import 'package:app_ui/app_ui.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../helpers/load_fonts.dart';
import '../../helpers/pump_component.dart';

/// The width of the card area, where the chips row runs edge to edge.
const _areaWidth = 1104.0;

/// The widest single digit hour clock in each locale the app ships. A two
/// digit hour beside three chips at the length limit can touch them.
const _widestClocks = [
  ClockDisplay(time: '9:59', period: 'PM', date: 'Wed, Sep 30'),
  ClockDisplay(time: '9:59', period: 'p. m.', date: 'mié, sept 30'),
  ClockDisplay(time: '9:59', period: 'p. m.', date: 'sáb, sept 30'),
];

void main() {
  setUpAll(loadFonts);

  group(ClockDisplay, () {
    testWidgets('shows the time, period and date', (tester) async {
      await tester.pumpComponent(
        const ClockDisplay(time: '4:30', period: 'PM', date: 'Sat, Oct 3'),
      );

      expect(find.text('4:30'), findsOneWidget);
      expect(find.text('PM'), findsOneWidget);
      expect(find.text('Sat, Oct 3'), findsOneWidget);
    });

    testWidgets('keeps the display size without stretching', (tester) async {
      // Bounded, as it is over the surface, so nothing in it can stretch.
      await tester.pumpWidget(
        MaterialApp(
          theme: AppTheme.light,
          home: const Align(
            alignment: Alignment.bottomLeft,
            child: ClockDisplay(time: '4:30', period: 'PM', date: 'Fri, Oct 2'),
          ),
        ),
      );

      expect(tester.getSize(find.byType(ClockDisplay)).height, 80);
    });

    for (final clock in _widestClocks) {
      testWidgets('fits before the longest chips row at ${clock.date}', (
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
          MaterialApp(
            theme: AppTheme.light,
            home: Align(
              alignment: Alignment.topLeft,
              child: SizedBox(
                width: _areaWidth,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    // Three chips short enough to sit beside the clock now
                    // that a pill is 64 high with 18 px text.
                    const ActionChips(
                      chips: [
                        ActionChipData(label: 'Tell guests 8', icon: 'chat'),
                        ActionChipData(label: 'Move preheat', icon: 'flame'),
                        ActionChipData(label: 'Chill wine', icon: 'wine'),
                      ],
                    ),
                    Align(alignment: Alignment.centerLeft, child: clock),
                  ],
                ),
              ),
            ),
          ),
        );

        // The sparkle leads the label, so the row starts at its icon.
        final chipsStart = tester.getTopLeft(find.byType(Icon).first).dx;
        final clockWidth = tester.getSize(find.byType(ClockDisplay)).width;
        // The chips stay on one line.
        expect(
          tester.getSize(find.byType(ActionChips)).height,
          ActionPill.height,
        );
        expect(
          chipsStart,
          greaterThanOrEqualTo(clockWidth + AppSpacing.gutter),
        );
      });
    }
  });
}
