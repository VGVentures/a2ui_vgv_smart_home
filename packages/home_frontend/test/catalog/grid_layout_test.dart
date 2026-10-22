import 'package:app_ui/app_ui.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:genui/genui.dart';
import 'package:home_catalog/home_catalog.dart';
import 'package:home_frontend/home_frontend.dart';
import 'package:home_frontend/src/catalog/genui_catalog.dart';

/// The card area of the panel, with the chips footer below it.
const _area = Size(1104, 544 + AppSpacing.gutter + ActionPill.height);

Component _row(String id, List<String> children) =>
    Component(id: id, type: 'Row', properties: {'children': children});

Component _column(String id, List<String> children, {int? weight}) => Component(
  id: id,
  type: 'Column',
  properties: {'children': children, 'weight': ?weight},
);

Component _device(String id, {int? weight}) => Component(
  id: id,
  type: 'DeviceCard',
  properties: {'deviceId': id, 'name': id, 'status': 'On', 'weight': ?weight},
);

Component _countdown(String id, {int? weight}) => Component(
  id: id,
  type: 'CountdownCard',
  properties: {
    'startsAt': '2099-10-10T19:00:00-05:00',
    'eyebrow': 'Guests in',
    'subtitle': id,
    'weight': ?weight,
  },
);

Component _trip(String id, {int? weight}) => Component(
  id: id,
  type: 'TripCard',
  properties: {'label': id, 'leaveBy': '5:00 PM', 'weight': ?weight},
);

Component _charge(String id, {int? weight}) => Component(
  id: id,
  type: 'ChargeCard',
  properties: {'title': id, 'percent': 80, 'weight': ?weight},
);

Component _plan(String id, {int? weight, String? density}) => Component(
  id: id,
  type: 'PlanTimeline',
  properties: {
    'title': id,
    'density': ?density,
    'weight': ?weight,
    'entries': [
      {'time': '6:00 PM', 'title': 'Preheat the oven'},
    ],
  },
);

Component _shopping(String id, {int? weight}) => Component(
  id: id,
  type: 'ShoppingList',
  properties: {
    'listId': id,
    'title': id,
    'weight': ?weight,
    'items': [
      {'id': 'a', 'label': 'Thyme'},
      {'id': 'b', 'label': 'Lemons'},
    ],
  },
);

Component _urgent(String id, {int? weight}) => Component(
  id: id,
  type: 'HeadsUpCard',
  properties: {
    'title': id,
    'message': 'Door open',
    'variant': 'urgent',
    'weight': ?weight,
  },
);

const _chips = Component(
  id: 'chips',
  type: 'ActionChips',
  properties: {
    'chips': [
      {
        'label': 'Preheat now',
        'action': {
          'command': {'deviceId': 'oven', 'command': 'on'},
        },
      },
    ],
  },
);

Future<SurfaceController> _pump(
  WidgetTester tester,
  List<Component> components,
) async {
  final controller = SurfaceController(
    catalogs: [
      buildCatalog(catalog: homeCatalog, widgetBuilders: widgetBuilders),
    ],
  );
  addTearDown(controller.dispose);
  controller
    ..handleMessage(UpdateComponents(surfaceId: 's', components: components))
    ..handleMessage(
      const CreateSurface(surfaceId: 's', catalogId: genUiCatalogId),
    );
  tester.view
    ..devicePixelRatio = 1
    ..physicalSize = const Size(1400, 900);
  addTearDown(tester.view.reset);
  await tester.pumpWidget(
    MaterialApp(
      theme: AppTheme.light,
      home: Scaffold(
        body: Align(
          alignment: Alignment.topLeft,
          child: SizedBox.fromSize(
            size: _area,
            child: Surface(surfaceContext: controller.contextFor('s')),
          ),
        ),
      ),
    ),
  );
  return controller;
}

Rect _rect(WidgetTester tester, String name) => tester.getRect(
  find.ancestor(of: find.text(name), matching: find.byType(AppCard)),
);

Rect _card(WidgetTester tester, Type type, [int index = 0]) =>
    tester.getRect(find.byType(type).at(index));

