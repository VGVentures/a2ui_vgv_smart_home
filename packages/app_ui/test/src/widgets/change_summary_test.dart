import 'package:app_ui/app_ui.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../helpers/pump_component.dart';

void main() {
  group(ChangeSummary, () {
    testWidgets('renders the eyebrow, title and tiles', (tester) async {
      await tester.pumpComponent(
        const ChangeSummary(
          eyebrow: 'Done · from your request at 5:40 PM',
          title: 'Dinner moved to 8:00 PM',
          changes: [
            ChangeTileData(
              icon: 'oven',
              label: 'Oven preheat',
              value: '7:00 PM',
              previous: 'was 6:00 PM',
            ),
            ChangeTileData(
              icon: 'send',
              label: 'Notified',
              value: 'Marco',
              note: 'Sent 5:41 PM',
            ),
            ChangeTileData(label: 'Plain', value: 'x'),
          ],
        ),
      );

      expect(find.text('Done · from your request at 5:40 PM'), findsOneWidget);
      expect(find.text('Dinner moved to 8:00 PM'), findsOneWidget);
      expect(find.text('Oven preheat'), findsOneWidget);
      expect(find.text('was 6:00 PM'), findsOneWidget);
      expect(find.text('Marco'), findsOneWidget);
      expect(find.text('Sent 5:41 PM'), findsOneWidget);
      expect(find.text('Plain'), findsOneWidget);
    });

    testWidgets('prefers previous over note', (tester) async {
      await tester.pumpComponent(
        const ChangeSummary(
          title: 'Done',
          changes: [
            ChangeTileData(
              label: 'A',
              value: '1',
              previous: 'was 0',
              note: 'ignored',
            ),
          ],
        ),
      );

      expect(find.text('was 0'), findsOneWidget);
      expect(find.text('ignored'), findsNothing);
    });

    testWidgets('renders without an eyebrow', (tester) async {
      await tester.pumpComponent(
        const ChangeSummary(
          title: 'Done',
          changes: [ChangeTileData(label: 'A', value: '1')],
        ),
      );

      expect(find.text('Done'), findsOneWidget);
    });

    testWidgets('spreads its tiles over a bounded height', (tester) async {
      final title = ['Done'].first;
      await tester.pumpComponent(
        SizedBox(
          width: 728,
          height: 260,
          child: ChangeSummary(
            title: title,
            changes: [
              ChangeTileData(label: ['A'].first, value: '7:00 PM'),
            ],
          ),
        ),
      );

      final tile = tester.getRect(find.text('7:00 PM'));
      final card = tester.getRect(find.byType(ChangeSummary));
      expect(card.bottom - tile.bottom, lessThan(80));
    });
  });
}
