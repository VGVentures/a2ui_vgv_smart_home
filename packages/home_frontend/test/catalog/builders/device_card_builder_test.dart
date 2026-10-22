import 'package:app_ui/app_ui.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:genui/genui.dart';
import 'package:home_frontend/src/catalog/builders/device_card_builder.dart';

const _oven = <String, Object?>{
  'id': 'oven',
  'component': 'DeviceCard',
  'deviceId': 'oven',
  'name': 'Oven',
  'icon': 'oven',
  'status': {'path': '/devices/oven/status'},
  'value': {'path': '/devices/oven/temp'},
  'unit': '°F',
  'isActive': {'path': '/devices/oven/on'},
  'control': {
    'type': 'toggle',
  },
};

const _office = <String, Object?>{
  'id': 'office',
  'component': 'DeviceCard',
  'deviceId': 'office-thermostat',
  'name': 'Upstairs Office',
  'icon': 'thermostat',
  'tone': 'climate',
  'status': 'Heating to 70 °F',
  'value': {'path': '/devices/office/temp'},
  'unit': '°F',
  'control': {
    'type': 'stepper',
  },
};

const _coffee = <String, Object?>{
  'id': 'coffee',
  'component': 'DeviceCard',
  'deviceId': 'coffee',
  'name': 'Coffee maker',
  'icon': 'coffee',
  'status': 'Kitchen · water full, beans loaded',
  'value': '8',
  'unit': 'cups ready',
  'control': {
    'type': 'button',
    'label': 'Brew',
    'icon': 'coffee',
    'command': 'brew',
  },
};

class _Harness {
  _Harness(this.data) : events = [];

  final DataContext data;
  final List<UserActionEvent> events;
}

Future<_Harness> _pump(
  WidgetTester tester,
  Map<String, Object?> component, {
  Map<String, Object?> model = const {},
  ValueNotifier<int>? revision,
}) async {
  final data = DataContext(InMemoryDataModel(), DataPath('/'));
  model.forEach((path, value) => data.update(DataPath(path), value));
  final harness = _Harness(data);
  Widget scoped(Widget child) => revision == null
      ? child
      : ValueListenableBuilder<int>(
          valueListenable: revision,
          builder: (_, value, _) =>
              OptimisticScope(revision: value, child: child),
        );
  await tester.pumpWidget(
    scoped(
      MaterialApp(
        theme: AppTheme.light,
        home: Scaffold(
          body: Builder(
            builder: (buildContext) => deviceCardBuilder(
              CatalogItemContext(
                data: component,
                id: component['id']! as String,
                type: 'DeviceCard',
                buildChild: (id, [dataContext]) => const SizedBox(),
                dispatchEvent: (event) {
                  if (event is UserActionEvent) harness.events.add(event);
                },
                buildContext: buildContext,
                dataContext: data,
                getComponent: (_) => null,
                getCatalogItem: (_) => null,
                surfaceId: 's',
                reportError: (_, _) {},
              ),
            ),
          ),
        ),
      ),
    ),
  );
  return harness;
}

const _literalToggle = <String, Object?>{
  'id': 'fridge',
  'deviceId': 'fridge',
  'name': 'Fridge',
  'status': 'Closed',
  'isActive': true,
  'control': {
    'type': 'toggle',
  },
};

const _literalStepper = <String, Object?>{
  'id': 'office',
  'deviceId': 'office',
  'name': 'Office',
  'status': 'Heating',
  'value': '70',
  'control': {
    'type': 'stepper',
  },
};

bool _switchValue(WidgetTester tester) =>
    tester.widget<AppSwitch>(find.byType(AppSwitch)).value;

