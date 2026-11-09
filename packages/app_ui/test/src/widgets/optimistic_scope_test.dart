import 'package:app_ui/app_ui.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../helpers/pump_component.dart';

/// Pumps the widget [build] returns for the current props, inside a scope whose
/// revision [revision] drives.
Future<void> _pump(
  WidgetTester tester, {
  required ValueNotifier<int> revision,
  required ValueNotifier<Object?> prop,
  required Widget Function(Object? prop) build,
}) {
  return tester.pumpComponent(
    ValueListenableBuilder<int>(
      valueListenable: revision,
      builder: (_, rev, _) => OptimisticScope(
        revision: rev,
        child: ValueListenableBuilder<Object?>(
          valueListenable: prop,
          builder: (_, value, _) => build(value),
        ),
      ),
    ),
  );
}

bool _on(WidgetTester tester) =>
    tester.widget<AppSwitch>(find.byType(AppSwitch)).value;

void main() {
  group(OptimisticScope, () {
    testWidgets('of is 0 without a scope', (tester) async {
      late int seen;
      await tester.pumpComponent(
        Builder(
          builder: (context) {
            seen = OptimisticScope.of(context);
            return const SizedBox();
          },
        ),
      );

      expect(seen, 0);
    });

    testWidgets('notifies dependents only when the revision changes', (
      tester,
    ) async {
      var builds = 0;
      // One instance, so only the scope can make it rebuild.
      final probe = Builder(
        builder: (context) {
          OptimisticScope.of(context);
          builds++;
          return const SizedBox();
        },
      );
      Widget scope(int revision) =>
          OptimisticScope(revision: revision, child: probe);
      await tester.pumpComponent(scope(1));
      await tester.pumpComponent(scope(1));
      expect(builds, 1);

      await tester.pumpComponent(scope(2));
      expect(builds, 2);
    });
  });

  group('DeviceCard optimism', () {
    Widget card(Object? isActive) => DeviceCard(
      name: 'Oven',
      status: 'On',
      isActive: isActive! as bool,
      controlType: DeviceControlType.toggle,
      onToggle: (_) {},
    );

    testWidgets('the switch flips at once and resets on a new revision', (
      tester,
    ) async {
      final revision = ValueNotifier(0);
      final prop = ValueNotifier<Object?>(true);
      await _pump(tester, revision: revision, prop: prop, build: card);

      await tester.tap(find.byType(AppSwitch));
      await tester.pump();
      expect(_on(tester), isFalse);

      revision.value = 1;
      await tester.pump();
      expect(_on(tester), isTrue);
    });

    testWidgets('the switch settles when its prop changes', (tester) async {
      final revision = ValueNotifier(0);
      final prop = ValueNotifier<Object?>(true);
      await _pump(tester, revision: revision, prop: prop, build: card);

      await tester.tap(find.byType(AppSwitch));
      await tester.pump();
      prop.value = false;
      await tester.pump();
      expect(_on(tester), isFalse);

      // The override is gone: a later prop change shows through.
      prop.value = true;
      await tester.pump();
      expect(_on(tester), isTrue);
    });

    testWidgets('the stepper counts at once and resets on a new revision', (
      tester,
    ) async {
      final revision = ValueNotifier(0);
      final prop = ValueNotifier<Object?>('70');
      await _pump(
        tester,
        revision: revision,
        prop: prop,
        build: (value) => DeviceCard(
          name: 'Office',
          status: 'Heating',
          value: value! as String,
          controlType: DeviceControlType.stepper,
          onIncrement: () {},
          onDecrement: () {},
        ),
      );

      await tester.tap(find.byIcon(Icons.add));
      await tester.tap(find.byIcon(Icons.add));
      await tester.tap(find.byIcon(Icons.remove));
      await tester.pump();
      expect(find.text('71'), findsOneWidget);

      revision.value = 1;
      await tester.pump();
      expect(find.text('70'), findsOneWidget);

      prop.value = '75';
      await tester.pump();
      expect(find.text('75'), findsOneWidget);
    });

    testWidgets('a stepper over a non-numeric value only calls back', (
      tester,
    ) async {
      var taps = 0;
      await tester.pumpComponent(
        DeviceCard(
          name: 'Lock',
          status: 'Door',
          value: 'Locked',
          controlType: DeviceControlType.stepper,
          onIncrement: () => taps++,
        ),
      );

      await tester.tap(find.byIcon(Icons.add));
      await tester.pump();

      expect(taps, 1);
      expect(find.text('Locked'), findsOneWidget);
    });
  });

  group('ShoppingList optimism', () {
    Widget list(Object? checked) => ShoppingList(
      title: 'Shopping',
      items: [
        ShoppingItem(id: 'a', label: 'Ribs', checked: checked! as bool),
        const ShoppingItem(id: 'b', label: 'Cream'),
      ],
      onToggle: (_, {required checked}) {},
    );

    testWidgets('a tick shows at once and resets on a new revision', (
      tester,
    ) async {
      final revision = ValueNotifier(0);
      final prop = ValueNotifier<Object?>(false);
      await _pump(tester, revision: revision, prop: prop, build: list);
      expect(find.text('2'), findsOneWidget);

      await tester.tap(find.text('Ribs'));
      await tester.pump();
      expect(find.text('1'), findsOneWidget);

      revision.value = 1;
      await tester.pump();
      expect(find.text('2'), findsOneWidget);
    });

    testWidgets('a tick settles when its item changes', (tester) async {
      final revision = ValueNotifier(0);
      final prop = ValueNotifier<Object?>(false);
      await _pump(tester, revision: revision, prop: prop, build: list);

      await tester.tap(find.text('Ribs'));
      await tester.pump();
      prop.value = true;
      await tester.pump();
      expect(find.text('1'), findsOneWidget);

      // A tap on an untouched row and a removed item leave nothing behind.
      await tester.tap(find.text('Cream'));
      await tester.pump();
      expect(find.text('0'), findsOneWidget);
      await tester.pumpComponent(
        const ShoppingList(
          title: 'Shopping',
          items: [ShoppingItem(id: 'z', label: 'Z')],
        ),
      );
      expect(find.text('1'), findsOneWidget);
    });
  });
}
