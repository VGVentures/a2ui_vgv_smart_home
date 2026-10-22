import 'package:app_ui/app_ui.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:material_symbols_icons/symbols.dart';

import '../../helpers/pump_component.dart';

void main() {
  group(AskBar, () {
    testWidgets('shows the hint muted beside the trailing button', (
      tester,
    ) async {
      await tester.pumpComponent(
        const AskBar(text: 'How can I help?', trailing: Text('mic')),
      );

      final text = tester.widget<Text>(find.text('How can I help?'));
      expect(text.style?.color, AppColors.ink3);
      expect(find.byIcon(Symbols.auto_awesome_rounded), findsOneWidget);
      expect(find.text('mic'), findsOneWidget);
    });

    testWidgets('shows the spoken text in full ink', (tester) async {
      await tester.pumpComponent(
        const AskBar(
          text: 'turn on the lights',
          isHint: false,
          trailing: SizedBox(),
        ),
      );

      final text = tester.widget<Text>(find.text('turn on the lights'));
      expect(text.style?.color, AppColors.ink);
    });
  });
}