void main() {
  group('a row of cards', () {
    testWidgets('draws each as wide as the columns it spans', (tester) async {
      await _pump(tester, [
        _column('root', ['top', 'bottom', 'chips']),
        _row('top', ['trip', 'charge']),
        _row('bottom', ['a', 'b', 'c']),
        _trip('trip', weight: 7),
        _charge('charge', weight: 5),
        _device('a', weight: 4),
        _device('b', weight: 4),
        _device('c', weight: 4),
        _chips,
      ]);

      expect(tester.takeException(), isNull);
      // The widths and the gutter between them are those of the Figma screens.
      expect(_card(tester, TripCard).width, closeTo(634, 0.01));
      expect(_card(tester, ChargeCard).width, closeTo(446, 0.01));
      expect(_card(tester, ChargeCard).left, closeTo(634 + 24, 0.01));
      expect(_rect(tester, 'a').width, closeTo(352, 0.01));
      expect(_rect(tester, 'b').left, closeTo(352 + 24, 0.01));
      expect(_rect(tester, 'c').right, closeTo(1104, 0.01));
    });

    testWidgets('gives each row half the area', (tester) async {
      await _pump(tester, [
        _column('root', ['top', 'bottom', 'chips']),
        _row('top', ['a', 'b', 'c']),
        _row('bottom', ['d', 'e', 'f']),
        for (final id in ['a', 'b', 'c', 'd', 'e', 'f']) _device(id, weight: 4),
        _chips,
      ]);

      expect(tester.takeException(), isNull);
      final a = _rect(tester, 'a');
      final d = _rect(tester, 'd');
      expect(a.height, closeTo(260, 0.01));
      expect(d.height, closeTo(260, 0.01));
      expect(a.top, 0);
      expect(d.bottom, closeTo(544, 0.01));
      expect(tester.getRect(find.byType(ActionChips)).top, greaterThan(544));
      expect(tester.getRect(find.byType(ActionChips)).bottom, _area.height);
    });

    testWidgets('uses what each card is built for when it has no weight', (
      tester,
    ) async {
      await _pump(tester, [
        _column('root', ['top', 'chips']),
        _row('top', ['trip', 'charge']),
        _trip('trip'),
        _charge('charge'),
        _chips,
      ]);

      expect(tester.takeException(), isNull);
      expect(_card(tester, TripCard).width, closeTo(634, 0.01));
      expect(_card(tester, ChargeCard).width, closeTo(352, 0.01));
    });

    testWidgets('takes an even share for what has no size', (tester) async {
      await _pump(tester, [
        _column('root', ['top', 'chips']),
        _row('top', ['empty', 'a']),
        _column('empty', []),
        _device('a'),
        _chips,
      ]);

      expect(tester.takeException(), isNull);
      expect(_rect(tester, 'a').width, closeTo(352, 0.01));
    });

    testWidgets('ignores a weight that is not a column count', (tester) async {
      await _pump(tester, [
        _column('root', ['top', 'chips']),
        _row('top', ['a', 'b']),
        _device('a', weight: 0),
        _device('b', weight: 40),
        _chips,
      ]);

      expect(tester.takeException(), isNull);
      expect(_rect(tester, 'a').width, closeTo(352, 0.01));
      expect(_rect(tester, 'b').width, closeTo(352, 0.01));
    });

    testWidgets('leaves the rest empty when it spans fewer than 12', (
      tester,
    ) async {
      await _pump(tester, [
        _column('root', ['top', 'chips']),
        _row('top', ['a']),
        _device('a', weight: 4),
        _chips,
      ]);

      final a = _rect(tester, 'a');
      expect(a.left, 0);
      expect(a.width, closeTo(352, 0.01));
      expect(a.height, closeTo(260, 0.01));
    });

    testWidgets('keeps every card when it spans more than 12', (tester) async {
      await _pump(tester, [
        _column('root', ['top', 'chips']),
        _row('top', ['a', 'b', 'c', 'd']),
        for (final id in ['a', 'b', 'c', 'd']) _device(id, weight: 4),
        _chips,
      ]);

      expect(tester.takeException(), isNull);
      for (final id in ['a', 'b', 'c', 'd']) {
        expect(find.text(id), findsOneWidget);
      }
      expect(_rect(tester, 'd').right, lessThanOrEqualTo(1104));
    });

    testWidgets('a card sent without a row is a row of one', (tester) async {
      await _pump(tester, [
        _column('root', ['a', 'chips']),
        _countdown('a'),
        _chips,
      ]);

      expect(tester.takeException(), isNull);
      expect(_rect(tester, 'a').width, closeTo(446, 0.01));
      expect(_rect(tester, 'a').height, closeTo(260, 0.01));
    });

    testWidgets('a single row is half the area and leaves the rest empty', (
      tester,
    ) async {
      await _pump(tester, [
        _column('root', ['top', 'chips']),
        _row('top', ['a']),
        _device('a', weight: 4),
        _chips,
      ]);

      expect(_rect(tester, 'a').height, closeTo(260, 0.01));
      expect(_rect(tester, 'a').top, 0);
    });

    testWidgets('keeps the room of the chips when the screen sends none', (
      tester,
    ) async {
      await _pump(tester, [
        _column('root', ['top', 'bottom']),
        _row('top', ['a']),
        _row('bottom', ['b']),
        _device('a', weight: 4),
        _device('b', weight: 4),
      ]);

      expect(tester.takeException(), isNull);
      expect(_rect(tester, 'b').bottom, closeTo(544, 0.01));
    });
  });

  group('a full height card', () {
    testWidgets('lays out the Figma screen of a plan between two bands', (
      tester,
    ) async {
      // Ana, Fri 4:30 PM: 5 + 4 + 3 columns.
      await _pump(tester, [
        _column('root', ['body', 'chips']),
        _row('body', ['left', 'plan', 'right']),
        _column('left', ['countdown', 'scene'], weight: 5),
        _plan('plan', weight: 4),
        _column('right', ['oven', 'fridge'], weight: 3),
        _countdown('countdown'),
        _countdown('scene'),
        _device('oven'),
        _device('fridge'),
        _chips,
      ]);

      expect(tester.takeException(), isNull);
      final plan = _card(tester, PlanTimeline);
      expect(plan.width, closeTo(352, 0.01));
      expect(plan.height, closeTo(544, 0.01));
      expect(plan.left, closeTo(446 + 24, 0.01));
      final countdown = _rect(tester, 'countdown');
      final scene = _rect(tester, 'scene');
      expect(countdown.width, closeTo(446, 0.01));
      expect(countdown.height, closeTo(260, 0.01));
      expect(scene.top, closeTo(260 + 24, 0.01));
      final oven = _rect(tester, 'oven');
      expect(oven.width, closeTo(258, 0.01));
      expect(oven.left, closeTo(1104 - 258, 0.01));
      expect(_rect(tester, 'fridge').bottom, closeTo(544, 0.01));
    });

    testWidgets('lays two rows beside it against the columns that are left', (
      tester,
    ) async {
      // The shape a model writes on its own: the list, and one Column of 7
      // columns that holds two rows of its own.
      await _pump(tester, [
        _column('root', ['body', 'chips']),
        _row('body', ['list', 'rest']),
        _shopping('list', weight: 5),
        _column('rest', ['top', 'bottom'], weight: 7),
        _row('top', ['a', 'b']),
        _row('bottom', ['c', 'd']),
        _device('a', weight: 4),
        _device('b', weight: 3),
        _device('c', weight: 3),
        _device('d', weight: 4),
        _chips,
      ]);

      expect(tester.takeException(), isNull);
      final list = _card(tester, ShoppingList);
      expect(list.width, closeTo(446, 0.01));
      expect(list.height, closeTo(544, 0.01));
      final a = _rect(tester, 'a');
      final b = _rect(tester, 'b');
      expect(a.left, closeTo(446 + 24, 0.01));
      expect(a.width, closeTo(352, 0.01));
      expect(b.width, closeTo(258, 0.01));
      expect(b.right, closeTo(1104, 0.01));
      expect(a.height, closeTo(260, 0.01));
      expect(_rect(tester, 'c').top, closeTo(260 + 24, 0.01));
      expect(_rect(tester, 'c').width, closeTo(258, 0.01));
      expect(_rect(tester, 'd').right, closeTo(1104, 0.01));
    });

    testWidgets('sizes a Column of rows with no weight by its first row', (
      tester,
    ) async {
      await _pump(tester, [
        _column('root', ['body', 'chips']),
        _row('body', ['list', 'rest']),
        _shopping('list', weight: 5),
        _column('rest', ['top', 'bottom']),
        _row('top', ['a', 'b']),
        _row('bottom', ['c']),
        _device('a', weight: 4),
        _device('b', weight: 3),
        _device('c', weight: 4),
        _chips,
      ]);

      expect(tester.takeException(), isNull);
      expect(_rect(tester, 'a').width, closeTo(352, 0.01));
      expect(_rect(tester, 'b').right, closeTo(1104, 0.01));
    });

    testWidgets('lays out the shopping list with its two bands', (
      tester,
    ) async {
      // Ana, Fri 7:30 AM: 5 + 4 + 3 columns.
      await _pump(tester, [
        _column('root', ['body', 'chips']),
        _row('body', ['list', 'middle', 'right']),
        _shopping('list', weight: 5),
        _column('middle', ['a', 'b'], weight: 4),
        _column('right', ['c', 'd'], weight: 3),
        for (final id in ['a', 'b', 'c', 'd']) _device(id),
        _chips,
      ]);

      expect(tester.takeException(), isNull);
      final list = _card(tester, ShoppingList);
      expect(list.width, closeTo(446, 0.01));
      expect(list.height, closeTo(544, 0.01));
      expect(_rect(tester, 'a').width, closeTo(352, 0.01));
      expect(_rect(tester, 'c').width, closeTo(258, 0.01));
    });

    testWidgets('lays out an urgent heads-up with one band and no chips', (
      tester,
    ) async {
      // Marco, Sat 2:00 AM: 8 + 4 columns, no chips row.
      await _pump(tester, [
        _column('root', ['body']),
        _row('body', ['alert', 'band']),
        _urgent('alert', weight: 8),
        _column('band', ['a', 'b'], weight: 4),
        _device('a'),
        _device('b'),
      ]);

      expect(tester.takeException(), isNull);
      final alert = _card(tester, HeadsUpCard);
      expect(alert.width, closeTo(728, 0.01));
      expect(alert.height, closeTo(544, 0.01));
      expect(_rect(tester, 'a').width, closeTo(352, 0.01));
      expect(_rect(tester, 'b').bottom, closeTo(544, 0.01));
    });

    testWidgets('a compact plan is half tall, in a row with the others', (
      tester,
    ) async {
      await _pump(tester, [
        _column('root', ['top', 'bottom', 'chips']),
        _row('top', ['plan', 'a', 'b']),
        _row('bottom', ['c', 'd', 'e']),
        _plan('plan', weight: 4, density: 'compact'),
        for (final id in ['a', 'b', 'c', 'd', 'e']) _device(id, weight: 4),
        _chips,
      ]);

      expect(tester.takeException(), isNull);
      expect(_card(tester, PlanTimeline).height, closeTo(260, 0.01));
      expect(_rect(tester, 'c').top, closeTo(260 + 24, 0.01));
    });

    testWidgets('a band of one card does not stretch it', (tester) async {
      await _pump(tester, [
        _column('root', ['body', 'chips']),
        _row('body', ['list', 'band']),
        _shopping('list', weight: 5),
        _column('band', ['a'], weight: 4),
        _device('a'),
        _chips,
      ]);

      expect(tester.takeException(), isNull);
      expect(_rect(tester, 'a').height, closeTo(260, 0.01));
      expect(_rect(tester, 'a').top, 0);
    });

    testWidgets('keeps every card of a band of three', (tester) async {
      await _pump(tester, [
        _column('root', ['body', 'chips']),
        _row('body', ['list', 'band']),
        _shopping('list', weight: 5),
        _column('band', ['a', 'b', 'c'], weight: 4),
        for (final id in ['a', 'b', 'c']) _device(id),
        _chips,
      ]);

      expect(tester.takeException(), isNull);
      for (final id in ['a', 'b', 'c']) {
        expect(find.text(id), findsOneWidget);
      }
    });

    testWidgets('is recognised when sent straight under the root', (
      tester,
    ) async {
      await _pump(tester, [
        _column('root', ['list', 'chips']),
        _shopping('list', weight: 5),
        _chips,
      ]);

      expect(tester.takeException(), isNull);
      expect(_card(tester, ShoppingList).height, closeTo(544, 0.01));
    });
  });

  group('the footer', () {
    testWidgets('is last and only one is kept', (tester) async {
      await _pump(tester, [
        _column('root', ['chips', 'top', 'more']),
        _row('top', ['a']),
        _device('a'),
        _device('more'),
        _chips,
        const Component(
          id: 'extra',
          type: 'ActionChips',
          properties: {'chips': <Object?>[]},
        ),
      ]);

      expect(find.byType(ActionChips), findsOneWidget);
      expect(
        tester.getRect(find.byType(ActionChips)).top,
        greaterThan(_rect(tester, 'a').bottom),
      );
    });
  });

  group('outside the screen', () {
    testWidgets('a column without a bounded height wraps its cards', (
      tester,
    ) async {
      final controller = SurfaceController(
        catalogs: [
          buildCatalog(catalog: homeCatalog, widgetBuilders: widgetBuilders),
        ],
      );
      addTearDown(controller.dispose);
      controller
        ..handleMessage(
          UpdateComponents(
            surfaceId: 's',
            components: [
              _column('root', ['a', 'b']),
              _device('a'),
              _device('b'),
            ],
          ),
        )
        ..handleMessage(
          const CreateSurface(surfaceId: 's', catalogId: genUiCatalogId),
        );
      await tester.pumpWidget(
        MaterialApp(
          theme: AppTheme.light,
          home: Scaffold(
            body: SingleChildScrollView(
              child: Surface(surfaceContext: controller.contextFor('s')),
            ),
          ),
        ),
      );

      expect(tester.takeException(), isNull);
      expect(find.text('a'), findsOneWidget);
      expect(find.text('b'), findsOneWidget);
    });

    testWidgets('a row without a bounded height lays its cards at the top', (
      tester,
    ) async {
      final controller = SurfaceController(
        catalogs: [
          buildCatalog(catalog: homeCatalog, widgetBuilders: widgetBuilders),
        ],
      );
      addTearDown(controller.dispose);
      controller
        ..handleMessage(
          UpdateComponents(
            surfaceId: 's',
            components: [
              _row('root', ['band']),
              _column('band', ['a', 'b'], weight: 4),
              _device('a'),
              _device('b'),
            ],
          ),
        )
        ..handleMessage(
          const CreateSurface(surfaceId: 's', catalogId: genUiCatalogId),
        );
      await tester.pumpWidget(
        MaterialApp(
          theme: AppTheme.light,
          home: Scaffold(
            body: SingleChildScrollView(
              child: Surface(surfaceContext: controller.contextFor('s')),
            ),
          ),
        ),
      );

      expect(tester.takeException(), isNull);
      expect(find.text('a'), findsOneWidget);
      expect(find.text('b'), findsOneWidget);
    });

    testWidgets('children given as a template keep the stock layout', (
      tester,
    ) async {
      await _pump(tester, [
        const Component(
          id: 'root',
          type: 'Column',
          properties: {
            'children': {'componentId': 'a', 'path': '/items'},
          },
        ),
        _device('a'),
      ]);

      expect(tester.takeException(), isNull);
    });

    testWidgets('a row given a template keeps the stock layout', (
      tester,
    ) async {
      await _pump(tester, [
        const Component(
          id: 'root',
          type: 'Row',
          properties: {
            'children': {'componentId': 'a', 'path': '/items'},
          },
        ),
        _device('a'),
      ]);

      expect(tester.takeException(), isNull);
    });
  });
}
