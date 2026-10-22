import 'package:app_ui/app_ui.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:home_frontend/src/catalog/builders/action_chips_builder.dart';

import 'pump_builder.dart';

void main() {
  group('actionChipsBuilder', () {
    testWidgets('renders the label and chips, a chip without a spec is inert', (
      tester,
    ) async {
      final h = await pumpBuilder(tester, actionChipsBuilder, 'ActionChips', {
        'chips': [
          {'label': 'Preheat now', 'icon': 'flame', 'isPrimary': true},
          {'label': 'Nothing', 'action': <String, Object?>{}},
        ],
      });

      expect(find.text('Suggested'), findsOneWidget);

      await tester.tap(find.text('Nothing'));
      await tester.pump();
      await tester.tap(find.text('Preheat now'));
      await tester.pump();

      expect(h.events, isEmpty);
      expect(tester.takeException(), isNull);
    });

    for (final (spec, name, context) in [
      (
        {
          'command': {'deviceId': 'oven', 'command': 'on'},
        },
        'run_device_action',
        {'deviceId': 'oven', 'command': 'on'},
      ),
      ({'scene': 'dinner'}, 'run_scene', {'sceneId': 'dinner'}),
      ({'undo': true}, 'undo_change', <String, Object?>{}),
      (
        {'ask': 'Tell guests dinner is at 8:00'},
        'ask',
        {'text': 'Tell guests dinner is at 8:00'},
      ),
    ]) {
      testWidgets('a $name chip dispatches the event built from its spec', (
        tester,
      ) async {
        final h = await pumpBuilder(tester, actionChipsBuilder, 'ActionChips', {
          'chips': [
            {'label': 'Do it', 'action': spec},
          ],
        });

        await tester.tap(find.text('Do it'));
        await tester.pump();

        expect(h.events, hasLength(1));
        expect(h.events.single.name, name);
        expect(h.events.single.context, {'progressLabel': 'Do it', ...context});
      });
    }

    testWidgets('uses a custom label and the isPrimary chip', (tester) async {
      await pumpBuilder(tester, actionChipsBuilder, 'ActionChips', {
        'label': 'Next',
        'chips': [
          {'label': 'One'},
          {'label': 'Two', 'isPrimary': true},
        ],
      });

      expect(find.text('Next'), findsOneWidget);
      final two = tester.widget<Material>(
        find
            .ancestor(of: find.text('Two'), matching: find.byType(Material))
            .first,
      );
      expect(two.color, AppColors.ink);
    });

    testWidgets('tolerates missing chips', (tester) async {
      await pumpBuilder(tester, actionChipsBuilder, 'ActionChips', {});

      expect(tester.takeException(), isNull);
    });
  });
}
