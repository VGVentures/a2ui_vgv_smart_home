import 'package:app_ui/app_ui.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../helpers/pump_component.dart';

void main() {
  group(AppCard, () {
    testWidgets('renders a tinted card', (tester) async {
      await tester.pumpComponent(
        const AppCard(tint: AppColors.accentSoft, child: Text('hi')),
      );

      expect(find.text('hi'), findsOneWidget);
    });
  });
}