void main() {
  group('optimistic controls', () {
    testWidgets('a literal toggle flips at once and resets on failure', (
      tester,
    ) async {
      final revision = ValueNotifier(0);
      await _pump(tester, _literalToggle, revision: revision);
      expect(_switchValue(tester), isTrue);

      await tester.tap(find.byType(AppSwitch));
      await tester.pump();
      expect(_switchValue(tester), isFalse);

      revision.value = 1;
      await tester.pump();
      await tester.pump();
      expect(_switchValue(tester), isTrue);
    });

    testWidgets('a literal stepper counts at once and resets on failure', (
      tester,
    ) async {
      final revision = ValueNotifier(0);
      await _pump(tester, _literalStepper, revision: revision);

      await tester.tap(find.byIcon(Icons.add));
      await tester.pump();
      expect(find.text('71'), findsOneWidget);

      revision.value = 1;
      await tester.pump();
      await tester.pump();
      expect(find.text('70'), findsOneWidget);
    });

    testWidgets('a bound toggle reverts the written value on failure', (
      tester,
    ) async {
      final revision = ValueNotifier(0);
      final h = await _pump(
        tester,
        _oven,
        model: {
          '/devices/oven/status': 'On',
          '/devices/oven/temp': '400',
          '/devices/oven/on': true,
        },
        revision: revision,
      );

      await tester.tap(find.byType(AppSwitch));
      await tester.pump();
      expect(_switchValue(tester), isFalse);
      expect(h.data.getValue<bool>(DataPath('/devices/oven/on')), isFalse);

      revision.value = 1;
      await tester.pump();
      await tester.pump();

      expect(h.data.getValue<bool>(DataPath('/devices/oven/on')), isTrue);
      expect(_switchValue(tester), isTrue);
    });

    testWidgets('a bound stepper reverts to the first value after two taps', (
      tester,
    ) async {
      final revision = ValueNotifier(0);
      final h = await _pump(
        tester,
        {
          ..._office,
          'value': {'path': '/devices/office/temp'},
        },
        model: {'/devices/office/temp': '70'},
        revision: revision,
      );
      final plus = find.byIcon(Icons.add);

      await tester.tap(plus);
      await tester.pump();
      await tester.tap(plus);
      await tester.pump();
      expect(h.data.getValue<String>(DataPath('/devices/office/temp')), '72');

      revision.value = 1;
      await tester.pump();
      await tester.pump();

      expect(h.data.getValue<String>(DataPath('/devices/office/temp')), '70');
      expect(find.text('70°F'), findsOneWidget);
    });

    testWidgets('an unchanged revision reverts nothing', (tester) async {
      final revision = ValueNotifier(0);
      final h = await _pump(
        tester,
        _oven,
        model: {'/devices/oven/on': true},
        revision: revision,
      );

      await tester.tap(find.byType(AppSwitch));
      await tester.pump();
      revision.value = 0;
      await tester.pump();

      expect(h.data.getValue<bool>(DataPath('/devices/oven/on')), isFalse);
    });
  });

  group('default control', () {
    testWidgets('a device with an id and no control shows its switch', (
      tester,
    ) async {
      final h = await _pump(tester, {
        'id': 'oven',
        'deviceId': 'oven',
        'name': 'Oven',
        'status': 'Preheating',
        'isActive': true,
      });

      expect(_switchValue(tester), isTrue);
      await tester.tap(find.byType(AppSwitch));
      await tester.pump();

      expect(h.events.single.name, 'toggle_device');
    });

    testWidgets('control none asks for no control', (tester) async {
      await _pump(tester, {
        'id': 'oven',
        'deviceId': 'oven',
        'name': 'Oven',
        'status': 'Off',
        'control': {'type': 'none'},
      });

      expect(find.byType(AppSwitch), findsNothing);
    });

    testWidgets('a card without a device id has nothing to command', (
      tester,
    ) async {
      await _pump(tester, {
        'id': 'info',
        'name': 'Weather',
        'status': 'Clear',
      });

      expect(find.byType(AppSwitch), findsNothing);
    });
  });

  group('deviceCardBuilder', () {
    testWidgets('resolves bound props and rebuilds when they change', (
      tester,
    ) async {
      final h = await _pump(
        tester,
        _oven,
        model: {
          '/devices/oven/status': 'Preheats at 6:00 PM',
          '/devices/oven/temp': '400',
          '/devices/oven/on': true,
        },
      );

      expect(find.text('Preheats at 6:00 PM'), findsOneWidget);
      expect(find.text('400°F'), findsOneWidget);

      h.data.update(DataPath('/devices/oven/temp'), '425');
      await tester.pump();

      expect(find.text('425°F'), findsOneWidget);
    });

    testWidgets('toggle writes the bound path, then dispatches the value', (
      tester,
    ) async {
      final h = await _pump(
        tester,
        _oven,
        model: {
          '/devices/oven/status': 'On',
          '/devices/oven/temp': '400',
          '/devices/oven/on': true,
        },
      );

      await tester.tap(find.byType(AppSwitch));
      await tester.pump();

      expect(h.data.getValue<bool>(DataPath('/devices/oven/on')), isFalse);
      expect(h.events, hasLength(1));
      expect(h.events.single.name, 'toggle_device');
      expect(h.events.single.context, {
        'progressLabel': 'Turn off oven',
        'deviceId': 'oven',
        'on': false,
      });
    });

    testWidgets('toggle on a literal state still dispatches the new value', (
      tester,
    ) async {
      final h = await _pump(tester, {
        'id': 'fridge',
        'deviceId': 'fridge',
        'name': 'Fridge',
        'status': 'Closed',
        'isActive': true,
        'control': {
          'type': 'toggle',
        },
      });

      await tester.tap(find.byType(AppSwitch));
      await tester.pump();

      expect(h.events.single.name, 'toggle_device');
      expect(h.events.single.context, {
        'progressLabel': 'Turn off fridge',
        'deviceId': 'fridge',
        'on': false,
      });
    });

    testWidgets('toggling an off device says Turn on', (tester) async {
      final h = await _pump(tester, {
        'id': 'oven',
        'deviceId': 'oven',
        'name': 'Oven',
        'status': 'Off',
        'isActive': false,
        'control': {'type': 'toggle'},
      });

      await tester.tap(find.byType(AppSwitch));
      await tester.pump();

      expect(h.events.single.context, {
        'progressLabel': 'Turn on oven',
        'deviceId': 'oven',
        'on': true,
      });
    });

    testWidgets('stepper writes the bound value and dispatches direction', (
      tester,
    ) async {
      final h = await _pump(
        tester,
        _office,
        model: {'/devices/office/temp': '68'},
      );

      await tester.tap(find.byIcon(Icons.add));
      await tester.pump();
      expect(h.data.getValue<String>(DataPath('/devices/office/temp')), '69');
      expect(find.text('69°F'), findsOneWidget);

      await tester.tap(find.byIcon(Icons.remove));
      await tester.pump();
      await tester.tap(find.byIcon(Icons.remove));
      await tester.pump();

      expect(h.data.getValue<String>(DataPath('/devices/office/temp')), '67');
      expect(h.events.map((e) => e.name), everyElement('adjust_device'));
      expect(h.events.map((e) => e.context), [
        {
          'progressLabel': 'Raise upstairs office',
          'deviceId': 'office-thermostat',
          'direction': 'up',
        },
        {
          'progressLabel': 'Lower upstairs office',
          'deviceId': 'office-thermostat',
          'direction': 'down',
        },
        {
          'progressLabel': 'Lower upstairs office',
          'deviceId': 'office-thermostat',
          'direction': 'down',
        },
      ]);
    });

    testWidgets('stepper with a literal value dispatches without writing', (
      tester,
    ) async {
      final h = await _pump(tester, {
        ..._office,
        'value': '68',
      });

      await tester.tap(find.byIcon(Icons.add));
      await tester.pump();

      expect(h.events.single.context, {
        'progressLabel': 'Raise upstairs office',
        'deviceId': 'office-thermostat',
        'direction': 'up',
      });
    });

    testWidgets('stepper ignores a non numeric value', (tester) async {
      final h = await _pump(
        tester,
        _office,
        model: {'/devices/office/temp': 'Off'},
      );

      await tester.tap(find.byIcon(Icons.add));
      await tester.pump();

      expect(h.data.getValue<String>(DataPath('/devices/office/temp')), 'Off');
      expect(h.events, hasLength(1));
    });

    testWidgets('button dispatches the command', (tester) async {
      final h = await _pump(tester, _coffee);

      expect(find.text('8'), findsOneWidget);
      expect(find.text('cups ready'), findsOneWidget);
      await tester.tap(find.text('Brew'));
      await tester.pump();

      expect(h.events.single.name, 'run_device_action');
      expect(h.events.single.context, {
        'progressLabel': 'Brew',
        'deviceId': 'coffee',
        'command': 'brew',
      });
    });

    testWidgets('a button without a label says Run and the device', (
      tester,
    ) async {
      final h = await _pump(tester, {
        'id': 'x',
        'deviceId': 'x1',
        'name': 'Oven',
        'status': 's',
        'control': {'type': 'button', 'command': 'start'},
      });

      await tester.tap(find.byType(ActionPill));
      await tester.pump();

      expect(h.events.single.name, 'run_device_action');
      expect(h.events.single.context, {
        'progressLabel': 'Run oven',
        'deviceId': 'x1',
        'command': 'start',
      });
    });

    testWidgets('a button without a command does nothing', (tester) async {
      final h = await _pump(tester, {
        'id': 'x',
        'deviceId': 'x1',
        'name': 'Oven',
        'status': 's',
        'control': {'type': 'button', 'label': 'Go'},
      });

      await tester.tap(find.text('Go'));
      await tester.pump();

      expect(h.events, isEmpty);
    });

    testWidgets('renders a bound tag beside the icon and keeps the control', (
      tester,
    ) async {
      await _pump(
        tester,
        {
          'id': 'blinds',
          'name': 'Blinds',
          'status': 'All 3 closed',
          'tag': {'path': '/devices/blinds/tag'},
          'control': {'type': 'toggle'},
        },
        model: {
          '/devices/blinds/tag': {
            'label': 'Updated just now',
            'kind': 'updated',
          },
        },
      );

      expect(find.text('Updated just now'), findsOneWidget);
      expect(find.byType(AppSwitch), findsOneWidget);
    });

    testWidgets('a loading device draws the skeleton', (tester) async {
      await _pump(tester, {
        'id': 'oven',
        'deviceId': 'oven',
        'name': 'Oven',
        'status': 'Preheating',
        'isLoading': true,
      });

      expect(find.text('Updating…'), findsOneWidget);
      expect(find.text('Oven'), findsNothing);
    });

    testWidgets('renders without a control and tolerates numeric values', (
      tester,
    ) async {
      await _pump(
        tester,
        {
          'id': 'outside',
          'name': 'Outside',
          'status': 'Cloudy',
          'tone': 'weather',
          'value': {'path': '/w'},
          'delta': 'cooler',
        },
        model: {'/w': 61},
      );

      expect(find.text('61'), findsOneWidget);
      expect(find.text('cooler'), findsOneWidget);
      expect(find.byType(AppSwitch), findsNothing);
      expect(find.byType(StepperButtons), findsNothing);
    });

    testWidgets('a toggle without a deviceId does not react', (tester) async {
      final h = await _pump(tester, {
        'id': 'x',
        'name': 'X',
        'status': 's',
        'control': {'type': 'toggle'},
      });

      await tester.tap(find.byType(AppSwitch));
      await tester.pump();

      expect(h.events, isEmpty);
    });
  });
}
