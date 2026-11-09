import 'package:app_ui/app_ui.dart';
import 'package:flutter_test/flutter_test.dart';
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

    testWidgets('follows bound values', (tester) async {
      final harness = await pumpBuilder(
        tester,
        tripCardBuilder,
        'TripCard',
        {
          'leaveBy': {'@path': '/trip/leaveBy'},
          'footer': {
            'text': {'@path': '/trip/footer'},
          },
          'stops': {'@path': '/trip/stops'},
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

      harness
        ..write('/trip/leaveBy', '4:40 PM')
        ..write('/trip/footer', 'Traffic');
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
