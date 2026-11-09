// Each test drives the cubit and fake time by hand, in a fixed order.
// ignore_for_file: cascade_invocations, discarded_futures

import 'dart:async';

import 'package:a2ui_vgv_smart_home/timeline/cubit/timeline_cubit.dart';
import 'package:fake_async/fake_async.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../helpers/fake_live_repository.dart';
import '../../helpers/fake_scenario_repository.dart';

void main() {
  group(TimelineCubit, () {
    late FakeScenarioRepository repository;
    late FakeLiveRepository live;

    setUp(() {
      repository = FakeScenarioRepository();
      live = FakeLiveRepository();
    });

    TimelineCubit build() => TimelineCubit(repository: repository, live: live);

    /// Runs [body] with a cubit that was reset and is ready, in fake time.
    void run(void Function(FakeAsync async, TimelineCubit cubit) body) {
      fakeAsync((async) {
        final cubit = build();
        unawaited(cubit.reset());
        async.flushMicrotasks();
        body(async, cubit);
        cubit.close();
      });
    }

    test('starts loading, on Saturday at 7:30 AM', () {
      final cubit = build();
      addTearDown(cubit.close);

      expect(cubit.state.status, TimelineStatus.loading);
      expect(cubit.state.now, saturdayStart);
      expect(cubit.state.moving, isFalse);
    });

    test('reset restores the backend and is ready at the start', () async {
      final cubit = build();
      addTearDown(cubit.close);

      await cubit.reset();

      expect(repository.resets, 1);
      expect(cubit.state.status, TimelineStatus.ready);
      expect(cubit.state.now, saturdayStart);
      expect(cubit.state.end, saturdayEnd);
      expect(cubit.state.resets, 1);
      expect(cubit.state.revision, 1);
    });

    test('a reset that fails leaves the timeline failed', () async {
      repository.failures = 1;
      final cubit = build();
      addTearDown(cubit.close);

      await cubit.reset();

      expect(cubit.state.status, TimelineStatus.failure);
      await cubit.reset();
      expect(cubit.state.status, TimelineStatus.ready);
    });

    test('a step is ignored until the demo is ready', () async {
      final cubit = build();
      addTearDown(cubit.close);

      await cubit.step(const Duration(minutes: 15));

      expect(repository.moves, isEmpty);
      expect(cubit.state.now, saturdayStart);
    });

    test('jumps to the target at once and settles on it', () {
      run((async, cubit) {
        final target = saturdayStart.add(const Duration(minutes: 15));
        final seen = <DateTime>[];
        final subscription = cubit.stream.listen((s) => seen.add(s.now));
        live.answers = false;

        unawaited(cubit.step(const Duration(minutes: 15)));
        async.flushMicrotasks();

        // The new time is on screen before the backend has confirmed it.
        expect(cubit.state.moving, isTrue);
        expect(cubit.state.now, target);
        expect(cubit.state.revision, 1);

        async.elapse(const Duration(seconds: 5));
        async.flushMicrotasks();

        expect(cubit.state.moving, isFalse);
        expect(cubit.state.now, target);
        expect(cubit.state.revision, 2);
        // It never passed through the minutes in between.
        expect(seen.toSet(), {target});
        subscription.cancel();
      });
    });

    test('tells the backend the target, once', () {
      run((async, cubit) {
        unawaited(cubit.step(const Duration(minutes: 15)));
        async.elapse(const Duration(seconds: 3));
        async.flushMicrotasks();

        expect(live.moves, [saturdayStart.add(const Duration(minutes: 15))]);
        expect(repository.moves, isEmpty);
        expect(cubit.state.revision, 2);
      });
    });

    test('goes back, but not before the start', () {
      run((async, cubit) {
        unawaited(cubit.step(const Duration(minutes: 30)));
        async.elapse(const Duration(seconds: 3));
        async.flushMicrotasks();
        unawaited(cubit.step(const Duration(minutes: -15)));
        async.elapse(const Duration(seconds: 3));
        async.flushMicrotasks();
        expect(cubit.state.now, saturdayStart.add(const Duration(minutes: 15)));

        unawaited(cubit.step(const Duration(minutes: -30)));
        async.elapse(const Duration(seconds: 3));
        async.flushMicrotasks();
        expect(cubit.state.now, saturdayStart);

        final moves = live.moves.length;
        unawaited(cubit.step(const Duration(minutes: -15)));
        async.flushMicrotasks();
        expect(live.moves, hasLength(moves));
      });
    });

    test('does not go past the end of the scenario', () {
      run((async, cubit) {
        unawaited(cubit.step(const Duration(hours: 17)));
        async.elapse(const Duration(seconds: 40));
        async.flushMicrotasks();
        expect(cubit.state.now, saturdayEnd);

        unawaited(cubit.step(const Duration(minutes: 15)));
        async.flushMicrotasks();
        expect(cubit.state.moving, isFalse);
      });
    });

    test('ignores another step while the time is moving', () {
      run((async, cubit) {
        live.answers = false;
        unawaited(cubit.step(const Duration(minutes: 15)));
        async.flushMicrotasks();
        unawaited(cubit.step(const Duration(minutes: 30)));
        async.elapse(const Duration(seconds: 5));
        async.flushMicrotasks();

        expect(cubit.state.now, saturdayStart.add(const Duration(minutes: 15)));
      });
    });

    test('fails when neither the socket nor HTTP reach the backend', () {
      run((async, cubit) {
        live.connected = false;
        repository.failures = 100;
        unawaited(cubit.step(const Duration(minutes: 15)));
        async.elapse(const Duration(seconds: 3));
        async.flushMicrotasks();

        expect(cubit.state.status, TimelineStatus.failure);
        expect(cubit.state.moving, isFalse);
        expect(cubit.state.revision, 1);
      });
    });

    test('asks over HTTP when there is no connection', () {
      run((async, cubit) {
        live.connected = false;
        unawaited(cubit.step(const Duration(minutes: 15)));
        async.elapse(const Duration(seconds: 3));
        async.flushMicrotasks();

        final target = saturdayStart.add(const Duration(minutes: 15));
        expect(live.moves, isEmpty);
        expect(repository.moves.last, target);
        expect(cubit.state.now, target);
        expect(cubit.state.status, TimelineStatus.ready);
      });
    });

    test('asks over HTTP when the socket never confirms the clock', () {
      run((async, cubit) {
        live.answers = false;
        unawaited(cubit.step(const Duration(minutes: 15)));
        async.elapse(const Duration(seconds: 1));
        async.flushMicrotasks();
        expect(cubit.state.moving, isTrue);

        async.elapse(const Duration(seconds: 5));
        async.flushMicrotasks();

        final target = saturdayStart.add(const Duration(minutes: 15));
        expect(repository.moves, [target]);
        expect(cubit.state.moving, isFalse);
        expect(cubit.state.now, target);
        expect(async.pendingTimers, isEmpty);
      });
    });

    test('settles on the time the backend confirms', () {
      run((async, cubit) {
        unawaited(cubit.step(const Duration(minutes: 15)));
        async.elapse(const Duration(seconds: 3));
        async.flushMicrotasks();

        expect(cubit.state.now, live.moves.last);
        expect(async.pendingTimers, isEmpty);
      });
    });

    test('seeks straight to a time, forward or back', () {
      run((async, cubit) {
        final target = saturdayStart.add(const Duration(minutes: 90));
        unawaited(cubit.seekTo(target));
        async.elapse(const Duration(seconds: 5));
        async.flushMicrotasks();
        expect(cubit.state.now, target);
        expect(live.moves.last, target);

        unawaited(cubit.seekTo(saturdayStart.add(const Duration(minutes: 15))));
        async.elapse(const Duration(seconds: 5));
        async.flushMicrotasks();
        expect(cubit.state.now, saturdayStart.add(const Duration(minutes: 15)));
      });
    });

    group('time passing on its own', () {
      TimelineCubit autoPlaying() =>
          TimelineCubit(repository: repository, live: live, autoPlay: true);

      void play(void Function(FakeAsync async, TimelineCubit cubit) body) {
        fakeAsync((async) {
          final cubit = autoPlaying();
          unawaited(cubit.reset());
          async.flushMicrotasks();
          body(async, cubit);
          cubit.close();
        });
      }

      test('a scenario minute takes secondsPerScenarioMinute', () {
        play((async, cubit) {
          async.elapse(const Duration(seconds: secondsPerScenarioMinute * 5));

          expect(
            cubit.state.now,
            saturdayStart.add(const Duration(minutes: 5)),
          );
        });
      });

      test('tells the backend each minute as it goes by', () {
        play((async, cubit) {
          async.elapse(const Duration(seconds: secondsPerScenarioMinute * 3));

          expect(live.moves, [
            for (var m = 1; m <= 3; m++)
              saturdayStart.add(Duration(minutes: m)),
          ]);
        });
      });

      test('does not run on top of a move, and goes on after it', () {
        play((async, cubit) {
          final target = saturdayStart.add(const Duration(minutes: 15));
          live.answers = false;
          unawaited(cubit.step(const Duration(minutes: 15)));
          async.elapse(const Duration(seconds: 2));
          // While it settles the time stays where it jumped.
          expect(cubit.state.moving, isTrue);
          expect(cubit.state.now, target);

          async.elapse(const Duration(seconds: 5));
          async.flushMicrotasks();
          expect(cubit.state.moving, isFalse);
          final settled = cubit.state.now;
          expect(
            settled.difference(target),
            lessThan(const Duration(minutes: 1)),
          );

          async.elapse(const Duration(seconds: secondsPerScenarioMinute * 2));
          expect(cubit.state.now, settled.add(const Duration(minutes: 2)));
        });
      });

      test('stops at the end of the scenario', () {
        play((async, cubit) {
          unawaited(cubit.seekTo(saturdayEnd));
          async.elapse(const Duration(seconds: 40));
          async.flushMicrotasks();
          async.elapse(const Duration(minutes: 5));

          expect(cubit.state.now, saturdayEnd);
        });
      });

      test('waits while the demo is not ready', () {
        fakeAsync((async) {
          repository.failures = 1;
          final cubit = autoPlaying();
          unawaited(cubit.reset());
          async.flushMicrotasks();
          async.elapse(const Duration(minutes: 5));
          expect(cubit.state.now, saturdayStart);

          unawaited(cubit.reset());
          async.flushMicrotasks();
          async.elapse(const Duration(seconds: secondsPerScenarioMinute));
          expect(
            cubit.state.now,
            saturdayStart.add(const Duration(minutes: 1)),
          );
          cubit.close();
        });
      });

      test('a second reset does not start a second clock', () {
        play((async, cubit) {
          unawaited(cubit.reset());
          async.flushMicrotasks();
          async.elapse(const Duration(seconds: secondsPerScenarioMinute));

          expect(
            cubit.state.now,
            saturdayStart.add(const Duration(minutes: 1)),
          );
        });
      });

      test('is off unless asked for', () {
        run((async, cubit) {
          async.elapse(const Duration(minutes: 5));

          expect(cubit.state.now, saturdayStart);
        });
      });
    });

    test('a reset in the middle of a move stops it', () {
      run((async, cubit) {
        live.answers = false;
        unawaited(cubit.step(const Duration(minutes: 30)));
        async.elapse(const Duration(milliseconds: 600));
        async.flushMicrotasks();
        expect(cubit.state.moving, isTrue);

        unawaited(cubit.reset());
        async.flushMicrotasks();
        async.elapse(const Duration(seconds: 5));
        async.flushMicrotasks();

        expect(cubit.state.moving, isFalse);
        expect(cubit.state.now, saturdayStart);
        expect(cubit.state.resets, 2);
      });
    });

    test('a reset in the middle of a slow reset wins', () {
      fakeAsync((async) {
        final cubit = build();
        repository.gate = Completer<void>();
        unawaited(cubit.reset());
        async.flushMicrotasks();
        repository.gate = null;
        unawaited(cubit.reset());
        async.flushMicrotasks();
        expect(cubit.state.status, TimelineStatus.ready);
        cubit.close();
      });
    });

    test('a reset that fails after it was replaced is ignored', () {
      fakeAsync((async) {
        final cubit = build();
        repository.failures = 1;
        unawaited(cubit.reset());
        unawaited(cubit.reset());
        async.flushMicrotasks();

        expect(cubit.state.status, TimelineStatus.ready);
        cubit.close();
      });
    });

    test('closing stops the time', () {
      fakeAsync((async) {
        final cubit = build();
        unawaited(cubit.reset());
        async.flushMicrotasks();
        unawaited(cubit.step(const Duration(minutes: 15)));
        async.flushMicrotasks();

        cubit.close();

        expect(async.pendingTimers, isEmpty);
      });
    });
  });

  group(TimelineState, () {
    test('copies, keeping what it is not given', () {
      final state = TimelineState();
      final copy = state.copyWith(moving: true);

      expect(copy.moving, isTrue);
      expect(copy.now, state.now);
      expect(copy, isNot(state));
      expect(state.copyWith(), state);
    });

    test('copies every field', () {
      final later = DateTime.utc(2026, 10, 10, 18);
      final copy = TimelineState().copyWith(
        status: TimelineStatus.ready,
        now: later,
        start: later,
        end: later,
        revision: 3,
        resets: 2,
      );

      expect(copy.status, TimelineStatus.ready);
      expect(copy.now, later);
      expect(copy.revision, 3);
      expect(copy.resets, 2);
    });
  });
}
