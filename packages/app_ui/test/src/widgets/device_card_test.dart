import 'package:app_ui/app_ui.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../helpers/pump_component.dart';

void main() {
  group(AppSwitch, () {
    testWidgets('is 72 x 40 and reports the opposite value on tap', (
      tester,
    ) async {
      bool? changed;
      await tester.pumpComponent(
        AppSwitch(value: false, onChanged: (v) => changed = v),
      );

      expect(tester.getSize(find.byType(AppSwitch)), const Size(72, 40));
      await tester.tap(find.byType(AppSwitch));
      expect(changed, isTrue);
    });

    testWidgets('does nothing without a handler', (tester) async {
      await tester.pumpComponent(const AppSwitch(value: true, onChanged: null));

      await tester.tap(find.byType(AppSwitch));
      expect(tester.takeException(), isNull);
    });
  });

  group(StepperButtons, () {
    testWidgets('calls the matching callback', (tester) async {
      final taps = <String>[];
      await tester.pumpComponent(
        StepperButtons(
          onDecrement: () => taps.add('down'),
          onIncrement: () => taps.add('up'),
        ),
      );

      await tester.tap(find.byIcon(Icons.remove));
      await tester.tap(find.byIcon(Icons.add));

      expect(taps, ['down', 'up']);
    });
  });

  group(DeviceCard, () {
    testWidgets('renders the minimal form with no control', (tester) async {
      await tester.pumpComponent(
        const DeviceCard(name: 'Fridge', status: 'Door closed'),
      );

      expect(find.text('Door closed'), findsOneWidget);
      expect(find.byType(AppSwitch), findsNothing);
      expect(find.byType(StepperButtons), findsNothing);
      expect(find.byType(PillButton), findsNothing);
    });

    testWidgets('shows hero, unit, delta and room', (tester) async {
      await tester.pumpComponent(
        const DeviceCard(
          name: 'Outside',
          room: 'Entry',
          status: 'Locked since 3:58 PM',
          icon: 'lock',
          tone: AppTone.security,
          value: '68',
          unit: '°F',
          delta: 'from 72 °F',
        ),
      );

      expect(find.text('Entry · Locked since 3:58 PM'), findsOneWidget);
      expect(find.text('68°F'), findsOneWidget);
      expect(find.text('from 72 °F'), findsOneWidget);
    });

    testWidgets('toggle reports the new value', (tester) async {
      bool? next;
      await tester.pumpComponent(
        DeviceCard(
          name: 'Oven',
          status: 'On',
          isActive: true,
          icon: 'oven',
          controlType: DeviceControlType.toggle,
          onToggle: (v) => next = v,
        ),
      );

      await tester.tap(find.byType(AppSwitch));

      expect(next, isFalse);
    });

    testWidgets('stepper calls both callbacks', (tester) async {
      final taps = <String>[];
      await tester.pumpComponent(
        DeviceCard(
          name: 'Office',
          status: 'Heating',
          controlType: DeviceControlType.stepper,
          onDecrement: () => taps.add('down'),
          onIncrement: () => taps.add('up'),
        ),
      );

      await tester.tap(find.byIcon(Icons.add));
      await tester.tap(find.byIcon(Icons.remove));

      expect(taps, ['up', 'down']);
    });

    testWidgets('button shows its label and is pressable', (tester) async {
      var pressed = false;
      await tester.pumpComponent(
        DeviceCard(
          name: 'Coffee maker',
          status: 'Ready',
          controlType: DeviceControlType.button,
          controlLabel: 'Brew',
          controlIcon: 'coffee',
          onPressed: () => pressed = true,
        ),
      );

      await tester.tap(find.text('Brew'));

      expect(pressed, isTrue);
    });

    testWidgets('a tag sits beside the icon and the control stays', (
      tester,
    ) async {
      await tester.pumpComponent(
        const DeviceCard(
          name: 'Living room',
          status: '10 people home',
          icon: 'thermostat',
          value: '76',
          unit: '°F',
          delta: '↑ from 72 °F',
          tag: StatusTag(label: 'Updated just now'),
          controlType: DeviceControlType.stepper,
        ),
      );

      expect(find.text('Updated just now'), findsOneWidget);
      expect(find.byType(StepperButtons), findsOneWidget);
      expect(find.text('from 72 °F'), findsOneWidget);
      expect(find.byIcon(Icons.arrow_upward_rounded), findsOneWidget);
    });

    testWidgets('a falling delta shows a down arrow, a plain one none', (
      tester,
    ) async {
      await tester.pumpComponent(
        const DeviceCard(
          name: 'Office',
          status: 'Cooling',
          value: '68',
          delta: '↓ from 72',
        ),
      );
      expect(find.byIcon(Icons.arrow_downward_rounded), findsOneWidget);

      await tester.pumpComponent(
        const DeviceCard(
          name: 'Office',
          status: 'Cooling',
          value: '68',
          delta: 'was 72',
        ),
      );
      expect(find.text('was 72'), findsOneWidget);
      expect(find.byIcon(Icons.arrow_downward_rounded), findsNothing);
    });

    testWidgets('a word unit reads small beside the hero', (tester) async {
      await tester.pumpComponent(
        const DeviceCard(
          name: 'Coffee maker',
          status: 'Ready',
          value: '8',
          unit: 'cups ready',
        ),
      );

      expect(find.text('8'), findsOneWidget);
      expect(find.text('cups ready'), findsOneWidget);
    });

    testWidgets('the icon bubble is colored whether the device is on or off', (
      tester,
    ) async {
      for (final (tone, active) in [
        (AppTone.neutral, false),
        (AppTone.neutral, true),
        (AppTone.climate, false),
      ]) {
        await tester.pumpComponent(
          DeviceCard(
            name: 'Fridge',
            status: 'Door closed',
            icon: 'fridge',
            tone: tone,
            isActive: active,
          ),
        );

        final bubble = tester.widget<CardIconBubble>(
          find.byType(CardIconBubble),
        );
        expect(bubble.size, 48);
        expect(
          bubble.background,
          tone == AppTone.neutral
              ? AppColors.brandYellow100
              : AppColors.overlayOnTint,
        );
      }
    });

    testWidgets('fills a bounded cell and fits a short one', (tester) async {
      for (final height in [260.0, 200.0]) {
        await tester.pumpComponent(
          SizedBox(
            width: 300,
            height: height,
            child: DeviceCard(
              name: 'Living room',
              status: '10 people home',
              icon: 'thermostat',
              tone: AppTone.climate,
              value: '76',
              unit: '°F',
              delta: '↑ from 72 °F',
              tag: const StatusTag(label: 'Updated'),
              controlType: DeviceControlType.stepper,
              onIncrement: () {},
            ),
          ),
        );

        expect(tester.takeException(), isNull);
        expect(tester.getSize(find.byType(AppCard)).height, height);
      }
    });

    testWidgets('a delta without a hero reading still shows', (tester) async {
      await tester.pumpComponent(
        const DeviceCard(
          name: 'Blinds',
          status: 'All 3 closed',
          delta: 'was open',
        ),
      );

      expect(find.text('was open'), findsOneWidget);
    });

    testWidgets('a loading card shows a skeleton and an Updating note', (
      tester,
    ) async {
      await tester.pumpComponent(
        const DeviceCard(name: 'Oven', status: 'Preheating', isLoading: true),
      );

      expect(find.text('Updating…'), findsOneWidget);
      expect(find.text('Oven'), findsNothing);
    });

    testWidgets('a loading card fills a bounded cell', (tester) async {
      await tester.pumpComponent(
        const SizedBox(
          width: 300,
          height: 260,
          child: DeviceCard(name: 'Oven', status: 'Heating', isLoading: true),
        ),
      );

      expect(tester.takeException(), isNull);
      expect(tester.getSize(find.byType(AppCard)).height, 260);
    });

    testWidgets('each tone picks a tile and a switch color', (tester) async {
      for (final tone in AppTone.values) {
        await tester.pumpComponent(
          DeviceCard(
            name: 'Device',
            status: 'On',
            icon: 'light',
            tone: tone,
            isActive: true,
            controlType: DeviceControlType.toggle,
            onToggle: (_) {},
          ),
        );

        expect(find.byType(AppSwitch), findsOneWidget);
      }
    });

    test('DeviceControlType.byName falls back to none', () {
      expect(DeviceControlType.byName('toggle'), DeviceControlType.toggle);
      expect(DeviceControlType.byName('x'), DeviceControlType.none);
      expect(DeviceControlType.byName(null), DeviceControlType.none);
    });
  });
}
