// Each step of a scenario is its own line on purpose.
// ignore_for_file: cascade_invocations
import 'dart:async';

import 'package:a2ui_vgv_smart_home/action_toast/cubit/action_toast_cubit.dart';
import 'package:fake_async/fake_async.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:home_frontend/home_frontend.dart';

void main() {
  group('ActionToastCubit', () {
    late StreamController<GenUIAgentEvent> events;
    late ActionToastCubit cubit;

    /// Runs [body] with a cubit whose timers are fake.
    void run(void Function(FakeAsync async) body) {
      fakeAsync((async) {
        events = StreamController<GenUIAgentEvent>.broadcast();
        cubit = ActionToastCubit(
          events: events.stream,
          successHold: const Duration(seconds: 1),
          errorHold: const Duration(seconds: 2),
        );
        body(async);
      });
    }

    test('starts idle', () {
      run((_) => expect(cubit.state, const ActionToastState()));
    });

    test('shows the label while a press is on its way', () {
      run((async) {
        events.add(const UiInteractionAdded('Turn off oven'));
        async.flushMicrotasks();
        expect(
          cubit.state,
          const ActionToastState(
            status: ActionToastStatus.loading,
            label: 'Turn off oven',
          ),
        );
      });
    });

    test('ignores events that are not about a request', () {
      run((async) {
        events
          ..add(const UserTurnRolledBack())
          ..add(const UiInteractionCompleted());
        async.flushMicrotasks();
        expect(cubit.state, const ActionToastState());
      });
    });

    test('keeps the label on success, then leaves after the hold', () {
      run((async) {
        events.add(const UiInteractionAdded('Turn off oven'));
        async.flushMicrotasks();
        events.add(const UiInteractionCompleted());
        async.flushMicrotasks();
        expect(
          cubit.state,
          const ActionToastState(
            status: ActionToastStatus.success,
            label: 'Turn off oven',
          ),
        );

        async.elapse(const Duration(milliseconds: 999));
        expect(cubit.state.status, ActionToastStatus.success);
        async.elapse(const Duration(milliseconds: 1));
        expect(cubit.state, const ActionToastState());
      });
    });

    test('keeps the label and the reason on error, held longer', () {
      run((async) {
        events.add(const UiInteractionAdded('Chill wine'));
        async.flushMicrotasks();
        events.add(
          const UiInteractionCompleted(succeeded: false, reason: 'Offline'),
        );
        async.flushMicrotasks();
        expect(
          cubit.state,
          const ActionToastState(
            status: ActionToastStatus.error,
            label: 'Chill wine',
            reason: 'Offline',
          ),
        );

        async.elapse(const Duration(milliseconds: 1999));
        expect(cubit.state.status, ActionToastStatus.error);
        async.elapse(const Duration(milliseconds: 1));
        expect(cubit.state, const ActionToastState());
      });
    });

    test('the newest label replaces the pill and its timer', () {
      run((async) {
        events.add(const UiInteractionAdded('First'));
        async.flushMicrotasks();
        events.add(const UiInteractionCompleted());
        async.flushMicrotasks();
        async.elapse(const Duration(milliseconds: 900));

        events.add(const UiInteractionAdded('Second'));
        async.flushMicrotasks();
        async.elapse(const Duration(seconds: 5));
        expect(cubit.state.status, ActionToastStatus.loading);
        expect(cubit.state.label, 'Second');
      });
    });

    test('a command is cancellable and ends as success or error', () {
      run((async) {
        cubit.commandStarted('Delay dinner');
        expect(
          cubit.state,
          const ActionToastState(
            status: ActionToastStatus.loading,
            label: 'Delay dinner',
            cancellable: true,
          ),
        );
        cubit.commandFinished(succeeded: true);
        expect(cubit.state.status, ActionToastStatus.success);
        expect(cubit.state.cancellable, isFalse);
        async.elapse(const Duration(seconds: 1));
        expect(cubit.state.status, ActionToastStatus.idle);

        cubit.commandStarted('Delay dinner');
        cubit.commandFinished(succeeded: false);
        expect(cubit.state.status, ActionToastStatus.error);
        expect(cubit.state.reason, isNull);
        async.elapse(const Duration(seconds: 2));
        expect(cubit.state.status, ActionToastStatus.idle);
      });
    });

    test('finishing a command that is no longer running does nothing', () {
      run((_) {
        cubit.commandFinished(succeeded: false);
        expect(cubit.state, const ActionToastState());
      });
    });

    test('dismiss takes the pill away and stops its timer', () {
      run((async) {
        cubit.commandStarted('Delay dinner');
        cubit.commandFinished(succeeded: true);
        cubit.dismiss();
        expect(cubit.state, const ActionToastState());
        cubit.commandStarted('Next');
        async.elapse(const Duration(seconds: 5));
        expect(cubit.state.label, 'Next');
      });
    });

    test('close cancels the hold', () {
      run((async) {
        cubit.commandStarted('Delay dinner');
        cubit.commandFinished(succeeded: true);
        cubit.close().ignore();
        async.flushMicrotasks();
        async.elapse(const Duration(seconds: 5));
        // The hold was cancelled: the pill was never taken away.
        expect(cubit.state.status, ActionToastStatus.success);
      });
    });
  });
}
