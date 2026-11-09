import 'package:home_backend/validation/layout_composer.dart';
import 'package:home_backend/validation/layout_validator.dart';
import 'package:home_catalog/home_catalog.dart';
import 'package:test/test.dart';

typedef _Json = Map<String, Object?>;

List<_Json> _reply(List<_Json> components) => components;

_Json _c(String id, String type, [Map<String, Object?> props = const {}]) => {
  'id': id,
  'component': type,
  ...props,
};

_Json _root(List<String> children) =>
    _c('root', 'Column', {'children': children});

_Json _row(String id, List<String> children) =>
    _c(id, 'Row', {'children': children});

_Json _device(String id, [int? weight]) =>
    _c(id, 'DeviceCard', {'name': id, 'weight': ?weight});

_Json _chips() => _c('chips', 'ActionChips', {'chips': <Object?>[]});

/// The components of [reply], by id.
Map<String, _Json> _components(List<_Json> reply) => {
  for (final c in reply) c['id']! as String: c,
};

/// The cards of [reply] with the columns each spans.
Map<String, int?> _weights(List<_Json> reply) => {
  for (final c in _components(reply).values)
    if (homeCatalog.components[c['component']]?.fit != null)
      c['id']! as String: c['weight'] as int?,
};

void main() {
  final composer = LayoutComposer(homeCatalog);
  final validator = LayoutValidator(homeCatalog);

  void expectOnTheGrid(List<_Json>? reply) {
    expect(reply, isNotNull);
    expect(validator.validate(reply!), isNull, reason: '$reply');
  }

  group('LayoutComposer lays the cards of a reply out again', () {
    test('as two rows that each span 12', () {
      final reply = composer.compose(
        _reply([
          _root(['top', 'bottom', 'chips']),
          _row('top', ['trip', 'charge']),
          _row('bottom', ['a', 'b', 'c']),
          _c('trip', 'TripCard', {'leaveBy': '5:00 PM', 'weight': 12}),
          _c('charge', 'ChargeCard', {'percent': 80, 'weight': 6}),
          _device('a', 6),
          _device('b', 6),
          _device('c', 6),
          _chips(),
        ]),
      );

      expectOnTheGrid(reply);
      expect(_weights(reply!), {
        'trip': 7,
        'charge': 5,
        'a': 4,
        'b': 4,
        'c': 4,
      });
      final rows = _components(reply);
      expect(rows['root']!['children'], ['grid_row_1', 'grid_row_2', 'chips']);
      expect(rows['grid_row_1']!['children'], ['trip', 'charge']);
      expect(rows['grid_row_2']!['children'], ['a', 'b', 'c']);
    });

    test('keeping the cards in the order the model wrote them', () {
      final reply = composer.compose(
        _reply([
          _root(['body', 'chips']),
          _row('body', ['x', 'inner']),
          _c('inner', 'Column', {
            'children': ['y', 'z'],
          }),
          _device('x', 4),
          _device('y', 4),
          _device('z', 4),
          _chips(),
        ]),
      );

      expectOnTheGrid(reply);
      expect(_components(reply!)['grid_row_1']!['children'], ['x', 'y', 'z']);
    });

    test('beside a full height card, in one Column of rows', () {
      final reply = composer.compose(
        _reply([
          _root(['body', 'chips']),
          _row('body', ['list', 'side']),
          _c('list', 'ShoppingList', {
            'listId': 'shopping',
            'title': 'Shopping',
            'items': <Object?>[],
          }),
          _c('side', 'Column', {
            'children': ['top', 'bottom'],
          }),
          _row('top', ['oven', 'fridge']),
          _row('bottom', ['scene']),
          _device('oven'),
          _device('fridge'),
          _c('scene', 'SceneCard', {'name': 'Dinner', 'sceneId': 'dinner'}),
          _chips(),
        ]),
      );

      expectOnTheGrid(reply);
      final byId = _components(reply!);
      expect(byId['root']!['children'], ['grid_body', 'chips']);
      expect(byId['grid_body']!['children'], ['list', 'grid_rest']);
      expect(byId['grid_rest']!['weight'], 7);
      expect(byId['list']!['weight'], 5);
      // A scene is built for 4 or 5 columns, so it cannot fill a row of the 7
      // that are left by itself: it is the one left out.
      expect(_weights(reply), {'list': 5, 'oven': 4, 'fridge': 3});
    });

    test('with the most urgent card full height when several are', () {
      final reply = composer.compose(
        _reply([
          _root(['body', 'chips']),
          _row('body', ['plan', 'list', 'a']),
          _c('plan', 'PlanTimeline', {
            'entries': [
              {'time': '6:00 PM', 'title': 'Preheat'},
            ],
          }),
          _c('list', 'ShoppingList', {
            'listId': 'shopping',
            'title': 'Shopping',
            'items': <Object?>[],
          }),
          _device('a'),
          _chips(),
        ]),
      );

      expectOnTheGrid(reply);
      final byId = _components(reply!);
      // The list keeps the tall cell. The plan is drawn for a half tall one.
      expect(byId['grid_body']!['children'], ['list', 'grid_rest']);
      expect(byId['plan']!['density'], 'compact');
      expect(_weights(reply)['list'], 5);
    });

    test('with an urgent heads-up half tall and the chips kept', () {
      final reply = composer.compose(
        _reply([
          _root(['body', 'chips']),
          _row('body', ['a', 'alert', 'list']),
          _device('a'),
          _c('alert', 'HeadsUpCard', {
            'title': 'Door open',
            'variant': 'urgent',
          }),
          _c('list', 'ShoppingList', {
            'listId': 'shopping',
            'title': 'Shopping',
            'items': <Object?>[],
          }),
          _device('b'),
          _chips(),
        ]),
      );

      expectOnTheGrid(reply);
      final byId = _components(reply!);
      expect(byId['root']!['children'], ['grid_body', 'chips']);
      // The list keeps the tall cell: the heads-up is half tall and urgent
      // never takes both rows.
      expect(byId['list']!['weight'], 5);
      expect(byId['alert']!['variant'], 'urgent');
      expect(byId['alert']!['weight'], 7);
    });

    test('leaving out the last ranked cards the grid has no room for', () {
      final reply = composer.compose(
        _reply([
          _root(['r1', 'chips']),
          _row('r1', [for (var i = 0; i < 8; i++) 'd$i']),
          for (var i = 0; i < 8; i++) _device('d$i', 4),
          _chips(),
        ]),
      );

      expectOnTheGrid(reply);
      expect(_weights(reply!).keys, [for (var i = 0; i < 6; i++) 'd$i']);
    });

    test('pairing a card that needs a partner with a flexible one', () {
      final reply = composer.compose(
        _reply([
          _root(['r1', 'chips']),
          _row('r1', ['trip', 'a', 'b', 'c', 'd']),
          _c('trip', 'TripCard', {'leaveBy': '5:00 PM'}),
          _device('a'),
          _device('b'),
          _device('c'),
          _device('d'),
          _chips(),
        ]),
      );

      expectOnTheGrid(reply);
      final weights = _weights(reply!);
      expect(weights['trip'], 7);
      expect(weights.length, 5);
    });

    test('keeping every prop of a card but its weight', () {
      final reply = composer.compose(
        _reply([
          _root(['r1', 'chips']),
          _row('r1', ['a', 'b', 'c']),
          _c('a', 'DeviceCard', {
            'name': 'Oven',
            'status': 'Preheating',
            'weight': 9,
            'control': {'type': 'toggle'},
          }),
          _device('b'),
          _device('c'),
          _chips(),
        ]),
      );

      final a = _components(reply!)['a']!;
      expect(a['name'], 'Oven');
      expect(a['status'], 'Preheating');
      expect(a['control'], {'type': 'toggle'});
      expect(a['weight'], 4);
    });

    test('with no row at all when its cards cannot fill one', () {
      final reply = composer.compose(
        _reply([
          _root(['r1', 'chips']),
          _row('r1', ['trip']),
          _c('trip', 'TripCard', {'leaveBy': '5:00 PM'}),
          _chips(),
        ]),
      );

      expect(_components(reply!)['root']!['children'], ['chips']);
    });

    test('with only the tall card when nothing else fits beside it', () {
      final reply = composer.compose(
        _reply([
          _root(['r1', 'chips']),
          _row('r1', ['list']),
          _c('list', 'ShoppingList', {
            'listId': 'shopping',
            'title': 'Shopping',
            'items': <Object?>[],
          }),
          _chips(),
        ]),
      );

      final byId = _components(reply!);
      expect(byId['grid_body']!['children'], ['list']);
      expect(byId.containsKey('grid_rest'), isFalse);
    });

    test('leaving the chips out when the model sent none', () {
      final reply = composer.compose(
        _reply([
          _root(['r1']),
          _row('r1', ['a', 'b', 'c']),
          _device('a'),
          _device('b'),
          _device('c'),
        ]),
      );

      expect(_components(reply!)['root']!['children'], ['grid_row_1']);
    });

    test('ignoring a component with no id', () {
      final reply = composer.compose([
        _root(['r1', 'chips']),
        _row('r1', ['a', 'b', 'c']),
        _device('a'),
        _device('b'),
        _device('c'),
        _chips(),
        {'component': 'DeviceCard'},
      ]);

      expectOnTheGrid(reply);
      expect(reply, hasLength(6));
    });
  });

  group('LayoutComposer finds nothing to lay out', () {
    test('in a reply with no components', () {
      expect(composer.compose(const []), isNull);
    });

    test('in a reply with no root', () {
      expect(composer.compose(_reply([_device('a')])), isNull);
    });

    test('in a screen with no card', () {
      expect(
        composer.compose(
          _reply([
            _root(['chips']),
            _chips(),
          ]),
        ),
        isNull,
      );
    });
  });

  group('LayoutValidator.repair', () {
    test('leaves a reply that is on the grid as it is', () {
      final reply = _reply([
        _root(['r1', 'chips']),
        _row('r1', ['a', 'b', 'c']),
        _device('a', 4),
        _device('b', 4),
        _device('c', 4),
        _chips(),
      ]);

      expect(validator.repair(reply), same(reply));
    });

    test('lays a reply that is off the grid out again', () {
      final reply = _reply([
        _root(['r1', 'chips']),
        _row('r1', ['a', 'b', 'c']),
        _device('a', 6),
        _device('b', 6),
        _device('c', 6),
        _chips(),
      ]);

      expect(validator.validate(reply), isNotNull);
      expect(validator.validate(validator.repair(reply)), isNull);
    });

    test('leaves a reply it cannot mend as it is', () {
      final noCards = _reply([
        _c('root', 'Row', {'children': <Object?>[]}),
      ]);
      expect(validator.repair(noCards), noCards);
    });
  });
}
