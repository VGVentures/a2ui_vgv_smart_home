import 'package:app_ui/app_ui.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:genui/genui.dart';
import 'package:home_frontend/src/catalog/builders/scene_card_builder.dart';

import 'pump_builder.dart';

void main() {
  group('sceneCardBuilder', () {
    testWidgets('ready shows Start and dispatches the action', (tester) async {
      final harness = await pumpBuilder(tester, sceneCardBuilder, 'SceneCard', {
        'sceneId': 'dinner',
        'name': 'Dinner party scene',
        'description': 'Dining Room · 4 devices',
        'settings': ['Pendants 40 %', 7, '70 °F'],
      });

      final card = tester.widget<SceneCard>(find.byType(SceneCard));
      expect(card.tone, AppTone.lighting);
      expect(card.icon, 'scene');
      expect(card.settings, ['Pendants 40 %', '70 °F']);

      await tester.tap(find.text('Start'));

      expect(harness.events.single.name, 'run_scene');
      expect(harness.events.single.context, {
        'progressLabel': 'Start Dinner party scene',
        'sceneId': 'dinner',
      });
    });

    testWidgets('the progress label uses the action label, trimmed to 40', (
      tester,
    ) async {
      final harness = await pumpBuilder(tester, sceneCardBuilder, 'SceneCard', {
        'sceneId': 'movie',
        'name': 'A very long scene name for the living room cinema',
        'actionLabel': 'Play',
      });

      await tester.tap(find.text('Play'));

      final label = harness.events.single.context['progressLabel']! as String;
      expect(label, 'Play A very long scene name for the livi');
      expect(label.length, lessThanOrEqualTo(40));
    });

    testWidgets('without a sceneId the button does nothing', (tester) async {
      final harness = await pumpBuilder(tester, sceneCardBuilder, 'SceneCard', {
        'name': 'Scene',
      });

      await tester.tap(find.text('Start'));

      expect(harness.events, isEmpty);
    });

    testWidgets('running shows On and honors tone, icon and label', (
      tester,
    ) async {
      await pumpBuilder(tester, sceneCardBuilder, 'SceneCard', {
        'name': 'Dinner party scene',
        'state': 'running',
        'tone': 'energy',
        'icon': 'light',
        'actionLabel': 'Go',
      });

      expect(find.text('On'), findsOneWidget);
      expect(find.text('Go'), findsNothing);
      expect(
        tester.widget<SceneCard>(find.byType(SceneCard)).tone,
        AppTone.energy,
      );
    });

    testWidgets('a bound state swaps the pill for the tag', (tester) async {
      final harness = await pumpBuilder(
        tester,
        sceneCardBuilder,
        'SceneCard',
        {
          'name': 'Scene',
          'state': {'path': '/scenes/dinner/state'},
        },
        model: {'/scenes/dinner/state': 'ready'},
      );
      expect(find.text('Start'), findsOneWidget);

      harness.data.update(DataPath('/scenes/dinner/state'), 'running');
      await tester.pump();

      expect(find.text('On'), findsOneWidget);
    });

    testWidgets('tolerates missing props', (tester) async {
      await pumpBuilder(tester, sceneCardBuilder, 'SceneCard', {});

      expect(tester.widget<SceneCard>(find.byType(SceneCard)).name, '');
    });
  });
}
