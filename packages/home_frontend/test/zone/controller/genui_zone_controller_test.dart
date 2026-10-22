import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:genui/genui.dart';
import 'package:home_frontend/src/agent/genui_agent.dart';
import 'package:home_frontend/src/agent/genui_agent_event.dart';
import 'package:home_frontend/src/zone/controller/genui_zone_controller.dart';
import 'package:home_frontend/src/zone/controller/genui_zone_item.dart';
import 'package:home_frontend/src/zone/controller/genui_zone_state.dart';
import 'package:mocktail/mocktail.dart';

class _MockGenUIAgent extends Mock implements GenUIAgent {}

class _FakeSurfaceController extends Fake implements SurfaceController {}

class _FakeSurfaceDefinition extends Fake implements SurfaceDefinition {}

ConversationEventReceived _surfaceReceived(String id) =>
    ConversationEventReceived(
      ConversationSurfaceAdded(id, _FakeSurfaceDefinition()),
    );

void main() {
  late _MockGenUIAgent agent;
  late StreamController<GenUIAgentEvent> eventsController;
  late _FakeSurfaceController surfaceController;

  setUp(() {
    agent = _MockGenUIAgent();
    eventsController = StreamController<GenUIAgentEvent>.broadcast();
    surfaceController = _FakeSurfaceController();
    when(() => agent.events).thenAnswer((_) => eventsController.stream);
    when(() => agent.controller).thenReturn(surfaceController);
    when(agent.dispose).thenAnswer((_) {});
  });

  tearDown(() async {
    await eventsController.close();
  });

  group(GenUIZoneController, () {
    test('starts in the Initial state with isSending false', () {
      final controller = GenUIZoneController(agent: agent);

      expect(controller.state, isA<GenUIZoneInitial>());
      expect(controller.isSending, isFalse);

      controller.dispose();
    });

    test('does not emit when start resolves with no events', () async {
      when(agent.start).thenAnswer((_) async {});
      final controller = GenUIZoneController(agent: agent);
      final states = <GenUIZoneState>[];
      controller.addListener(() => states.add(controller.state));

      await controller.start();

      expect(states, isEmpty);
      expect(controller.state, isA<GenUIZoneInitial>());

      controller.dispose();
    });

    test(
      'appends SurfaceItem and notifies listeners when surface events arrive',
      () async {
        when(agent.start).thenAnswer((_) async {});
        final controller = GenUIZoneController(agent: agent);
        final states = <GenUIZoneState>[];
        controller.addListener(() => states.add(controller.state));

        await controller.start();
        eventsController
          ..add(_surfaceReceived('surface-1'))
          ..add(_surfaceReceived('surface-2'));
        await Future<void>.delayed(Duration.zero);

        expect(states, hasLength(2));
        expect(
          states.first,
          isA<GenUIZoneItemsUpdated>().having(
            (s) => s.items,
            'items',
            [isA<SurfaceItem>().having((i) => i.surfaceId, 'id', 'surface-1')],
          ),
        );
        expect(
          states.last,
          isA<GenUIZoneItemsUpdated>()
              .having((s) => s.items, 'items', [
                isA<SurfaceItem>().having(
                  (i) => i.surfaceId,
                  'id',
                  'surface-1',
                ),
                isA<SurfaceItem>().having(
                  (i) => i.surfaceId,
                  'id',
                  'surface-2',
                ),
              ])
              .having((s) => s.controller, 'controller', surfaceController),
        );

        controller.dispose();
      },
    );

    test('appends UserMessageItem when UserMessageAdded arrives', () async {
      when(agent.start).thenAnswer((_) async {});
      final controller = GenUIZoneController(agent: agent);
      final states = <GenUIZoneState>[];
      controller.addListener(() => states.add(controller.state));

      await controller.start();
      eventsController.add(const UserMessageAdded('hi'));
      await Future<void>.delayed(Duration.zero);

      expect(states, hasLength(1));
      expect(
        controller.state,
        isA<GenUIZoneItemsUpdated>().having((s) => s.items, 'items', [
          isA<UserMessageItem>().having((i) => i.text, 'text', 'hi'),
        ]),
      );

      controller.dispose();
    });

    test(
      'interleaves user messages and surfaces in arrival order',
      () async {
        when(agent.start).thenAnswer((_) async {});
        final controller = GenUIZoneController(agent: agent);
        await controller.start();

        eventsController
          ..add(const UserMessageAdded('hello'))
          ..add(_surfaceReceived('surface-1'))
          ..add(const UserMessageAdded('again'))
          ..add(_surfaceReceived('surface-2'));
        await Future<void>.delayed(Duration.zero);

        final state = controller.state as GenUIZoneItemsUpdated;
        expect(state.items, [
          isA<UserMessageItem>().having((i) => i.text, 'text', 'hello'),
          isA<SurfaceItem>().having((i) => i.surfaceId, 'id', 'surface-1'),
          isA<UserMessageItem>().having((i) => i.text, 'text', 'again'),
          isA<SurfaceItem>().having((i) => i.surfaceId, 'id', 'surface-2'),
        ]);

        controller.dispose();
      },
    );

    test('items list is unmodifiable', () async {
      when(agent.start).thenAnswer((_) async {});
      final controller = GenUIZoneController(agent: agent);

      await controller.start();
      eventsController.add(_surfaceReceived('surface-1'));
      await Future<void>.delayed(Duration.zero);

      final state = controller.state as GenUIZoneItemsUpdated;
      expect(
        () => state.items.add(const SurfaceItem('x')),
        throwsUnsupportedError,
      );

      controller.dispose();
    });

    test('emits Error when agent.start throws', () async {
      when(agent.start).thenThrow(Exception('boom'));
      final controller = GenUIZoneController(agent: agent);

      await controller.start();

      expect(
        controller.state,
        isA<GenUIZoneError>().having(
          (s) => s.error,
          'error',
          contains('boom'),
        ),
      );

      controller.dispose();
    });

    test('sendMessage forwards text to agent.sendMessage', () async {
      when(agent.start).thenAnswer((_) async {});
      when(() => agent.sendMessage(any())).thenAnswer((_) async {});
      final controller = GenUIZoneController(agent: agent);
      await controller.start();

      await controller.sendMessage('hello');

      verify(() => agent.sendMessage('hello')).called(1);

      controller.dispose();
    });

    test('sendMessage records an ErrorItem when agent throws', () async {
      when(agent.start).thenAnswer((_) async {});
      when(() => agent.sendMessage(any())).thenThrow(Exception('boom'));
      final controller = GenUIZoneController(agent: agent);
      await controller.start();

      await controller.sendMessage('hello');

      expect(
        controller.state,
        isA<GenUIZoneItemsUpdated>().having((s) => s.items, 'items', [
          isA<ErrorItem>().having(
            (i) => i.error,
            'error',
            isA<Exception>().having(
              (e) => e.toString(),
              'toString',
              contains('boom'),
            ),
          ),
        ]),
      );

      controller.dispose();
    });

    test('a failed send keeps the items that preceded it', () async {
      // A failure used to replace the whole state with GenUIZoneError, which
      // erased the conversation the user could still see.
      when(agent.start).thenAnswer((_) async {});
      when(() => agent.sendMessage(any())).thenThrow(Exception('boom'));
      final controller = GenUIZoneController(agent: agent);
      await controller.start();

      eventsController.add(_surfaceReceived('surface-1'));
      await Future<void>.delayed(Duration.zero);
      await controller.sendMessage('hello');

      expect((controller.state as GenUIZoneItemsUpdated).items, [
        isA<SurfaceItem>().having((i) => i.surfaceId, 'id', 'surface-1'),
        isA<ErrorItem>(),
      ]);

      controller.dispose();
    });

    test(
      'isSending flips true during sendMessage and back to false on completion',
      () async {
        when(agent.start).thenAnswer((_) async {});
        final sendCompleter = Completer<void>();
        when(
          () => agent.sendMessage(any()),
        ).thenAnswer((_) => sendCompleter.future);
        final controller = GenUIZoneController(agent: agent);
        await controller.start();

        final future = controller.sendMessage('hello');
        expect(controller.isSending, isTrue);

        sendCompleter.complete();
        await future;
        expect(controller.isSending, isFalse);

        controller.dispose();
      },
    );

    group('discardTurn', () {
      late Completer<void> turn;
      late GenUIZoneController controller;

      setUp(() async {
        when(agent.start).thenAnswer((_) async {});
        turn = Completer<void>();
        when(() => agent.sendMessage(any())).thenAnswer((_) => turn.future);
        controller = GenUIZoneController(agent: agent);
        await controller.start();
      });

      tearDown(() => controller.dispose());

      test('drops the surface of the turn in flight', () async {
        final sent = controller.sendMessage('hello');
        controller.discardTurn();

        eventsController.add(_surfaceReceived('late'));
        await pumpEventQueue();

        expect(controller.state, isA<GenUIZoneInitial>());
        // The agent is still busy, so a new turn has to wait for it.
        expect(controller.isSending, isTrue);

        turn.complete();
        await sent;
        expect(controller.isSending, isFalse);
      });

      test('drops the error of the turn in flight', () async {
        when(
          () => agent.sendMessage(any()),
        ).thenAnswer((_) => turn.future);
        final sent = controller.sendMessage('hello');
        controller.discardTurn();

        eventsController.add(
          ConversationEventReceived(ConversationError(Exception('boom'))),
        );
        turn.completeError(Exception('thrown'));
        await sent;

        expect(controller.state, isA<GenUIZoneInitial>());
      });

      test('does nothing when no turn is in flight', () async {
        controller.discardTurn();

        final sent = controller.sendMessage('hello');
        eventsController.add(_surfaceReceived('next'));
        await pumpEventQueue();
        turn.complete();
        await sent;

        expect(controller.state, isA<GenUIZoneItemsUpdated>());
      });

      test('does not outlive the turn it discarded', () async {
        final first = controller.sendMessage('first');
        controller.discardTurn();
        turn.complete();
        await first;

        final second = controller.sendMessage('second');
        eventsController.add(_surfaceReceived('next'));
        await pumpEventQueue();

        expect(controller.state, isA<GenUIZoneItemsUpdated>());
        await second;
      });
    });

    test('isSending resets to false when sendMessage throws', () async {
      when(agent.start).thenAnswer((_) async {});
      when(() => agent.sendMessage(any())).thenThrow(Exception('boom'));
      final controller = GenUIZoneController(agent: agent);
      await controller.start();

      await controller.sendMessage('hello');

      expect(controller.isSending, isFalse);

      controller.dispose();
    });

    test(
      'isSending resets to false when a surface arrives mid-send',
      () async {
        when(agent.start).thenAnswer((_) async {});
        final sendCompleter = Completer<void>();
        when(() => agent.sendMessage(any())).thenAnswer((_) async {
          eventsController.add(_surfaceReceived('surface-1'));
          await sendCompleter.future;
        });
        final controller = GenUIZoneController(agent: agent);
        await controller.start();

        final future = controller.sendMessage('hello');
        await Future<void>.delayed(Duration.zero);

        expect(controller.isSending, isFalse);
        expect(controller.state, isA<GenUIZoneItemsUpdated>());

        sendCompleter.complete();
        await future;

        controller.dispose();
      },
    );

    test(
      'UserMessageAdded does not flip isSending false mid-send',
      () async {
        when(agent.start).thenAnswer((_) async {});
        final sendCompleter = Completer<void>();
        when(() => agent.sendMessage(any())).thenAnswer((_) async {
          eventsController.add(const UserMessageAdded('hello'));
          await sendCompleter.future;
        });
        final controller = GenUIZoneController(agent: agent);
        await controller.start();

        final future = controller.sendMessage('hello');
        await Future<void>.delayed(Duration.zero);

        expect(controller.isSending, isTrue);
        expect(controller.state, isA<GenUIZoneItemsUpdated>());

        sendCompleter.complete();
        await future;
        expect(controller.isSending, isFalse);

        controller.dispose();
      },
    );

    group('UI interactions', () {
      test('failedTurns counts failed completions only', () async {
        when(agent.start).thenAnswer((_) async {});
        final controller = GenUIZoneController(agent: agent);
        await controller.start();
        var notified = 0;
        controller.addListener(() => notified++);
        expect(controller.failedTurns, 0);

        eventsController.add(const UiInteractionCompleted());
        await Future<void>.delayed(Duration.zero);
        expect(controller.failedTurns, 0);

        eventsController
          ..add(const UiInteractionAdded('Testing'))
          ..add(const UiInteractionCompleted(succeeded: false, reason: 'No'));
        await Future<void>.delayed(Duration.zero);
        expect(controller.failedTurns, 1);
        expect(controller.isSending, isFalse);
        expect(notified, greaterThan(0));

        eventsController.add(const UiInteractionCompleted(succeeded: false));
        await Future<void>.delayed(Duration.zero);
        expect(controller.failedTurns, 2);

        controller.dispose();
      });

      test(
        'UiInteractionAdded records the interaction and starts sending',
        () async {
          // A press on a generated surface never reaches sendMessage, so the
          // controller has to enter the in-flight state off the event instead.
          when(agent.start).thenAnswer((_) async {});
          final controller = GenUIZoneController(agent: agent);
          await controller.start();

          eventsController.add(const UiInteractionAdded('Testing'));
          await Future<void>.delayed(Duration.zero);

          expect(controller.isSending, isTrue);
          expect(
            controller.state,
            isA<GenUIZoneItemsUpdated>().having((s) => s.items, 'items', [
              isA<UserMessageItem>().having((i) => i.text, 'text', 'Testing'),
            ]),
          );

          controller.dispose();
        },
      );

      test('UiInteractionCompleted clears the sending state', () async {
        when(agent.start).thenAnswer((_) async {});
        final controller = GenUIZoneController(agent: agent);
        await controller.start();

        eventsController.add(const UiInteractionAdded('Testing'));
        await Future<void>.delayed(Duration.zero);
        expect(controller.isSending, isTrue);

        eventsController.add(const UiInteractionCompleted());
        await Future<void>.delayed(Duration.zero);

        expect(controller.isSending, isFalse);

        controller.dispose();
      });

      test(
        'an interaction locks the surfaces that preceded it',
        () async {
          // The view derives locking from the index of the latest user item,
          // so recording the interaction is what freezes the picker behind it.
          when(agent.start).thenAnswer((_) async {});
          final controller = GenUIZoneController(agent: agent);
          await controller.start();

          eventsController
            ..add(const UserMessageAdded('seed'))
            ..add(_surfaceReceived('picker'))
            ..add(const UiInteractionAdded('Testing'));
          await Future<void>.delayed(Duration.zero);

          // The picker now sits before the latest user item, rather than the
          // seed at index 0 staying latest for the whole session.
          final items = (controller.state as GenUIZoneItemsUpdated).items;
          expect(items, [
            isA<UserMessageItem>().having((i) => i.text, 'text', 'seed'),
            isA<SurfaceItem>().having((i) => i.surfaceId, 'id', 'picker'),
            isA<UserMessageItem>().having((i) => i.text, 'text', 'Testing'),
          ]);

          controller.dispose();
        },
      );

      test('a surface arriving for an interaction stops sending', () async {
        when(agent.start).thenAnswer((_) async {});
        final controller = GenUIZoneController(agent: agent);
        await controller.start();

        eventsController
          ..add(const UiInteractionAdded('Testing'))
          ..add(_surfaceReceived('lesson'));
        await Future<void>.delayed(Duration.zero);

        expect(controller.isSending, isFalse);

        controller.dispose();
      });
    });

    group(UserTurnRolledBack, () {
      test('marks the interaction that froze a surface as failed', () async {
        // A failed interaction must not age out the picker behind it: marking
        // it failed makes 'seed' the newest turn again.
        when(agent.start).thenAnswer((_) async {});
        final controller = GenUIZoneController(agent: agent);
        await controller.start();

        eventsController
          ..add(const UserMessageAdded('seed'))
          ..add(_surfaceReceived('picker'))
          ..add(const UiInteractionAdded('Testing'))
          ..add(const UserTurnRolledBack());
        await Future<void>.delayed(Duration.zero);

        expect((controller.state as GenUIZoneItemsUpdated).items, [
          isA<UserMessageItem>()
              .having((i) => i.text, 'text', 'seed')
              .having((i) => i.failed, 'failed', isFalse),
          isA<SurfaceItem>().having((i) => i.surfaceId, 'id', 'picker'),
          isA<UserMessageItem>()
              .having((i) => i.text, 'text', 'Testing')
              .having((i) => i.failed, 'failed', isTrue),
        ]);

        controller.dispose();
      });

      test('keeps the bubble a failed typed message left behind', () async {
        when(agent.start).thenAnswer((_) async {});
        final controller = GenUIZoneController(agent: agent);
        await controller.start();

        eventsController
          ..add(const UserMessageAdded('hello'))
          ..add(const UserTurnRolledBack());
        await Future<void>.delayed(Duration.zero);

        expect((controller.state as GenUIZoneItemsUpdated).items, [
          isA<UserMessageItem>()
              .having((i) => i.text, 'text', 'hello')
              .having((i) => i.failed, 'failed', isTrue),
        ]);

        controller.dispose();
      });

      test('marks the message when the error item landed first', () async {
        // A throwing sendMessage appends the ErrorItem before the rollback
        // event is delivered, so the message is no longer the trailing item.
        when(agent.start).thenAnswer((_) async {});
        when(() => agent.sendMessage(any())).thenAnswer((_) async {
          eventsController
            ..add(const UserMessageAdded('kenya'))
            ..add(const UserTurnRolledBack());
          throw Exception('failed to fetch');
        });
        final controller = GenUIZoneController(agent: agent);
        await controller.start();

        await controller.sendMessage('kenya');
        await Future<void>.delayed(Duration.zero);

        expect((controller.state as GenUIZoneItemsUpdated).items, [
          isA<UserMessageItem>()
              .having((i) => i.text, 'text', 'kenya')
              .having((i) => i.failed, 'failed', isTrue),
          isA<ErrorItem>(),
        ]);

        controller.dispose();
      });

      test('leaves an earlier successful turn alone', () async {
        // The scan stops at the last surface, so a rollback that carries no
        // message of its own cannot mark a message that already got a reply.
        when(agent.start).thenAnswer((_) async {});
        final controller = GenUIZoneController(agent: agent);
        await controller.start();

        eventsController
          ..add(const UserMessageAdded('seed'))
          ..add(_surfaceReceived('lesson'))
          ..add(const UserTurnRolledBack());
        await Future<void>.delayed(Duration.zero);

        expect((controller.state as GenUIZoneItemsUpdated).items, [
          isA<UserMessageItem>()
              .having((i) => i.text, 'text', 'seed')
              .having((i) => i.failed, 'failed', isFalse),
          isA<SurfaceItem>().having((i) => i.surfaceId, 'id', 'lesson'),
        ]);

        controller.dispose();
      });

      test('leaves a surface in place', () async {
        // Only a trailing user item is rolled back. A turn that produced a
        // surface is never reported as rolled back; this guards the ordering.
        when(agent.start).thenAnswer((_) async {});
        final controller = GenUIZoneController(agent: agent);
        await controller.start();

        eventsController
          ..add(_surfaceReceived('lesson'))
          ..add(const UserTurnRolledBack());
        await Future<void>.delayed(Duration.zero);

        expect((controller.state as GenUIZoneItemsUpdated).items, [
          isA<SurfaceItem>().having((i) => i.surfaceId, 'id', 'lesson'),
        ]);

        controller.dispose();
      });

      test('is a no-op when no item has been recorded yet', () async {
        when(agent.start).thenAnswer((_) async {});
        final controller = GenUIZoneController(agent: agent);
        final states = <GenUIZoneState>[];
        controller.addListener(() => states.add(controller.state));

        await controller.start();
        eventsController.add(const UserTurnRolledBack());
        await Future<void>.delayed(Duration.zero);

        expect(states, isEmpty);
        expect(controller.state, isA<GenUIZoneInitial>());

        controller.dispose();
      });

      test('does not notify listeners after dispose', () async {
        when(agent.start).thenAnswer((_) async {});
        final controller = GenUIZoneController(agent: agent);
        await controller.start();

        eventsController.add(const UserMessageAdded('hello'));
        await Future<void>.delayed(Duration.zero);

        var notifications = 0;
        controller
          ..addListener(() => notifications++)
          ..dispose();

        eventsController.add(const UserTurnRolledBack());
        await Future<void>.delayed(Duration.zero);

        expect(notifications, 0);
      });
    });

    group(ConversationError, () {
      test('records an ErrorItem so a failed interaction is visible', () async {
        // The SDK's Conversation reports failures as an event rather than
        // throwing, so without this a failed tap produces no feedback at all.
        when(agent.start).thenAnswer((_) async {});
        final controller = GenUIZoneController(agent: agent);
        await controller.start();

        eventsController.add(
          ConversationEventReceived(ConversationError(Exception('boom'))),
        );
        await Future<void>.delayed(Duration.zero);

        expect(
          controller.state,
          isA<GenUIZoneItemsUpdated>().having((s) => s.items, 'items', [
            isA<ErrorItem>().having(
              (i) => i.error,
              'error',
              isA<Exception>().having(
                (e) => e.toString(),
                'toString',
                contains('boom'),
              ),
            ),
          ]),
        );

        controller.dispose();
      });

      test('keeps the surfaces and messages that preceded it', () async {
        when(agent.start).thenAnswer((_) async {});
        final controller = GenUIZoneController(agent: agent);
        await controller.start();

        eventsController
          ..add(const UserMessageAdded('seed'))
          ..add(_surfaceReceived('picker'))
          ..add(
            ConversationEventReceived(ConversationError(Exception('boom'))),
          );
        await Future<void>.delayed(Duration.zero);

        expect((controller.state as GenUIZoneItemsUpdated).items, [
          isA<UserMessageItem>().having((i) => i.text, 'text', 'seed'),
          isA<SurfaceItem>().having((i) => i.surfaceId, 'id', 'picker'),
          isA<ErrorItem>(),
        ]);

        controller.dispose();
      });

      test('clears the sending state a failed interaction left set', () async {
        when(agent.start).thenAnswer((_) async {});
        final controller = GenUIZoneController(agent: agent);
        await controller.start();

        eventsController
          ..add(const UiInteractionAdded('Testing'))
          ..add(
            ConversationEventReceived(ConversationError(Exception('boom'))),
          );
        await Future<void>.delayed(Duration.zero);

        expect(controller.isSending, isFalse);

        controller.dispose();
      });

      test('does not notify listeners after dispose', () async {
        when(agent.start).thenAnswer((_) async {});
        final controller = GenUIZoneController(agent: agent);
        await controller.start();

        var notifications = 0;
        controller
          ..addListener(() => notifications++)
          ..dispose();

        eventsController.add(
          ConversationEventReceived(ConversationError(Exception('boom'))),
        );
        await Future<void>.delayed(Duration.zero);

        expect(notifications, 0);
      });
    });

    test('ignores conversation events that carry no zone item', () async {
      // Text, waiting, component updates, and surface removals all flow through
      // the same subscription; none of them changes the item list.
      when(agent.start).thenAnswer((_) async {});
      final controller = GenUIZoneController(agent: agent);
      final states = <GenUIZoneState>[];
      controller.addListener(() => states.add(controller.state));

      await controller.start();
      eventsController
        ..add(ConversationEventReceived(ConversationWaiting()))
        ..add(ConversationEventReceived(ConversationContentReceived('hi')))
        ..add(
          ConversationEventReceived(
            ConversationComponentsUpdated('s-1', _FakeSurfaceDefinition()),
          ),
        )
        ..add(ConversationEventReceived(ConversationSurfaceRemoved('s-1')));
      await Future<void>.delayed(Duration.zero);

      expect(states, isEmpty);
      expect(controller.state, isA<GenUIZoneInitial>());

      controller.dispose();
    });

    test('start asserts in debug when called a second time', () async {
      when(agent.start).thenAnswer((_) async {});
      final controller = GenUIZoneController(agent: agent);

      await controller.start();
      expect(controller.start, throwsA(isA<AssertionError>()));
      verify(agent.start).called(1);

      controller.dispose();
    });

    test(
      'dispose cancels the subscription without disposing the agent',
      () async {
        when(agent.start).thenAnswer((_) async {});
        final controller = GenUIZoneController(agent: agent);
        await controller.start();

        expect(eventsController.hasListener, isTrue);

        controller.dispose();

        expect(eventsController.hasListener, isFalse);
        verifyNever(agent.dispose);
      },
    );

    test('dispose is safe before start', () {
      final controller = GenUIZoneController(agent: agent);

      expect(controller.dispose, returnsNormally);
      verifyNever(agent.dispose);
    });

    test(
      'surface events arriving after dispose do not notify listeners',
      () async {
        when(agent.start).thenAnswer((_) async {});
        final controller = GenUIZoneController(agent: agent);
        await controller.start();

        var notifications = 0;
        controller
          ..addListener(() => notifications++)
          ..dispose();

        eventsController.add(_surfaceReceived('late'));
        await Future<void>.delayed(Duration.zero);

        expect(notifications, 0);
      },
    );
  });
}
