import 'package:app_ui/app_ui.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:genui/genui.dart';
import 'package:home_frontend/src/catalog/builders/trip_card_builder.dart';

import 'pump_builder.dart';

void main() {
  group('tripCardBuilder', () {
    testWidgets('renders literal props', (tester) async {
      await pumpBuilder(tester, tripCardBuilder, 'TripCard', {
        'leaveBy': '4:50 PM',
        'previousLeaveBy': '5:00 PM',
        'tag': {'label': 'Updated just now', 'kind': 'updated'},
        'footer': {
          'icon': 'traffic',
          'text': 'Traffic building, +10 min',
          'tone': 'warning',
        },
        'stops': [
          {
            'icon': 'school',
            'title': 'School pickup',
            'subtitle': 'Lincoln Elementary',
            'time': '5:15 PM',
            'emphasis': 'good',
          },
        ],
      });

      final card = tester.widget<TripCard>(find.byType(TripCard));
      expect(card.label, 'Leave by');
      expect(card.leaveBy, '4:50 PM');
      expect(card.previousLeaveBy, '5:00 PM');
      expect(card.tag, 'Updated just now');
      expect(card.tagKind, StatusTagKind.updated);
      expect(card.footer?.tone, TripFooterTone.warning);
      expect(card.stops.single.emphasis, TripStopEmphasis.good);
      expect(find.text('Lincoln Elementary'), findsOneWidget);
      expect(find.text('was 5:00 PM'), findsOneWidget);
    });

    testWidgets('reads the en route progress', (tester) async {
      await pumpBuilder(tester, tripCardBuilder, 'TripCard', {
        'leaveBy': '5:45 PM',
        'progress': {'percent': 40, 'icon': 'delivery'},
      });

      final card = tester.widget<TripCard>(find.byType(TripCard));
      expect(card.progress?.percent, 40);
      expect(card.progress?.icon, 'delivery');
    });

    testWidgets('an en route card without an icon uses the trip one', (
      tester,
    ) async {
      await pumpBuilder(tester, tripCardBuilder, 'TripCard', {
        'leaveBy': '5:45 PM',
        'progress': {'percent': 10},
      });

      expect(
        tester.widget<TripCard>(find.byType(TripCard)).progress?.icon,
        'trip',
      );
    });

    testWidgets('follows bound values', (tester) async {
      final harness = await pumpBuilder(
        tester,
        tripCardBuilder,
        'TripCard',
        {
          'leaveBy': {'path': '/trip/leaveBy'},
          'footer': {
            'text': {'path': '/trip/footer'},
          },
          'stops': {'path': '/trip/stops'},
        },
        model: {
          '/trip/leaveBy': '5:00 PM',
          '/trip/footer': 'Clear roads',
          '/trip/stops': [
            {'title': 'Home', 'time': '6:00 PM'},
          ],
        },
      );
      expect(find.text('Clear roads'), findsOneWidget);
      expect(find.text('Home'), findsOneWidget);

      harness.data
        ..update(DataPath('/trip/leaveBy'), '4:40 PM')
        ..update(DataPath('/trip/footer'), 'Traffic');
      await tester.pump();

      expect(tester.widget<TripCard>(find.byType(TripCard)).leaveBy, '4:40 PM');
      expect(find.text('Traffic'), findsOneWidget);
    });

    testWidgets('tolerates missing props', (tester) async {
      await pumpBuilder(tester, tripCardBuilder, 'TripCard', {
        'footer': <String, Object?>{},
        'stops': [<String, Object?>{}],
      });

      final card = tester.widget<TripCard>(find.byType(TripCard));
      expect(card.leaveBy, '');
      expect(card.footer, isNull);
      expect(card.tag, isNull);
    });
  });
}
