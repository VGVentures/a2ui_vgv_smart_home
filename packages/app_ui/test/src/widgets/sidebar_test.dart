import 'package:app_ui/app_ui.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:material_symbols_icons/symbols.dart';

const _profiles = [
  SidebarProfile(name: 'Ana'),
  SidebarProfile(name: 'Marco'),
];

Future<void> _pump(
  WidgetTester tester, {
  int selectedIndex = 0,
  ValueChanged<int>? onProfileSelected,
  VoidCallback? onSettings,
  double height = 704,
}) {
  return tester.pumpWidget(
    MaterialApp(
      theme: AppTheme.light,
      home: Scaffold(
        body: Align(
          alignment: Alignment.topLeft,
          child: SizedBox(
            height: height,
            child: Sidebar(
              profiles: _profiles,
              selectedIndex: selectedIndex,
              onProfileSelected: onProfileSelected ?? (_) {},
              onSettings: onSettings ?? () {},
              settingsTooltip: 'Settings',
            ),
          ),
        ),
      ),
    ),
  );
}

void main() {
  group(Sidebar, () {
    testWidgets('lists the profiles and the navigation', (tester) async {
      await _pump(tester);

      expect(find.text('Ana'), findsOneWidget);
      expect(find.text('Marco'), findsOneWidget);
      expect(find.byIcon(Symbols.home_rounded), findsOneWidget);
      expect(find.byIcon(Symbols.settings_rounded), findsOneWidget);
    });

    testWidgets('shows the initial when a profile has no photo', (
      tester,
    ) async {
      await _pump(tester);

      expect(find.text('A'), findsOneWidget);
    });

    testWidgets('selects the tapped profile', (tester) async {
      final selected = <int>[];
      await _pump(tester, onProfileSelected: selected.add);

      await tester.tap(find.text('Marco'));

      expect(selected, [1]);
    });

    testWidgets('slides the highlight to the selected profile', (
      tester,
    ) async {
      await _pump(tester);
      final before = tester.getTopLeft(find.byType(AnimatedPositioned));

      await _pump(tester, selectedIndex: 1);
      await tester.pumpAndSettle();
      final after = tester.getTopLeft(find.byType(AnimatedPositioned));

      expect(after.dy, greaterThan(before.dy));
    });

    testWidgets('marks the selected profile for assistive tech', (
      tester,
    ) async {
      await _pump(tester, selectedIndex: 1);

      expect(
        tester.getSemantics(find.bySemanticsLabel('Marco')),
        isSemantics(
          label: 'Marco',
          isButton: true,
          isSelected: true,
          hasSelectedState: true,
        ),
      );
    });

    testWidgets('runs the settings action', (tester) async {
      var opened = false;
      await _pump(tester, onSettings: () => opened = true);

      await tester.tap(find.byIcon(Symbols.settings_rounded));

      expect(opened, isTrue);
    });

    testWidgets('scrolls instead of overflowing on a short screen', (
      tester,
    ) async {
      await _pump(tester, height: 300);

      expect(tester.takeException(), isNull);
    });
  });
}
