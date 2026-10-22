import 'package:app_ui/app_ui.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../helpers/pump_component.dart';

void main() {
  group(StatusTagKind, () {
    test('byName maps the catalog names', () {
      expect(StatusTagKind.byName('updated'), StatusTagKind.updated);
      expect(StatusTagKind.byName('new'), StatusTagKind.isNew);
      expect(StatusTagKind.byName('moved'), StatusTagKind.moved);
      expect(StatusTagKind.byName('info'), StatusTagKind.info);
    });

    test('byName reads null and unknown names as info', () {
      expect(StatusTagKind.byName(null), StatusTagKind.info);
      expect(StatusTagKind.byName('other'), StatusTagKind.info);
    });
  });

  group(StatusTag, () {
    testWidgets('shows the label with the icon of its kind', (tester) async {
      await tester.pumpComponent(
        const StatusTag(label: 'Moved', kind: StatusTagKind.moved),
      );

      expect(find.text('Moved'), findsOneWidget);
      expect(find.byIcon(AppIcons.byName('clock')), findsOneWidget);
    });

    testWidgets('prefers an explicit icon', (tester) async {
      await tester.pumpComponent(
        const StatusTag(label: '6 guests', icon: 'guests'),
      );

      expect(find.byIcon(AppIcons.byName('guests')), findsOneWidget);
    });

    testWidgets('shows no icon for an info tag without one', (tester) async {
      await tester.pumpComponent(const StatusTag(label: 'On'));

      expect(find.byType(Icon), findsNothing);
    });
  });
}
