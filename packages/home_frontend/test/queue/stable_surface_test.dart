import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:home_frontend/src/queue/stable_surface.dart';

String _fence(Map<String, Object?> message) =>
    '```json\n${jsonEncode(message)}\n```';

Map<String, Object?> _create(String id, {String catalog = 'cat'}) => {
  'version': 'v0.9',
  'createSurface': {
    'surfaceId': id,
    'catalogId': catalog,
    'sendDataModel': true,
  },
};

Map<String, Object?> _update(
  String id,
  List<Map<String, Object?>> components,
) => {
  'version': 'v0.9',
  'updateComponents': {'surfaceId': id, 'components': components},
};

Map<String, Object?> _text(String id, {Object? children, Object? child}) => {
  'id': id,
  'component': 'Column',
  'children': ?children,
  'child': ?child,
};

String _reply(List<Map<String, Object?>> messages) =>
    messages.map(_fence).join('\n');

Map<String, Object?> _body(Map<String, Object?> message, String key) =>
    message[key]! as Map<String, Object?>;

void main() {
  group(StableSurface, () {
    late StableSurface surface;
    setUp(() => surface = StableSurface('dashboard'));

    final first = _reply([
      _create('s_1'),
      _update('s_1', [
        _text('root', children: ['a']),
        _text('a'),
      ]),
    ]);

    test('addresses every message to the stable id', () {
      final messages = surface.admit(first);

      expect(messages, hasLength(2));
      expect(_body(messages[0], 'createSurface')['surfaceId'], 'dashboard');
      expect(_body(messages[1], 'updateComponents')['surfaceId'], 'dashboard');
      expect(messages[0]['version'], 'v0.9');
    });

    test('creates the surface once and updates it after that', () {
      surface.admit(first);

      final messages = surface.admit(
        _reply([
          _create('s_2'),
          _update('s_2', [
            _text('root', children: ['b']),
            _text('b'),
          ]),
        ]),
      );

      expect(messages, hasLength(1));
      expect(messages.single.keys, contains('updateComponents'));
      expect(
        _body(messages.single, 'updateComponents')['surfaceId'],
        'dashboard',
      );
    });

    test('recreates the surface when the catalog changes', () {
      surface.admit(first);

      final messages = surface.admit(
        _reply([
          _create('s_2', catalog: 'other'),
          _update('s_2', [_text('root')]),
        ]),
      );

      expect(messages.map((m) => m.keys.last), [
        'deleteSurface',
        'createSurface',
        'updateComponents',
      ]);
      expect(_body(messages.first, 'deleteSurface')['surfaceId'], 'dashboard');
    });

    test('lets an update refer to components the surface already has', () {
      surface.admit(first);

      final messages = surface.admit(
        _reply([
          _update('x', [
            _text('c', child: 'a'),
          ]),
        ]),
      );

      expect(messages, hasLength(1));
    });

    test('lets a data model update through', () {
      surface.admit(first);

      final messages = surface.admit(
        _reply([
          {
            'version': 'v0.9',
            'updateDataModel': {'surfaceId': 'x', 'path': '/a', 'value': 1},
          },
        ]),
      );

      expect(_body(messages.single, 'updateDataModel')['path'], '/a');
    });

    test('follows a deleteSurface from the model with a new createSurface', () {
      surface.admit(first);
      final deleted = surface.admit(
        _reply([
          {
            'version': 'v0.9',
            'deleteSurface': {'surfaceId': 'x'},
          },
          _create('y'),
          _update('y', [_text('root')]),
        ]),
      );

      expect(deleted.map((m) => m.keys.last), [
        'deleteSurface',
        'createSurface',
        'updateComponents',
      ]);
    });

    test('accepts a children template and ignores other children', () {
      final messages = surface.admit(
        _reply([
          _create('s'),
          _update('s', [
            _text(
              'root',
              children: {'componentId': 'row', 'path': '/items'},
            ),
            _text('row', children: 'not a list'),
          ]),
        ]),
      );

      expect(messages, hasLength(2));
    });

    group('rejects', () {
      void rejects(String reply, Matcher reason) {
        expect(
          () => surface.admit(reply),
          throwsA(
            isA<RejectedReply>().having(
              (e) => e.reasons.join(),
              'reasons',
              reason,
            ),
          ),
        );
      }

      test('a reply without a message', () {
        rejects('Sorry, no JSON here', contains('no A2UI message'));
      });

      test('a block that is not JSON', () {
        rejects('```json\n{oops\n```', contains('not valid JSON'));
      });

      test('JSON that is not a message', () {
        rejects(
          '```json\n[1]\n```\n```json\n{"a": 1}\n```\n'
          '```json\n{"createSurface": 1}\n```',
          contains('no A2UI message'),
        );
      });

      test('an update with no createSurface first', () {
        rejects(
          _reply([
            _update('s', [_text('root')]),
          ]),
          contains('no createSurface'),
        );
      });

      test('a surface with no root', () {
        rejects(
          _reply([
            _create('s'),
            _update('s', [_text('a')]),
          ]),
          contains('"root"'),
        );
      });

      test('a createSurface with no components at all', () {
        rejects(_reply([_create('s')]), contains('"root"'));
      });

      test('a component that points at a missing one', () {
        rejects(
          _reply([
            _create('s'),
            _update('s', [
              _text('root', children: ['a', 'gone']),
              _text('a', child: 'also_gone'),
            ]),
          ]),
          allOf(contains('gone'), contains('also_gone')),
        );
      });

      test('and keeps the last surface it accepted', () {
        surface.admit(first);
        expect(
          () => surface.admit(
            _reply([
              _update('s', [
                _text('root', children: ['gone']),
              ]),
            ]),
          ),
          throwsA(isA<RejectedReply>()),
        );

        // `a` is still known, so an update that refers to it passes.
        final messages = surface.admit(
          _reply([
            _update('s', [_text('d', child: 'a')]),
          ]),
        );
        expect(messages, hasLength(1));
      });
    });

    group('address', () {
      test('points a message that came outside a reply at the surface', () {
        final message = {
          'version': 'v0.9',
          'updateDataModel': {
            'surfaceId': 'whatever',
            'path': '/devices/oven',
            'value': {'status': 'Off'},
          },
        };

        final addressed = surface.address(message);

        expect(addressed['version'], 'v0.9');
        expect(addressed['updateDataModel'], {
          'surfaceId': 'dashboard',
          'path': '/devices/oven',
          'value': {'status': 'Off'},
        });
        // The message it was given is not changed.
        expect((message['updateDataModel']! as Map)['surfaceId'], 'whatever');
      });

      test('leaves what is not a message as it is', () {
        final nothing = {'version': 'v0.9'};
        final notABody = {'updateDataModel': 3};

        expect(surface.address(nothing), same(nothing));
        expect(surface.address(notABody), same(notABody));
      });
    });

    test('RejectedReply says why', () {
      expect(
        const RejectedReply(['a', 'b']).toString(),
        'RejectedReply: a; b',
      );
    });
  });
}
