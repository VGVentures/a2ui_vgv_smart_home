import 'package:app_ui/app_ui.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:genui/genui.dart';
import 'package:home_frontend/src/catalog/builders/shopping_list_builder.dart';

import 'pump_builder.dart';

Map<String, Object?> _literal() => {
  'listId': 'shopping',
  'title': 'Shopping for tonight',
  'subtitle': 'Missing from the fridge',
  'items': [
    {'id': 'ribs', 'label': 'Short ribs', 'detail': '4 lb'},
    {'id': 'shallots', 'label': 'Shallots', 'checked': true},
  ],
  'footerAction': {
    'label': 'Share list with Marco',
    'icon': 'share',
  },
};

Map<String, Object?> _bound() => {
  'listId': 'shopping',
  'title': 'Shopping',
  'items': [
    {
      'id': 'ribs',
      'label': 'Short ribs',
      'checked': {'path': '/todo/ribs'},
    },
    {
      'id': 'cream',
      'label': 'Heavy cream',
      'checked': {'path': '/todo/cream'},
    },
  ],
};

void main() {
  group('shoppingListBuilder', () {
    testWidgets('renders literal rows and the open count', (tester) async {
      await pumpBuilder(
        tester,
        shoppingListBuilder,
        'ShoppingList',
        _literal(),
      );

      expect(find.text('Shopping for tonight'), findsOneWidget);
      expect(find.text('4 lb'), findsOneWidget);
      expect(find.text('1'), findsOneWidget);
      expect(
        tester.widget<ShoppingList>(find.byType(ShoppingList)).icon,
        'cart',
      );
    });

    testWidgets('ticking a literal row flips it and dispatches', (
      tester,
    ) async {
      final harness = await pumpBuilder(
        tester,
        shoppingListBuilder,
        'ShoppingList',
        _literal(),
      );

      await tester.tap(find.text('Short ribs'));
      await tester.pump();

      expect(find.text('0'), findsOneWidget);
      final event = harness.events.single;
      expect(event.name, 'toggle_todo');
      expect(event.context, {
        'progressLabel': 'Check off Short ribs',
        'listId': 'shopping',
        'itemId': 'ribs',
        'checked': true,
      });

      await tester.tap(find.text('Short ribs'));
      await tester.pump();

      expect(find.text('1'), findsOneWidget);
      expect(harness.events.last.context['checked'], false);
      expect(
        harness.events.last.context['progressLabel'],
        'Uncheck Short ribs',
      );
    });

    testWidgets('ticking a bound row writes the path then dispatches', (
      tester,
    ) async {
      final harness = await pumpBuilder(
        tester,
        shoppingListBuilder,
        'ShoppingList',
        _bound(),
        model: {'/todo/ribs': false, '/todo/cream': true},
      );
      expect(find.text('1'), findsOneWidget);

      await tester.tap(find.text('Short ribs'));
      await tester.pump();

      expect(harness.data.getValue<bool>(DataPath('/todo/ribs')), isTrue);
      expect(find.text('0'), findsOneWidget);
      expect(harness.events.single.context, {
        'progressLabel': 'Check off Short ribs',
        'listId': 'shopping',
        'itemId': 'ribs',
        'checked': true,
      });
    });

    testWidgets('a failed turn unticks a literal row', (tester) async {
      final revision = ValueNotifier(0);
      await pumpBuilder(
        tester,
        shoppingListBuilder,
        'ShoppingList',
        _literal(),
        revision: revision,
      );

      await tester.tap(find.text('Short ribs'));
      await tester.pump();
      expect(find.text('0'), findsOneWidget);

      revision.value = 1;
      await tester.pump();
      await tester.pump();

      expect(find.text('1'), findsOneWidget);
    });

    testWidgets('a failed turn restores a bound row and its path', (
      tester,
    ) async {
      final revision = ValueNotifier(0);
      final harness = await pumpBuilder(
        tester,
        shoppingListBuilder,
        'ShoppingList',
        _bound(),
        model: {'/todo/ribs': false, '/todo/cream': true},
        revision: revision,
      );

      await tester.tap(find.text('Short ribs'));
      await tester.pump();
      expect(harness.data.getValue<bool>(DataPath('/todo/ribs')), isTrue);

      revision.value = 1;
      await tester.pump();
      await tester.pump();

      expect(harness.data.getValue<bool>(DataPath('/todo/ribs')), isFalse);
      expect(find.text('1'), findsOneWidget);
    });

    testWidgets('a server write moves a bound row', (tester) async {
      final harness = await pumpBuilder(
        tester,
        shoppingListBuilder,
        'ShoppingList',
        _bound(),
        model: {'/todo/ribs': false, '/todo/cream': false},
      );
      expect(find.text('2'), findsOneWidget);

      harness.data.update(DataPath('/todo/cream'), true);
      await tester.pump();

      expect(find.text('1'), findsOneWidget);
    });

    testWidgets('the footer pill dispatches its action', (tester) async {
      final harness = await pumpBuilder(
        tester,
        shoppingListBuilder,
        'ShoppingList',
        _literal(),
      );

      await tester.tap(find.text('Share list with Marco'));

      expect(harness.events.single.name, 'share_list');
      expect(harness.events.single.context, {
        'progressLabel': 'Share list with Marco',
        'listId': 'shopping',
      });
    });

    testWidgets('without a listId nothing is dispatched', (tester) async {
      final harness = await pumpBuilder(
        tester,
        shoppingListBuilder,
        'ShoppingList',
        {
          'title': 'T',
          'items': [
            {'id': 'a', 'label': 'A'},
          ],
          'footerAction': {'label': 'Share'},
        },
      );

      await tester.tap(find.text('A'));
      await tester.tap(find.text('Share'));

      expect(harness.events, isEmpty);
    });

    testWidgets('tolerates missing props', (tester) async {
      await pumpBuilder(tester, shoppingListBuilder, 'ShoppingList', {
        'items': [<String, Object?>{}],
      });

      expect(tester.widget<ShoppingList>(find.byType(ShoppingList)).title, '');
      expect(find.byType(PillButton), findsNothing);
    });
  });
}
