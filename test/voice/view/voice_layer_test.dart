import 'dart:async';

import 'package:a2ui_vgv_smart_home/action_toast/view/action_glow.dart';
import 'package:a2ui_vgv_smart_home/users/cubit/users_cubit.dart';
import 'package:a2ui_vgv_smart_home/voice/view/voice_input.dart';
import 'package:a2ui_vgv_smart_home/voice/view/voice_overlay.dart';
import 'package:app_ui/app_ui.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../helpers/fake_agent.dart';
import '../../helpers/fake_voice.dart';
import '../../helpers/helpers.dart';

/// The skeleton and the toast animate for as long as they are on screen, so
/// these tests cannot wait for the frames to stop.
Future<void> settle(WidgetTester tester) async {
  await tester.pump(const Duration(seconds: 1));
  await tester.pump(const Duration(seconds: 1));
}

final Finder _askMicrophone = find.byTooltip('Tap to speak');
final Finder _sendMicrophone = find.byTooltip('Tap to send');
final Finder _cancel = find.text('Cancel');
final Finder _card = find.text('Listening to Ana');

void main() {
  group('VoiceLayer', () {
    late FakeAgentFactory agents;
    late FakeMicrophone microphone;
    late FakeTranscriptionClient client;

    setUp(() {
      agents = FakeAgentFactory();
      microphone = FakeMicrophone();
      client = FakeTranscriptionClient();
    });

    Future<void> pump(WidgetTester tester) => tester.pumpApp(
      agents,
      microphone: microphone,
      transcriptionClient: client,
    );

    Future<void> tapToSpeak(WidgetTester tester) async {
      await tester.tap(_askMicrophone);
      await tester.pump();
      await settle(tester);
    }

    /// Says [words] and lets the pause after them end the command.
    Future<void> say(WidgetTester tester, String words) async {
      client.session.hear(words, isFinal: true);
      await tester.pump();
      await tester.pump(const Duration(seconds: 3));
      expect(client.session.stopped, isTrue);
      client.session.end();
      await tester.pump();
    }

    testWidgets('opens a card on tap and closes it when nothing is open', (
      tester,
    ) async {
      await pump(tester);
      expect(_card, findsNothing);

      await tapToSpeak(tester);
      expect(_card, findsOneWidget);
      expect(microphone.isOn, isTrue);

      await tester.tap(_cancel);
      await settle(tester);
      expect(_card, findsNothing);
    });

    testWidgets('shows the words as they come and the voice as it rises', (
      tester,
    ) async {
      await pump(tester);
      await tapToSpeak(tester);
      expect(find.textContaining('“'), findsNothing);

      client.session.hear('Delay the');
      microphone.speak([0, 64, 0, 64]);
      await tester.pump();

      expect(find.text('“Delay the”'), findsOneWidget);
    });

    testWidgets('sends the command a pause after the last words', (
      tester,
    ) async {
      await pump(tester);
      final agent = agents.agents.single..hold = Completer<void>();
      await tapToSpeak(tester);

      await say(tester, 'Delay the oven preheat.');
      await tester.pump(const Duration(seconds: 1));

      expect(agent.sent.last, 'Delay the oven preheat.');
      expect(_card, findsNothing);
      expect(find.text('Delay the oven preheat.'), findsOneWidget);

      agent.hold!.complete();
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 600));
      // The same pill turns green and says so for a moment, then leaves.
      expect(find.text('Completed'), findsOneWidget);
      expect(find.byKey(const ValueKey('success')), findsOneWidget);
      await tester.pump(const Duration(seconds: 2));
      await tester.pump(const Duration(seconds: 1));
      expect(find.text('Completed'), findsNothing);
    });

    testWidgets('a command that fails shows the error on the same pill', (
      tester,
    ) async {
      await pump(tester);
      final agent = agents.agents.single
        ..hold = Completer<void>()
        ..failNext = Exception('boom');
      await tapToSpeak(tester);
      await say(tester, 'Delay dinner');
      await tester.pump(const Duration(seconds: 1));
      expect(find.byKey(const ValueKey('loading')), findsOneWidget);

      agent.hold!.complete();
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 600));

      expect(find.text('Delay dinner'), findsOneWidget);
      expect(find.byKey(const ValueKey('error')), findsOneWidget);
      expect(find.text('Something went wrong. Try again.'), findsOneWidget);
      await tester.pump(const Duration(seconds: 4));
      await tester.pump(const Duration(seconds: 1));
      expect(find.text('Delay dinner'), findsNothing);
    });

    testWidgets('sends the command when the microphone is tapped again', (
      tester,
    ) async {
      await pump(tester);
      final agent = agents.agents.single;
      await tapToSpeak(tester);
      client.session.hear('Chill the wine', isFinal: true);
      await tester.pump();

      await tester.tap(_sendMicrophone);
      await tester.pump();
      expect(client.session.stopped, isTrue);
      client.session.end();
      await tester.pump();

      expect(agent.sent.last, 'Chill the wine');
    });

    testWidgets('cancel sends nothing', (tester) async {
      await pump(tester);
      await tapToSpeak(tester);
      client.session.hear('Never mind', isFinal: true);
      await tester.pump();

      await tester.tap(_cancel);
      await settle(tester);

      expect(microphone.isOn, isFalse);
      expect(client.session.closed, isTrue);
      expect(agents.agents.single.sent, hasLength(1));
    });

    testWidgets('closes by itself when nothing is said', (tester) async {
      await pump(tester);
      await tapToSpeak(tester);

      await tester.pump(const Duration(seconds: 11));
      await settle(tester);

      expect(_card, findsNothing);
      expect(microphone.isOn, isFalse);
      expect(agents.agents.single.sent, hasLength(1));
    });

    testWidgets('closes without a command when cancelled while connecting', (
      tester,
    ) async {
      final gate = Completer<void>();
      client = FakeTranscriptionClient(gate: gate);
      await pump(tester);

      await tester.tap(_askMicrophone);
      await settle(tester);
      await tester.tap(_cancel);
      gate.complete();
      await settle(tester);

      expect(_card, findsNothing);
      expect(client.session.closed, isTrue);
      expect(microphone.starts, 0);
    });

    testWidgets('listens while the dashboard loads', (tester) async {
      agents = FakeAgentFactory(gate: Completer<void>());
      await pump(tester);
      await tester.pump();

      await tapToSpeak(tester);

      expect(client.sessions, hasLength(1));
      expect(_card, findsOneWidget);
    });

    group('while the panel answers', () {
      testWidgets('a second command waits for the first', (tester) async {
        await pump(tester);
        final agent = agents.agents.single..hold = Completer<void>();

        await tapToSpeak(tester);
        await say(tester, 'First');
        await tester.pump(const Duration(seconds: 1));
        expect(agent.sent.last, 'First');

        await tapToSpeak(tester);
        await say(tester, 'Second');
        await tester.pump(const Duration(seconds: 1));
        expect(client.sessions, hasLength(2));
        expect(agent.sent, isNot(contains('Second')));
        expect(find.text('Second'), findsOneWidget);

        agent.hold!.complete();
        await tester.pump();
        await tester.pump();
        expect(agent.sent.last, 'Second');
      });

      testWidgets('cancelling the toast drops the command', (tester) async {
        await pump(tester);
        final agent = agents.agents.single..hold = Completer<void>();
        await tapToSpeak(tester);
        await say(tester, 'Delay dinner');
        await tester.pump(const Duration(seconds: 1));
        expect(find.text('Delay dinner'), findsOneWidget);

        await tester.tap(_cancel);
        await settle(tester);

        expect(find.text('Delay dinner'), findsNothing);
        agent.hold!.complete();
        await tester.pump();
      });

      testWidgets('cancelling a waiting command leaves the turn running', (
        tester,
      ) async {
        await pump(tester);
        final agent = agents.agents.single..hold = Completer<void>();
        await tapToSpeak(tester);
        await say(tester, 'First');
        await tester.pump(const Duration(seconds: 1));
        await tapToSpeak(tester);
        await say(tester, 'Second');
        await tester.pump(const Duration(seconds: 1));

        await tester.tap(_cancel);
        await settle(tester);
        agent.hold!.complete();
        await tester.pump();
        await tester.pump();

        expect(agent.sent, isNot(contains('Second')));
        expect(find.text('Second'), findsNothing);
      });
    });

    testWidgets('explains the browser prompt, then listens on the next tap', (
      tester,
    ) async {
      microphone = FakeMicrophone(granted: false);
      await pump(tester);

      await tester.tap(_askMicrophone);
      await settle(tester);
      expect(find.byType(MicrophonePermissionDialog), findsOneWidget);
      expect(microphone.requests, 0);

      await tester.tap(find.text('Continue'));
      await settle(tester);
      expect(find.byType(MicrophonePermissionDialog), findsNothing);
      expect(microphone.requests, 1);
      expect(microphone.starts, 0);

      await tapToSpeak(tester);
      expect(microphone.isOn, isTrue);
    });

    testWidgets('cancelling the explanation asks nothing', (tester) async {
      microphone = FakeMicrophone(granted: false);
      await pump(tester);

      await tester.tap(_askMicrophone);
      await settle(tester);
      await tester.tap(_cancel);
      await settle(tester);

      expect(find.byType(MicrophonePermissionDialog), findsNothing);
      expect(microphone.requests, 0);
      expect(client.sessions, isEmpty);
    });

    group('says the microphone is unavailable', () {
      final message = find.text(
        "The microphone isn't available. Allow it in your browser's site "
        'settings and try again.',
      );

      testWidgets('when the browser prompt is refused', (tester) async {
        microphone = FakeMicrophone(granted: false, grantOnRequest: false);
        await pump(tester);

        await tester.tap(_askMicrophone);
        await settle(tester);
        await tester.tap(find.text('Continue'));
        await tester.pump();

        expect(message, findsOneWidget);
      });

      testWidgets('when it fails to start', (tester) async {
        microphone = FakeMicrophone(failStart: true);
        await pump(tester);

        await tapToSpeak(tester);

        expect(message, findsOneWidget);
        expect(_card, findsNothing);
      });
    });

    testWidgets('says when the command could not be transcribed', (
      tester,
    ) async {
      await pump(tester);

      await tapToSpeak(tester);
      client.session.fail();
      await tester.pump();

      expect(
        find.text("Couldn't turn that into text. Try again."),
        findsOneWidget,
      );
    });

    testWidgets('veils the whole screen while the card is open', (
      tester,
    ) async {
      await pump(tester);
      await tapToSpeak(tester);

      const screen = Size(AppSpacing.panelWidth, AppSpacing.panelHeight);
      expect(tester.getSize(find.byType(VoiceScrim)), screen);
      expect(tester.getSize(find.byType(ActionGlow)), screen);
      final veil = tester.getRect(find.byType(VoiceScrim));
      expect(
        veil.contains(tester.getRect(find.byType(Sidebar)).topLeft),
        isTrue,
      );
    });

    testWidgets('switching user drops the command being spoken', (
      tester,
    ) async {
      await pump(tester);

      await tapToSpeak(tester);
      // The veil covers the sidebar while the card is open, so the user is
      // switched from where a reset would switch it.
      tester.element(find.byType(VoiceInput)).read<UsersCubit>().select(marco);
      await settle(tester);

      expect(microphone.isOn, isFalse);
      expect(client.session.closed, isTrue);
      expect(tester.takeException(), isNull);
    });
  });
}
