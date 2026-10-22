import 'package:app_ui/app_ui.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:genui/genui.dart';
import 'package:home_frontend/src/catalog/builders/charge_card_builder.dart';

import 'pump_builder.dart';

void main() {
  group('chargeCardBuilder', () {
    testWidgets('renders literal props', (tester) async {
      await pumpBuilder(tester, chargeCardBuilder, 'ChargeCard', {
        'status': 'Plugged in',
        'percent': 82,
        'range': '190 mi range',
        'summary': 'Enough for both stops',
        'window': r'Off-peak tonight · saves $2.40',
        'windowIcon': 'savings',
        'tag': {'label': 'Updated', 'kind': 'updated'},
      });

      final card = tester.widget<ChargeCard>(find.byType(ChargeCard));
      expect(card.title, 'Car');
      expect(card.windowIcon, 'savings');
      expect(card.tagKind, StatusTagKind.updated);
      expect(find.text('Car · Plugged in'), findsOneWidget);
      expect(find.text('82%'), findsOneWidget);
      expect(find.text('Updated'), findsOneWidget);
    });

    testWidgets('follows a bound percent', (tester) async {
      final harness = await pumpBuilder(
        tester,
        chargeCardBuilder,
        'ChargeCard',
        {
          'percent': {'path': '/car/percent'},
          'range': {'path': '/car/range'},
        },
        model: {'/car/percent': 82, '/car/range': '190 mi'},
      );
      expect(find.text('82%'), findsOneWidget);

      harness.data.update(DataPath('/car/percent'), 20);
      await tester.pump();

      expect(find.text('20%'), findsOneWidget);
    });

    testWidgets('tolerates a missing level', (tester) async {
      await pumpBuilder(tester, chargeCardBuilder, 'ChargeCard', {});

      expect(find.text('0%'), findsOneWidget);
      expect(
        tester.widget<ChargeCard>(find.byType(ChargeCard)).windowIcon,
        'clock',
      );
    });
  });
}
