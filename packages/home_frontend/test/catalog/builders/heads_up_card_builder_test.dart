import 'package:app_ui/app_ui.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:genui/genui.dart';
import 'package:home_frontend/src/catalog/builders/heads_up_card_builder.dart';

import 'pump_builder.dart';

const _close = {
  'command': {'deviceId': 'blinds', 'command': 'close'},
};

Map<String, Object?> _rain({Object? state = 'pending'}) => {
  'source': 'Weather',
  'variant': 'headsUp',
  'title': 'Rain starting in 20 min.',
  'message': 'Garage door is open',
  'timestamp': {'path': '/alerts/rain/at'},
  'actions': [
    {
      'label': 'Close garage',
      'isPrimary': true,
      'action': _close,
    },
    {
      'label': 'Blinds closed',
      'icon': 'blinds',
      'state': state,
      'action': _close,
    },
  ],
};

void main() {
  group('headsUpCardBuilder', () {
    testWidgets('renders the card and dispatches a pending action', (
      tester,
    ) async {
      final h = await pumpBuilder(
        tester,
        headsUpCardBuilder,
        'HeadsUpCard',
        _rain(),
        model: {'/alerts/rain/at': 'Just now'},
      );

      expect(find.text('Rain starting in 20 min.'), findsOneWidget);
      expect(find.text('Just now'), findsOneWidget);
      expect(find.textContaining('Weather'), findsOneWidget);

      await tester.tap(find.text('Blinds closed'));
      await tester.pump();

      expect(h.events.single.name, 'run_device_action');
      expect(h.events.single.context, {
        'progressLabel': 'Blinds closed',
        'deviceId': 'blinds',
        'command': 'close',
      });
    });

    testWidgets('a done state, bound or literal, shows a check', (
      tester,
    ) async {
      final h = await pumpBuilder(
        tester,
        headsUpCardBuilder,
        'HeadsUpCard',
        _rain(state: {'path': '/alerts/rain/blinds'}),
        model: {
          '/alerts/rain/at': 'Just now',
          '/alerts/rain/blinds': 'pending',
        },
      );
      expect(find.byIcon(AppIcons.byName('check')), findsNothing);

      h.data.update(DataPath('/alerts/rain/blinds'), 'done');
      await tester.pump();

      expect(find.byIcon(AppIcons.byName('check')), findsOneWidget);
      await tester.tap(find.text('Blinds closed'));
      await tester.pump();
      expect(h.events, isEmpty);
    });

    testWidgets('maps the urgent and unknown variants', (tester) async {
      for (final variant in ['urgent', 'other']) {
        await pumpBuilder(tester, headsUpCardBuilder, 'HeadsUpCard', {
          'variant': variant,
          'title': 'Door open',
        });

        expect(find.text('Door open'), findsOneWidget);
        expect(
          tester.widget<HeadsUpCard>(find.byType(HeadsUpCard)).variant,
          variant == 'urgent' ? HeadsUpVariant.urgent : HeadsUpVariant.headsUp,
        );
      }
    });

    for (final (spec, name, context) in [
      ({'scene': 'dinner'}, 'run_scene', {'sceneId': 'dinner'}),
      ({'undo': true}, 'undo_change', <String, Object?>{}),
      ({'ask': 'Remind me at 7:30'}, 'ask', {'text': 'Remind me at 7:30'}),
    ]) {
      testWidgets('a $name action dispatches the event built from its spec', (
        tester,
      ) async {
        final h = await pumpBuilder(tester, headsUpCardBuilder, 'HeadsUpCard', {
          'title': 'Door open',
          'actions': [
            {'label': 'Go', 'action': spec},
          ],
        });

        await tester.tap(find.text('Go'));
        await tester.pump();

        expect(h.events.single.name, name);
        expect(h.events.single.context, {'progressLabel': 'Go', ...context});
      });
    }

    testWidgets('an action whose spec names nothing is inert', (tester) async {
      final h = await pumpBuilder(tester, headsUpCardBuilder, 'HeadsUpCard', {
        'title': 'Door open',
        'actions': [
          {'label': 'Close', 'action': <String, Object?>{}},
        ],
      });

      await tester.tap(find.text('Close'));
      await tester.pump();

      expect(h.events, isEmpty);
      expect(tester.takeException(), isNull);
    });
  });
}
