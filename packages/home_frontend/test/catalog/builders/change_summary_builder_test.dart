import 'package:flutter_test/flutter_test.dart';
import 'package:home_frontend/src/catalog/builders/change_summary_builder.dart';

import 'pump_builder.dart';

void main() {
  group('changeSummaryBuilder', () {
    testWidgets('renders the eyebrow, title and tiles', (tester) async {
      await pumpBuilder(tester, changeSummaryBuilder, 'ChangeSummary', {
        'eyebrow': 'Done · from your request at 5:40 PM',
        'title': 'Dinner moved to 8:00 PM',
        'changes': [
          {
            'icon': 'oven',
            'label': 'Oven preheat',
            'value': '7:00 PM',
            'previous': 'was 6:00 PM',
          },
          {
            'icon': 'send',
            'label': 'Notified',
            'value': 'Marco',
            'note': 'Sent 5:41 PM',
          },
          'skip',
        ],
      });

      expect(find.text('Done · from your request at 5:40 PM'), findsOneWidget);
      expect(find.text('Dinner moved to 8:00 PM'), findsOneWidget);
      expect(find.text('was 6:00 PM'), findsOneWidget);
      expect(find.text('Sent 5:41 PM'), findsOneWidget);
    });

    testWidgets('tolerates missing fields', (tester) async {
      await pumpBuilder(tester, changeSummaryBuilder, 'ChangeSummary', {
        'changes': [<String, Object?>{}],
      });

      expect(tester.takeException(), isNull);
    });
  });
}
