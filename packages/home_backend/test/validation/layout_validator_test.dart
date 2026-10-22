import 'dart:convert';

import 'package:home_backend/validation/layout_validator.dart';
import 'package:home_catalog/home_catalog.dart';
import 'package:test/test.dart';

typedef _Json = Map<String, Object?>;

String _reply(List<_Json> components) =>
    '```json\n${jsonEncode({
      'version': 'v0.9',
      'updateComponents': {'surfaceId': 's', 'components': components},
    })}\n```';

_Json _c(String id, String type, [Map<String, Object?> props = const {}]) => {
  'id': id,
  'component': type,
  ...props,
};

_Json _root(List<String> children) =>
    _c('root', 'Column', {'children': children});

_Json _row(String id, List<String> children) =>
    _c(id, 'Row', {'children': children});

_Json _band(String id, int? weight, List<String> children) =>
    _c(id, 'Column', {'children': children, 'weight': ?weight});

_Json _card(String id, String type, int? weight, [_Json props = const {}]) =>
    _c(id, type, {'weight': ?weight, ...props});

_Json _device(String id, int? weight) => _card(id, 'DeviceCard', weight);

_Json _chips([String id = 'chips']) => _c(id, 'ActionChips');

_Json _plan(String id, int? weight, {String? density}) =>
    _card(id, 'PlanTimeline', weight, {'density': ?density});

_Json _urgent(String id, int? weight) =>
    _card(id, 'HeadsUpCard', weight, {'variant': 'urgent'});

void main() {
  final validator = LayoutValidator(homeCatalog);

  List<String>? check(List<_Json> components) =>
      validator.validate(_reply(components));

  group('LayoutValidator accepts the screens of the Figma board', () {
    test('Marco, Fri 4:30 PM: 7 + 5 over 4 + 4 + 4', () {
      expect(
        check([
          _root(['r1', 'r2', 'chips']),
          _row('r1', ['trip', 'charge']),
          _row('r2', ['a', 'b', 'c']),
          _card('trip', 'TripCard', 7),
          _card('charge', 'ChargeCard', 5),
          _device('a', 4),
          _device('b', 4),
          _device('c', 4),
          _chips(),
        ]),
        isNull,
      );
    });

    test('Ana, Fri 4:30 PM: a plan between two bands, 5 + 4 + 3', () {
      expect(
        check([
          _root(['body', 'chips']),
          _row('body', ['left', 'plan', 'right']),
          _band('left', 5, ['countdown', 'scene']),
          _plan('plan', 4),
          _band('right', 3, ['oven', 'fridge']),
          _card('countdown', 'CountdownCard', null),
          _card('scene', 'SceneCard', null),
          _device('oven', null),
          _device('fridge', null),
          _chips(),
        ]),
        isNull,
      );
    });

    test('Ana, Fri 5:41 PM: 8 + 4 over a compact plan and two devices', () {
      expect(
        check([
          _root(['r1', 'r2', 'chips']),
          _row('r1', ['summary', 'countdown']),
          _row('r2', ['plan', 'oven', 'new']),
          _card('summary', 'ChangeSummary', 8),
          _card('countdown', 'CountdownCard', 4),
          _plan('plan', 4, density: 'compact'),
          _device('oven', 4),
          _device('new', 4),
          _chips(),
        ]),
        isNull,
      );
    });

    test('Marco, Sat 2:00 AM: an urgent heads-up and no chips', () {
      expect(
        check([
          _root(['body']),
          _row('body', ['alert', 'band']),
          _urgent('alert', 8),
          _band('band', 4, ['doors', 'night']),
          _device('doors', null),
          _device('night', null),
        ]),
        isNull,
      );
    });

    test('Ana, Fri 7:30 AM: the shopping list and two bands, 5 + 4 + 3', () {
      expect(
        check([
          _root(['body', 'chips']),
          _row('body', ['list', 'middle', 'right']),
          _card('list', 'ShoppingList', 5),
          _band('middle', 4, ['a', 'b']),
          _band('right', 3, ['c', 'd']),
          for (final id in ['a', 'b', 'c', 'd']) _device(id, null),
          _chips(),
        ]),
        isNull,
      );
    });

    test('Marco, Fri 4:48 PM: 5 + 7 over 7 + 5', () {
      expect(
        check([
          _root(['r1', 'r2', 'chips']),
          _row('r1', ['outside', 'alert']),
          _row('r2', ['trip', 'blinds']),
          _device('outside', 5),
          _card('alert', 'HeadsUpCard', 7),
          _card('trip', 'TripCard', 7),
          _device('blinds', 5),
          _chips(),
        ]),
        isNull,
      );
    });

    test('a card with no weight spans what it is built for', () {
      expect(
        check([
          _root(['r1', 'r2', 'chips']),
          _row('r1', ['a', 'b', 'c']),
          _row('r2', ['trip', 'charge']),
          _device('a', null),
          _device('b', 4),
          _device('c', 4),
          _card('trip', 'TripCard', null),
          _card('charge', 'ChargeCard', 5),
          _chips(),
        ]),
        isNull,
      );
    });

    test('a band with no weight spans what its first card is built for', () {
      expect(
        check([
          _root(['body', 'chips']),
          _row('body', ['list', 'middle', 'right']),
          _card('list', 'ShoppingList', null),
          _band('middle', null, ['a', 'b']),
          _band('right', 3, ['c', 'd']),
          for (final id in ['a', 'b', 'c', 'd']) _device(id, null),
          _chips(),
        ]),
        isNull,
      );
    });

    test('a full height card beside one Column of two rows, as a model '
        'writes it', () {
      expect(
        check([
          _root(['body', 'chips']),
          _row('body', ['list', 'rest']),
          _card('list', 'ShoppingList', 5),
          _band('rest', 7, ['top', 'bottom']),
          _row('top', ['oven', 'scene']),
          _row('bottom', ['trip']),
          _device('oven', 4),
          _device('scene', 3),
          _card('trip', 'TripCard', 7),
          _chips(),
        ]),
        isNull,
      );
    });

    test('a Column of rows with no weight adds up like its first row', () {
      expect(
        check([
          _root(['body', 'chips']),
          _row('body', ['list', 'rest']),
          _card('list', 'ShoppingList', 5),
          _band('rest', null, ['top', 'bottom']),
          _row('top', ['a', 'b']),
          _row('bottom', ['c', 'd']),
          _device('a', 4),
          _device('b', 3),
          _device('c', 3),
          _device('d', 4),
          _chips(),
        ]),
        isNull,
      );
    });

    test('one row that fills the grid', () {
      expect(
        check([
          _root(['r1', 'chips']),
          _row('r1', ['a', 'b', 'c']),
          for (final id in ['a', 'b', 'c']) _device(id, 4),
          _chips(),
        ]),
        isNull,
      );
    });

    test('a band of one card, and a weight sent as a whole number', () {
      expect(
        check([
          _root(['body', 'chips']),
          _row('body', ['list', 'band', 'other']),
          _card('list', 'ShoppingList', 5),
          _band('band', 4, ['a']),
          _band('other', 3, ['b']),
          _device('a', null),
          _device('b', null),
          _chips(),
        ]),
        isNull,
      );
      expect(
        check([
          _root(['r1', 'r2', 'chips']),
          _row('r1', ['a', 'b']),
          _row('r2', ['c', 'd']),
          _c('a', 'ChangeSummary', {'weight': 8.0}),
          _device('b', 4),
          _device('c', 8 - 3),
          _card('d', 'TripCard', 7),
          _chips(),
        ]),
        isNull,
      );
    });
  });

  group('LayoutValidator leaves alone', () {
    test('a reply with no components', () {
      expect(validator.validate(''), isNull);
      expect(validator.validate('plain prose'), isNull);
    });

    test('a reply with no root', () {
      expect(check([_device('a', 4)]), isNull);
    });

    test('JSON that is not a message, and a block that is not JSON', () {
      expect(
        validator.validate(
          '```json\n{oops\n```\n```json\n[1]\n```\n'
          '```json\n{"updateComponents": 1}\n```\n'
          '```json\n{"updateComponents": {"components": [1, {"x": 2}]}}\n```',
        ),
        isNull,
      );
    });
  });

  group('LayoutValidator rejects', () {
    void rejects(List<_Json> components, Matcher message) {
      expect(check(components), isNotNull);
      expect(check(components)!.join('\n'), message);
    }

    final twoRows = [
      _row('r1', ['a', 'b', 'c']),
      _row('r2', ['d', 'e', 'f']),
      for (final id in ['a', 'b', 'c', 'd', 'e', 'f']) _device(id, 4),
    ];

    test('a root that is not a Column', () {
      rejects([_c('root', 'Row', {})], contains('must be a `Column`'));
    });

    test('a root with no list of children', () {
      rejects([_c('root', 'Column', {})], contains('list its children'));
    });

    test('an id that is not defined', () {
      rejects(
        [
          _root(['r1', 'gone', 'chips']),
          _row('r1', ['a', 'ghost']),
          _device('a', 12),
          _chips(),
        ],
        allOf(contains('"gone"'), contains('"ghost"')),
      );
    });

    test('a card directly under the root', () {
      rejects(
        [
          _root(['a', 'chips']),
          _device('a', 4),
          _chips(),
        ],
        contains('Put every card in a `Row`'),
      );
    });

    test('a screen without chips', () {
      rejects(
        [
          _root(['r1', 'r2']),
          ...twoRows,
        ],
        contains('exactly one `ActionChips`'),
      );
    });

    test('a screen with two chips', () {
      rejects(
        [
          _root(['r1', 'r2', 'chips', 'more']),
          ...twoRows,
          _chips(),
          _chips('more'),
        ],
        contains('lists 2'),
      );
    });

    test('chips that are not last', () {
      rejects(
        [
          _root(['chips', 'r1', 'r2']),
          ...twoRows,
          _chips(),
        ],
        contains('must be the last child'),
      );
    });

    test('chips on a screen with an urgent heads-up', () {
      rejects(
        [
          _root(['body', 'chips']),
          _row('body', ['alert', 'band']),
          _urgent('alert', 8),
          _band('band', 4, ['a', 'b']),
          _device('a', null),
          _device('b', null),
          _chips(),
        ],
        contains('no `ActionChips`'),
      );
    });

    test('a screen with no row of cards', () {
      rejects(
        [
          _root(['chips']),
          _chips(),
        ],
        contains('no `Row` of cards'),
      );
      rejects(
        [
          _root(['r1', 'chips']),
          _c('r1', 'Row', {}),
          _chips(),
        ],
        allOf(contains('must list its cards'), contains('no `Row` of cards')),
      );
    });

    test('three rows', () {
      rejects(
        [
          _root(['r1', 'r2', 'r3', 'chips']),
          _row('r1', ['a', 'b', 'c']),
          _row('r2', ['d', 'e', 'f']),
          _row('r3', ['g']),
          for (final id in ['a', 'b', 'c', 'd', 'e', 'f']) _device(id, 4),
          _device('g', 12),
          _chips(),
        ],
        contains('at most two `Row`s'),
      );
    });

    test('a row that does not add up to 12', () {
      rejects(
        [
          _root(['r1', 'r2', 'chips']),
          _row('r1', ['a', 'b']),
          _row('r2', ['c', 'd', 'e']),
          _device('a', 4),
          _device('b', 4),
          for (final id in ['c', 'd', 'e']) _device(id, 4),
          _chips(),
        ],
        allOf(contains('"r1" add up to 8'), contains('exactly 12')),
      );
    });

    test('a card with a weight it is not built for', () {
      rejects(
        [
          _root(['r1', 'r2', 'chips']),
          _row('r1', ['trip', 'charge']),
          _row('r2', ['a', 'b', 'c']),
          _card('trip', 'TripCard', 12),
          _card('charge', 'ChargeCard', 5),
          for (final id in ['a', 'b', 'c']) _device(id, 4),
          _chips(),
        ],
        allOf(
          contains('TripCard "trip" has weight 12'),
          contains('built for 7 of 12 columns, half tall'),
        ),
      );
    });

    test('a screen with no weights at all, as the log of a failed reply', () {
      // Every card then spans what it is best built for: 5 and 4 here, short
      // of the 12 the row must add up to. The weights are what it must add.
      rejects(
        [
          _root(['body', 'chips']),
          _row('body', ['shopping_col', 'sidebar_col']),
          _c('shopping_col', 'ShoppingList'),
          _band('sidebar_col', null, ['oven', 'fridge']),
          _c('oven', 'DeviceCard'),
          _c('fridge', 'DeviceCard'),
          _chips(),
        ],
        contains('add up to 9'),
      );
    });

    test('a row of four cards', () {
      rejects(
        [
          _root(['r1', 'r2', 'chips']),
          _row('r1', ['a', 'b', 'c', 'd']),
          _row('r2', ['e', 'f', 'g']),
          for (final id in ['a', 'b', 'c', 'd']) _device(id, 3),
          for (final id in ['e', 'f', 'g']) _device(id, 4),
          _chips(),
        ],
        contains('holds 4 cards. It holds at most 3'),
      );
    });

    test('something that is not a card in a row', () {
      rejects(
        [
          _root(['r1', 'r2', 'chips']),
          _row('r1', ['a', 'nested']),
          _row('nested', ['x']),
          _row('r2', ['c', 'd', 'e']),
          _device('a', 4),
          _device('x', 8),
          for (final id in ['c', 'd', 'e']) _device(id, 4),
          _chips(),
        ],
        contains('Row "nested" cannot be placed'),
      );
    });

    test('a band in a screen with no full height card', () {
      rejects(
        [
          _root(['body', 'chips']),
          _row('body', ['left', 'right']),
          _band('left', 4, ['a', 'b']),
          _band('right', 8, ['c', 'd']),
          _device('a', null),
          _device('b', null),
          _card('c', 'ChangeSummary', null),
          _card('d', 'TripCard', null),
          _chips(),
        ],
        contains('holds `Column`s but no full height card'),
      );
    });

    test('a card that is not in a band beside a full height card', () {
      rejects(
        [
          _root(['body', 'chips']),
          _row('body', ['plan', 'a', 'b']),
          _plan('plan', 4),
          _device('a', 4),
          _device('b', 4),
          _chips(),
        ],
        contains('DeviceCard "a" is directly in the `Row`'),
      );
    });

    test('two full height cards', () {
      rejects(
        [
          _root(['body', 'chips']),
          _row('body', ['plan', 'list', 'band']),
          _plan('plan', 4),
          _card('list', 'ShoppingList', 5),
          _band('band', 3, ['a']),
          _device('a', null),
          _chips(),
        ],
        contains('holds 2 full height cards'),
      );
    });

    test('a full height card in a half tall row', () {
      rejects(
        [
          _root(['r1', 'r2', 'chips']),
          _row('r1', ['plan', 'a', 'b']),
          _row('r2', ['c', 'd', 'e']),
          _plan('plan', 4),
          for (final id in ['a', 'b', 'c', 'd', 'e']) _device(id, 4),
          _chips(),
        ],
        anyOf(
          contains('A screen with a full height card has a single `Row`'),
          contains('full height card'),
        ),
      );
    });

    test('a full height card in a band', () {
      rejects(
        [
          _root(['body', 'chips']),
          _row('body', ['plan', 'band']),
          _plan('plan', 4),
          _band('band', 8, ['list']),
          _card('list', 'ShoppingList', null),
          _chips(),
        ],
        contains('ShoppingList "list" is a full height card'),
      );
    });

    test('rows beside a full height card that miss the columns left', () {
      rejects(
        [
          _root(['body', 'chips']),
          _row('body', ['list', 'rest']),
          _card('list', 'ShoppingList', 5),
          _band('rest', 7, ['top', 'bottom']),
          _row('top', ['a', 'b']),
          _row('bottom', ['c', 'd']),
          _device('a', 4),
          _device('b', 4),
          _device('c', 3),
          _device('d', 4),
          _chips(),
        ],
        allOf(
          contains('"top" add up to 8'),
          contains('exactly 7'),
          contains('columns of the `Column`'),
        ),
      );
    });

    test('rows beside a full height card, three of them', () {
      rejects(
        [
          _root(['body', 'chips']),
          _row('body', ['list', 'rest']),
          _card('list', 'ShoppingList', 5),
          _band('rest', 7, ['r1', 'r2', 'r3']),
          for (final id in ['r1', 'r2', 'r3']) _row(id, ['${id}a', '${id}b']),
          for (final id in ['r1a', 'r2a', 'r3a']) _device(id, 4),
          for (final id in ['r1b', 'r2b', 'r3b']) _device(id, 3),
          _chips(),
        ],
        contains('holds 3 rows. It holds at most two'),
      );
    });

    test('a Column that mixes rows and cards, or has an empty row', () {
      rejects(
        [
          _root(['body', 'chips']),
          _row('body', ['list', 'rest']),
          _card('list', 'ShoppingList', 5),
          _band('rest', 7, ['top', 'card']),
          _row('top', ['a', 'b']),
          _device('a', 4),
          _device('b', 3),
          _device('card', 4),
          _chips(),
        ],
        contains('mixes rows and cards'),
      );
      rejects(
        [
          _root(['body', 'chips']),
          _row('body', ['list', 'rest']),
          _card('list', 'ShoppingList', 5),
          _band('rest', 7, ['top']),
          _c('top', 'Row', {}),
          _chips(),
        ],
        contains('mixes rows and cards'),
      );
    });

    test('a band of three, and a band with no weight', () {
      rejects(
        [
          _root(['body', 'chips']),
          _row('body', ['list', 'band']),
          _card('list', 'ShoppingList', 5),
          _band('band', 7, ['a', 'b', 'c']),
          for (final id in ['a', 'b', 'c']) _device(id, null),
          _chips(),
        ],
        contains('holds 3 cards. It holds one or two'),
      );
    });

    test('an empty band', () {
      rejects(
        [
          _root(['body', 'chips']),
          _row('body', ['list', 'band']),
          _card('list', 'ShoppingList', 5),
          _band('band', 7, []),
          _chips(),
        ],
        contains('holds 0 cards'),
      );
    });

    test('a full height card with a weight it is not built for', () {
      rejects(
        [
          _root(['body', 'chips']),
          _row('body', ['plan', 'band']),
          _plan('plan', 5),
          _band('band', 7, ['a']),
          _device('a', null),
          _chips(),
        ],
        contains('PlanTimeline "plan" has weight 5'),
      );
    });

    test('two heads-ups, and too many cards', () {
      rejects(
        [
          _root(['r1', 'r2', 'chips']),
          _row('r1', ['a', 'b']),
          _row('r2', ['c', 'd', 'e']),
          _card('a', 'HeadsUpCard', 7),
          _card('b', 'HeadsUpCard', 5),
          for (final id in ['c', 'd', 'e']) _device(id, 4),
          _chips(),
        ],
        contains('at most one `HeadsUpCard`'),
      );
      rejects(
        [
          _root(['r1', 'r2', 'chips']),
          _row('r1', ['a', 'b', 'c']),
          _row('r2', ['d', 'e', 'f']),
          for (final id in ['a', 'b', 'c', 'd', 'e', 'f']) _device(id, 4),
          _device('g', 4),
          _row('r3', ['g']),
          _root(['r1', 'r2', 'r3', 'chips']),
          _chips(),
        ],
        contains('has 7 cards'),
      );
    });

    test('messages of several blocks, merged by id', () {
      final first = _reply([
        _root(['r1', 'r2', 'chips']),
        _row('r1', ['a', 'b']),
      ]);
      final second = _reply([
        _row('r2', ['c', 'd', 'e']),
        _device('a', 4),
        _device('b', 4),
        for (final id in ['c', 'd', 'e']) _device(id, 4),
        _chips(),
      ]);

      expect(validator.validate('$first\n$second'), isNotNull);
      expect(
        validator.validate('$first\n$second')!.join(),
        contains('add up to 8'),
      );
    });
  });
}
