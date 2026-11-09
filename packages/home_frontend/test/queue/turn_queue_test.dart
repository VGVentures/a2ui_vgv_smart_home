import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:home_frontend/src/queue/turn_queue.dart';

void main() {
  group(TurnQueue, () {
    test('runs interactions one at a time, in the order asked', () async {
      final queue = TurnQueue();
      final log = <String>[];
      final firstGate = Completer<void>();

      final first = queue.interaction(() async {
        log.add('first start');
        await firstGate.future;
        log.add('first end');
      });
      final second = queue.interaction(() async => log.add('second'));
      await pumpEventQueue();
      expect(log, ['first start']);

      firstGate.complete();
      await Future.wait([first, second]);
      expect(log, ['first start', 'first end', 'second']);
    });

    test('a failed interaction reaches its caller and not the next', () async {
      final queue = TurnQueue();

      final failing = queue.interaction<void>(
        () async => throw StateError('x'),
      );
      final next = queue.interaction(() async => 'ok');

      await expectLater(failing, throwsStateError);
      expect(await next, 'ok');
    });

    test('runs a refresh when nothing else is going on', () async {
      final queue = TurnQueue();
      var ran = 0;

      await queue.refresh((isCurrent) async {
        ran++;
        expect(isCurrent(), isTrue);
      });

      expect(ran, 1);
    });

    test('drops a refresh asked while an interaction runs', () async {
      final queue = TurnQueue();
      final gate = Completer<void>();
      final turn = queue.interaction(() => gate.future);
      var ran = 0;

      await queue.refresh((_) async => ran++);
      gate.complete();
      await turn;

      expect(ran, 0);
    });

    test('drops a refresh asked while an interaction waits', () async {
      final queue = TurnQueue();
      final gate = Completer<void>();
      final turns = [
        queue.interaction(() => gate.future),
        queue.interaction(() async {}),
      ];
      var ran = 0;

      gate.complete();
      await queue.refresh((_) async => ran++);
      await Future.wait(turns);

      expect(ran, 0);
    });

    test('runs a refresh again once the interaction is done', () async {
      final queue = TurnQueue();
      await queue.interaction(() async {});
      var ran = 0;

      await queue.refresh((_) async => ran++);

      expect(ran, 1);
    });

    test('folds triggers that come while it runs into one more', () async {
      final queue = TurnQueue();
      final gate = Completer<void>();
      var ran = 0;

      final first = queue.refresh((_) async {
        ran++;
        if (ran == 1) await gate.future;
      });
      await queue.refresh((_) async => fail('must not run beside the first'));
      await queue.refresh((_) async => fail('must not run beside the first'));
      gate.complete();
      await first;

      expect(ran, 2);
    });

    test('does not rerun when an interaction came meanwhile', () async {
      final queue = TurnQueue();
      final gate = Completer<void>();
      var ran = 0;

      final refresh = queue.refresh((_) async {
        ran++;
        await gate.future;
      });
      await queue.refresh((_) async {});
      final turn = queue.interaction(() async {});
      gate.complete();
      await Future.wait([refresh, turn]);

      expect(ran, 1);
    });

    test('tells a refresh it is stale once an interaction was asked', () async {
      final queue = TurnQueue();
      final gate = Completer<void>();
      bool Function()? isCurrent;

      final refresh = queue.refresh((current) async {
        isCurrent = current;
        await gate.future;
      });
      await pumpEventQueue();
      expect(isCurrent!(), isTrue);

      await queue.interaction(() async {});
      expect(isCurrent!(), isFalse);
      gate.complete();
      await refresh;
    });

    test('lets the next refresh run after one fails', () async {
      final queue = TurnQueue();

      await expectLater(
        queue.refresh((_) async => throw StateError('x')),
        throwsStateError,
      );
      var ran = 0;
      await queue.refresh((_) async => ran++);

      expect(ran, 1);
    });
  });
}
