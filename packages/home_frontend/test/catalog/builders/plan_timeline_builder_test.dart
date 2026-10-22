import 'package:app_ui/app_ui.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:genui/genui.dart';
import 'package:home_frontend/src/catalog/builders/plan_timeline_builder.dart';

import 'pump_builder.dart';

void main() {
  group('planTimelineBuilder', () {
    testWidgets('renders literal props', (tester) async {
      await pumpBuilder(tester, planTimelineBuilder, 'PlanTimeline', {
        'title': "Tonight's plan",
        'subtitle': 'Friday, Oct 2',
        'tag': {'label': 'Now 4:30', 'kind': 'info', 'icon': 'clock'},
        'entries': [
          {
            'time': '6:00 PM',
            'title': 'Preheat oven',
            'icon': 'oven',
            'detail': '400 °F',
          },
          {
            'time': '7:00 PM',
            'title': 'Guests',
            'previousTime': '6:00',
            'changedBy': 'Ana',
            'status': 'moved',
          },
        ],
      });

      expect(find.text("Tonight's plan"), findsOneWidget);
      expect(find.text('Friday, Oct 2'), findsOneWidget);
      expect(find.text('Now 4:30'), findsOneWidget);
      expect(find.text('400 °F'), findsOneWidget);
      expect(find.text('was 6:00 · Ana'), findsOneWidget);
    });

    testWidgets('reads the compact density', (tester) async {
      await pumpBuilder(tester, planTimelineBuilder, 'PlanTimeline', {
        'density': 'compact',
        'subtitle': 'Hidden',
        'entries': [
          {'time': '7:00 PM', 'title': 'One', 'status': 'unchanged'},
        ],
      });

      expect(find.text('Hidden'), findsNothing);
      expect(find.text('Unchanged'), findsOneWidget);
    });

    testWidgets('follows bound entries and tag', (tester) async {
      final h = await pumpBuilder(
        tester,
        planTimelineBuilder,
        'PlanTimeline',
        {
          'tag': {'path': '/plan/tag'},
          'entries': {'path': '/plan/entries'},
        },
        model: {
          '/plan/tag': {'label': 'New', 'kind': 'new'},
          '/plan/entries': [
            {'time': '7:00 PM', 'title': 'Before'},
          ],
        },
      );
      expect(find.text('Before'), findsOneWidget);
      expect(find.text('New'), findsOneWidget);

      h.data.update(DataPath('/plan/entries'), [
        {'time': '8:00 PM', 'title': 'After', 'previousTime': '7:00'},
      ]);
      h.data.update(DataPath('/plan/tag'), {'label': 'Updated'});
      await tester.pump();

      expect(find.text('After'), findsOneWidget);
      expect(find.text('was 7:00'), findsOneWidget);
      expect(find.text('Updated'), findsOneWidget);
    });

    testWidgets('skips a tag without a label', (tester) async {
      await pumpBuilder(tester, planTimelineBuilder, 'PlanTimeline', {
        'tag': {'kind': 'new'},
        'entries': [
          {'time': '7:00 PM', 'title': 'One'},
        ],
      });

      expect(find.byType(StatusTag), findsNothing);
    });

    testWidgets('dresses the tag by its kind', (tester) async {
      Future<StatusTag> tagFor(Map<String, Object?> tag) async {
        await pumpBuilder(tester, planTimelineBuilder, 'PlanTimeline', {
          'tag': tag,
          'entries': [
            {'time': '7:00 PM', 'title': 'One'},
          ],
        });
        return tester.widget<StatusTag>(find.byType(StatusTag));
      }

      final changed = await tagFor({
        'label': 'Changed by Ana',
        'kind': 'moved',
      });
      expect(changed.icon, 'edit');
      expect(changed.tint, AppTone.climate.wash);
      expect(changed.ink, AppTone.climate.ink);

      final updated = await tagFor({'label': 'Updated', 'kind': 'updated'});
      expect(updated.tint, const Color(0xFFECEAE5));

      final now = await tagFor({'label': 'Now 4:30'});
      expect(now.dot, AppColors.spark);
      expect(now.ink, AppColors.ink2);

      final withIcon = await tagFor({'label': 'Now', 'icon': 'clock'});
      expect(withIcon.dot, isNull);
      expect(withIcon.ink, AppColors.ink);
    });
  });
}
