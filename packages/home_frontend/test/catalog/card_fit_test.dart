import 'dart:io';

import 'package:app_ui/app_ui.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:genui/genui.dart';
import 'package:home_catalog/home_catalog.dart';
import 'package:home_frontend/src/catalog/widget_builders.dart';

/// Every card the catalog says is built for a cell, drawn in that cell with as
/// much content as the card takes, with the real fonts.
///
/// The catalog's `CardFit` is the one place a card's size is written down and
/// the prompt is rendered from it, so this is what keeps the prompt honest: a
/// card that overflows a cell it lists fails here. The cells are the ones on
/// the Figma component catalog, drawn at their real size.
const Map<String, Object?> _action = {
  'command': {'deviceId': 'oven', 'command': 'start'},
};

/// The most each card takes: every entry, stop, tile, action and row.
final Map<String, Map<String, Object?>> _full = {
  'CountdownCard': {
    'startsAt': '2026-10-10T19:00:00-05:00',
    'eyebrow': 'Guests in',
    'subtitle': 'Dinner at 7:00 PM · Dining Room',
    'tag': {'label': 'Dinner party · 6 guests', 'kind': 'info'},
  },
  'PlanTimeline': {
    'title': "Tonight's plan",
    'subtitle': 'Saturday, Oct 10',
    'tag': {'label': 'Now 4:30', 'kind': 'info'},
    'entries': [
      for (final (i, title) in [
        'Prep the rack',
        'Preheat the oven',
        'Roast goes in',
        'Start the dining scene',
        'Serve',
      ].indexed)
        {
          'time': '${6 + i ~/ 2}:${i.isEven ? '00' : '30'} PM',
          'title': title,
          'detail': 'Oven · 400 °F for the roast',
          'icon': 'oven',
        },
    ],
  },
  'DeviceCard': {
    'deviceId': 'oven',
    'name': 'Upstairs Office',
    'icon': 'thermostat',
    'tone': 'climate',
    'status': 'Heating to 70 °F · until 9 PM',
    'value': '68',
    'unit': '°F',
    'delta': '↑ from 66 °F',
    'isActive': true,
    'control': {'type': 'stepper'},
  },
  'TripCard': {
    'leaveBy': '4:50 PM',
    'previousLeaveBy': '5:00 PM',
    'tag': {'label': 'Updated just now', 'kind': 'updated'},
    'footer': {
      'icon': 'traffic',
      'text': 'Traffic building on Elm Ave, +10 min',
      'tone': 'warning',
    },
    'progress': {'percent': 40, 'icon': 'delivery'},
    'stops': [
      for (final name in ['School pickup', 'Grab the cake', 'Home'])
        {
          'icon': 'school',
          'title': name,
          'subtitle': 'Lincoln Elementary',
          'time': '5:15 PM',
          'emphasis': 'good',
        },
    ],
  },
  'ChargeCard': {
    'status': 'Plugged in',
    'percent': 82,
    'range': '190 mi range',
    'summary': 'Enough for both stops',
    'window': 'Charging tonight 9 PM – 6 AM',
    'windowIcon': 'clock',
    'tag': {'label': 'Not charging', 'kind': 'info'},
  },
  'SceneCard': {
    'sceneId': 'dinner_party',
    'name': 'Dinner party scene',
    'description': 'Dining Room · Starts 6:45 PM · 4 devices',
    'settings': ['Pendants 40%', 'Jazz on Nest Audio', '70 °F', 'Candle mode'],
  },
  'HeadsUpCard': {
    'source': 'Weather',
    'variant': 'headsUp',
    'title': 'Rain starting in 20 min, and the garage door is open.',
    'message': 'Garage door is open · Living room blinds are up',
    'timestamp': 'Just now',
    'actions': [
      {
        'label': 'Close garage when I leave',
        'isPrimary': true,
        'action': _action,
      },
      {
        'label': 'Close living room blinds',
        'icon': 'blinds',
        'action': _action,
      },
    ],
  },
  'ChangeSummary': {
    'eyebrow': 'Done · from your request at 5:40 PM',
    'title': 'Dinner moved to 8:00 PM',
    'changes': [
      for (final label in ['Oven preheat', 'Guest scene', 'Notified', 'Serve'])
        {
          'icon': 'oven',
          'label': label,
          'value': '7:00 PM',
          'previous': 'was 6:00 PM',
        },
    ],
  },
  'ShoppingList': {
    'listId': 'shopping',
    'title': 'Shopping for tonight',
    'subtitle': 'Missing from the fridge · dinner for 6',
    'items': [
      for (final (i, label) in [
        'Rack of lamb',
        'Heavy cream',
        'Red wine',
        'Fresh thyme',
        'Shallots',
        'Baguette',
      ].indexed)
        {
          'id': 'item$i',
          'label': label,
          'detail': '2 bottles',
          'checked': i.isEven,
        },
    ],
    'footerAction': {'label': 'Share list with Marco', 'icon': 'share'},
  },
};

Future<void> _loadFonts() async {
  const faces = {
    'packages/app_ui/HostGrotesk': '../app_ui/assets/fonts/HostGrotesk.ttf',
    'packages/app_ui/RobotoMono': '../app_ui/assets/fonts/RobotoMono.ttf',
  };
  for (final MapEntry(key: family, value: path) in faces.entries) {
    final bytes = File(path).readAsBytesSync();
    final loader = FontLoader(family)
      ..addFont(Future.value(ByteData.sublistView(bytes)));
    await loader.load();
  }
}

void main() {
  setUpAll(_loadFonts);

  final cards = [
    for (final component in homeCatalog.components.values)
      if (component.fit != null) component,
  ];

  test('every card has content to draw', () {
    expect(_full.keys.toSet(), cards.map((c) => c.name).toSet());
  });

  for (final card in cards) {
    for (final cell in card.fit!.cells) {
      testWidgets('${card.name} fills ${cell.label} without overflowing', (
        tester,
      ) async {
        final data = DataContext(InMemoryDataModel(), DataPath('/'));
        final size = Size(cell.width, cell.height);
        tester.view
          ..devicePixelRatio = 1
          ..physicalSize = const Size(1400, 900);
        addTearDown(tester.view.reset);

        await tester.pumpWidget(
          MaterialApp(
            theme: AppTheme.light,
            home: Scaffold(
              body: Align(
                alignment: Alignment.topLeft,
                child: SizedBox.fromSize(
                  size: size,
                  child: Builder(
                    builder: (buildContext) => widgetBuilders[card.name]!(
                      CatalogItemContext(
                        data: _full[card.name]!,
                        id: 'id',
                        type: card.name,
                        buildChild: (id, [dataContext]) => const SizedBox(),
                        dispatchEvent: (_) {},
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
          ),
        );

        expect(tester.takeException(), isNull);
        // ChangeSummary draws its own shell, and the cards with a glow draw
        // theirs as a clipped round rect; every other card is an AppCard.
        final glowShell = find.byWidgetPredicate(
          (w) =>
              w is ClipRRect &&
              w.borderRadius == BorderRadius.circular(AppSpacing.cardRadius),
        );
        final shell = find.byType(ChangeSummary).evaluate().isNotEmpty
            ? find.byType(ChangeSummary)
            : find.byType(AppCard).evaluate().isNotEmpty
            ? find.byType(AppCard)
            : glowShell;
        expect(shell, findsOneWidget);
        expect(tester.getSize(shell).width, size.width);
      });
    }
  }
}
