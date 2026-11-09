import 'package:app_ui/app_ui.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../helpers/pump_component.dart';

const _items = [
  ShoppingItem(id: 'ribs', label: 'Short ribs', detail: '4 lb · bone-in'),
  ShoppingItem(id: 'cream', label: 'Heavy cream'),
  ShoppingItem(id: 'shallots', label: 'Shallots', detail: '6', checked: true),
];

void main() {
  group(ShoppingList, () {
    testWidgets('shows the header, rows and the open count', (tester) async {
      await tester.pumpComponent(
        const ShoppingList(
          title: 'Shopping for tonight',
          subtitle: 'Missing from the fridge',
          items: _items,
        ),
      );

      expect(find.text('Shopping for tonight'), findsOneWidget);
      expect(find.text('Missing from the fridge'), findsOneWidget);
      expect(find.text('Short ribs'), findsOneWidget);
      expect(find.text('4 lb · bone-in'), findsOneWidget);
      expect(find.text('2'), findsOneWidget);
      expect(find.byIcon(Icons.check_rounded), findsOneWidget);
      expect(find.byIcon(AppIcons.byName('cart')), findsOneWidget);
    });

    testWidgets('greys a checked label', (tester) async {
      await tester.pumpComponent(
        const ShoppingList(title: 'List', items: _items),
      );

      final checked = tester.widget<Text>(find.text('Shallots'));
      final open = tester.widget<Text>(find.text('Short ribs'));
      expect(checked.style?.color, AppColors.ink3);
      expect(open.style?.color, AppColors.ink);
    });

    testWidgets('reports the value a tap asks for', (tester) async {
      final calls = <String>[];
      await tester.pumpComponent(
        ShoppingList(
          title: 'List',
          items: _items,
          onToggle: (item, {required checked}) =>
              calls.add('${item.id}:$checked'),
        ),
      );

      await tester.tap(find.text('Short ribs'));
      await tester.tap(find.text('Shallots'));

      expect(calls, ['ribs:true', 'shallots:false']);
    });

    testWidgets('shows the footer pill and runs it', (tester) async {
      var shared = false;
      await tester.pumpComponent(
        ShoppingList(
          title: 'List',
          items: _items,
          footerLabel: 'Share list with Marco',
          footerIcon: 'share',
          onFooter: () => shared = true,
        ),
      );

      await tester.tap(find.text('Share list with Marco'));
      expect(shared, isTrue);
    });

    testWidgets('has no footer without a label and caps rows at six', (
      tester,
    ) async {
      await tester.pumpComponent(
        ShoppingList(
          title: 'List',
          items: [
            for (var i = 0; i < 7; i++)
              ShoppingItem(id: '$i', label: 'Item $i'),
          ],
        ),
      );

      expect(find.byType(PillButton), findsNothing);
      expect(find.text('Item 5'), findsOneWidget);
      expect(find.text('Item 6'), findsNothing);
    });

    testWidgets('fills a tall cell: rows stretch and the footer stays', (
      tester,
    ) async {
      await tester.pumpComponent(
        SizedBox(
          height: 544,
          child: ShoppingList(
            title: 'List',
            items: [
              for (var i = 0; i < 5; i++)
                ShoppingItem(id: '$i', label: 'Item $i'),
            ],
            footerLabel: 'Share',
            onFooter: () {},
          ),
        ),
      );

      expect(find.byType(PillButton), findsOneWidget);
      expect(find.text('Item 4'), findsOneWidget);
      final card = tester.getRect(find.byType(AppCard));
      final footer = tester.getRect(find.byType(PillButton));
      // The footer pill sits at the bottom padding, so nothing is left empty.
      expect(card.bottom - footer.bottom, closeTo(33, 1));
    });

    testWidgets('never stretches a row past its maximum', (tester) async {
      await tester.pumpComponent(
        const SizedBox(
          height: 500,
          child: ShoppingList(
            title: 'List',
            items: [ShoppingItem(id: 'a', label: 'Only item')],
          ),
        ),
      );

      final row = tester.getRect(find.text('Only item'));
      final card = tester.getRect(find.byType(AppCard));
      expect(card.bottom - row.bottom, greaterThan(200));
    });

    testWidgets('drops the footer when fewer than three rows fit', (
      tester,
    ) async {
      await tester.pumpComponent(
        SizedBox(
          height: 300,
          child: ShoppingList(
            title: 'List',
            items: _items,
            footerLabel: 'Share',
            onFooter: () {},
          ),
        ),
      );

      expect(find.byType(PillButton), findsNothing);
      expect(tester.takeException(), isNull);
    });
  });
}
