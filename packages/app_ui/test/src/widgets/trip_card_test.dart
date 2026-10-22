import 'package:app_ui/app_ui.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../helpers/pump_component.dart';

void main() {
  group(TripCard, () {
    testWidgets('shows the label, hero time and stops', (tester) async {
      await tester.pumpComponent(
        const TripCard(
          leaveBy: '5:00 PM',
          footer: TripFooter(text: '14 min · light traffic'),
          stops: [
            TripStop(
              icon: 'school',
              title: 'School pickup',
              subtitle: 'Lincoln Elementary',
              time: '5:15 PM',
            ),
          ],
        ),
      );

      expect(find.text('Leave by'), findsOneWidget);
      expect(find.text('5:00'), findsOneWidget);
      expect(find.text('14 min · light traffic'), findsOneWidget);
      expect(find.text('School pickup'), findsOneWidget);
      expect(find.text('Lincoln Elementary'), findsOneWidget);
      expect(find.text('5:15'), findsOneWidget);
      expect(find.text('PM'), findsNWidgets(2));
      expect(find.textContaining('was '), findsNothing);
      expect(find.byType(StatusTag), findsNothing);
    });

    testWidgets('draws an en route track with the marker icon', (tester) async {
      await tester.pumpComponent(
        const TripCard(
          label: 'Arrives',
          leaveBy: '5:45 PM',
          progress: TripProgress(percent: 40, icon: 'delivery'),
        ),
      );

      expect(find.byIcon(AppIcons.byName('delivery')), findsOneWidget);
      expect(find.text('Arrives'), findsOneWidget);
    });

    testWidgets('holds the marker on the track out of range', (tester) async {
      await tester.pumpComponent(
        const TripCard(
          leaveBy: '5:45 PM',
          progress: TripProgress(percent: 140),
        ),
      );

      expect(tester.takeException(), isNull);
      expect(find.byIcon(AppIcons.byName('trip')), findsOneWidget);
    });

    testWidgets('shows the previous time, the tag and a warning footer', (
      tester,
    ) async {
      await tester.pumpComponent(
        const TripCard(
          leaveBy: '4:50 PM',
          previousLeaveBy: '5:00 PM',
          tag: 'Updated just now',
          tagKind: StatusTagKind.updated,
          footer: TripFooter(
            icon: 'traffic',
            text: 'Traffic building, +10 min',
            tone: TripFooterTone.warning,
          ),
        ),
      );

      expect(find.text('was 5:00 PM'), findsOneWidget);
      expect(find.text('Updated just now'), findsOneWidget);
      expect(find.byIcon(AppIcons.byName('traffic')), findsOneWidget);
    });

    testWidgets('draws a good stop in green and caps stops at three', (
      tester,
    ) async {
      await tester.pumpComponent(
        const TripCard(
          leaveBy: '5:00 PM',
          stops: [
            TripStop(
              title: 'A',
              time: '1:00 PM',
              emphasis: TripStopEmphasis.good,
            ),
            TripStop(title: 'B', time: '2:00 PM'),
            TripStop(title: 'C', time: '3:00 PM'),
            TripStop(title: 'D', time: '4:00 PM'),
          ],
        ),
      );

      expect(find.text('C'), findsOneWidget);
      expect(find.text('D'), findsNothing);
    });

    testWidgets('an en route card keeps the last two stops', (tester) async {
      await tester.pumpComponent(
        const TripCard(
          leaveBy: '5:45 PM',
          previousLeaveBy: '5:30 PM',
          progress: TripProgress(percent: 50, icon: 'delivery'),
          stops: [
            TripStop(title: 'A', time: '1:00 PM'),
            TripStop(title: 'B', time: '2:00 PM'),
            TripStop(title: 'C', time: '3:00 PM'),
          ],
        ),
      );

      expect(find.text('A'), findsNothing);
      expect(find.text('B'), findsOneWidget);
      expect(find.text('C'), findsOneWidget);
      expect(find.textContaining('was '), findsNothing);
    });

    testWidgets('keeps a time without a suffix whole', (tester) async {
      await tester.pumpComponent(const TripCard(leaveBy: '17:00'));

      expect(find.text('17:00'), findsOneWidget);
    });

    test('maps names to enums', () {
      expect(TripStopEmphasis.byName('good'), TripStopEmphasis.good);
      expect(TripStopEmphasis.byName(null), TripStopEmphasis.none);
      expect(TripFooterTone.byName('warning'), TripFooterTone.warning);
      expect(TripFooterTone.byName('x'), TripFooterTone.normal);
    });

    testWidgets('builds from runtime values', (tester) async {
      final percent = int.parse('40');
      final [home, on] = ['Home', 'On time'].toList();
      await tester.pumpComponent(
        TripCard(
          leaveBy: '5:00 PM',
          footer: TripFooter(text: on),
          progress: TripProgress(percent: percent),
          stops: [TripStop(title: home, time: '6:10 PM')],
        ),
      );

      expect(find.text('On time'), findsOneWidget);
      expect(find.text('Home'), findsOneWidget);
    });
  });
}
