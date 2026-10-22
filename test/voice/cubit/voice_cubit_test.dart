import 'dart:async';
import 'dart:typed_data';

import 'package:a2ui_vgv_smart_home/voice/cubit/voice_cubit.dart';
import 'package:bloc_test/bloc_test.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../helpers/fake_voice.dart';

const _connecting = VoiceState(status: VoiceStatus.connecting);
const _listening = VoiceState(status: VoiceStatus.listening);
const _microphoneUnavailable = VoiceState(
  status: VoiceStatus.failure,
  failure: VoiceFailure.microphoneUnavailable,
);
const _transcriptionFailed = VoiceState(
  status: VoiceStatus.failure,
  failure: VoiceFailure.transcriptionFailed,
);

void main() {
  group('VoiceCubit', () {
    late FakeMicrophone microphone;
    late FakeTranscriptionClient client;

    setUp(() {
      microphone = FakeMicrophone();
      client = FakeTranscriptionClient();
    });

    VoiceCubit build() => VoiceCubit(microphone: microphone, client: client);

    test('starts idle', () {
      expect(build().state, const VoiceState());
    });

    blocTest<VoiceCubit, VoiceState>(
      'start listens and streams the microphone when it is granted',
      build: build,
      act: (cubit) async {
        await cubit.start();
        microphone.speak([1, 2]);
        await pumpEventQueue();
      },
      expect: () => [
        _connecting,
        _listening,
        isA<VoiceState>().having((state) => state.levels, 'levels', [
          audioLevel(Uint8List.fromList([1, 2])),
        ]),
      ],
      verify: (_) {
        expect(client.session.audio, [
          [1, 2],
        ]);
      },
    );

    blocTest<VoiceCubit, VoiceState>(
      'start asks for an explanation first when the microphone is not granted',
      build: () {
        microphone = FakeMicrophone(granted: false);
        return build();
      },
      act: (cubit) => cubit.start(),
      expect: () => const [
        _connecting,
        VoiceState(status: VoiceStatus.permissionNeeded),
      ],
      verify: (_) {
        expect(microphone.starts, 0);
        expect(client.sessions, isEmpty);
      },
    );

    blocTest<VoiceCubit, VoiceState>(
      'permissionConfirmed asks the browser and waits for the next tap',
      build: () {
        microphone = FakeMicrophone(granted: false);
        return build();
      },
      seed: () => const VoiceState(status: VoiceStatus.permissionNeeded),
      act: (cubit) => cubit.permissionConfirmed(),
      expect: () => const [VoiceState()],
      verify: (_) {
        expect(microphone.requests, 1);
        expect(microphone.starts, 0);
      },
    );

    blocTest<VoiceCubit, VoiceState>(
      'permissionConfirmed fails when the browser is refused',
      build: () {
        microphone = FakeMicrophone(granted: false, grantOnRequest: false);
        return build();
      },
      seed: () => const VoiceState(status: VoiceStatus.permissionNeeded),
      act: (cubit) => cubit.permissionConfirmed(),
      expect: () => const [_microphoneUnavailable],
    );

    blocTest<VoiceCubit, VoiceState>(
      'permissionDismissed goes back to idle',
      build: build,
      seed: () => const VoiceState(status: VoiceStatus.permissionNeeded),
      act: (cubit) => cubit.permissionDismissed(),
      expect: () => const [VoiceState()],
    );

    blocTest<VoiceCubit, VoiceState>(
      'shows the finished utterances followed by the current one',
      build: build,
      act: (cubit) async {
        await cubit.start();
        client.session
          ..hear("Dinner's")
          ..hear("Dinner's an hour later, ", isFinal: true)
          ..hear('delay the');
        await pumpEventQueue();
      },
      skip: 2,
      expect: () => const [
        VoiceState(status: VoiceStatus.listening, text: "Dinner's"),
        VoiceState(
          status: VoiceStatus.listening,
          text: "Dinner's an hour later,",
        ),
        VoiceState(
          status: VoiceStatus.listening,
          text: "Dinner's an hour later, delay the",
        ),
      ],
    );

    blocTest<VoiceCubit, VoiceState>(
      'finish stops the microphone and ends with the whole command',
      build: build,
      act: (cubit) async {
        await cubit.start();
        client.session.hear('Delay the');
        await pumpEventQueue();

        await cubit.finish();
        await pumpEventQueue();
        expect(client.session.stopped, isTrue);

        client.session
          ..hear('Delay the oven preheat.', isFinal: true)
          ..end();
        await pumpEventQueue();
      },
      skip: 3,
      expect: () => const [
        VoiceState(status: VoiceStatus.finishing, text: 'Delay the'),
        VoiceState(
          status: VoiceStatus.finishing,
          text: 'Delay the oven preheat.',
        ),
        VoiceState(status: VoiceStatus.done, text: 'Delay the oven preheat.'),
      ],
      verify: (_) {
        expect(microphone.isOn, isFalse);
        expect(client.session.closed, isTrue);
      },
    );

    blocTest<VoiceCubit, VoiceState>(
      'goes back to idle when nothing was heard',
      build: build,
      act: (cubit) async {
        await cubit.start();
        client.session
          ..hear('Uh')
          ..end();
        await pumpEventQueue();
      },
      skip: 3,
      expect: () => const [VoiceState()],
      verify: (_) => expect(microphone.isOn, isFalse),
    );

    blocTest<VoiceCubit, VoiceState>(
      'fails and releases everything when the transcription fails',
      build: build,
      act: (cubit) async {
        await cubit.start();
        client.session.fail();
        await pumpEventQueue();
      },
      skip: 2,
      expect: () => const [_transcriptionFailed],
      verify: (_) {
        expect(microphone.isOn, isFalse);
        expect(client.session.closed, isTrue);
      },
    );

    blocTest<VoiceCubit, VoiceState>(
      'fails without touching the microphone when it cannot connect',
      build: () {
        client = FakeTranscriptionClient(failConnect: true);
        return build();
      },
      act: (cubit) => cubit.start(),
      expect: () => const [_connecting, _transcriptionFailed],
      verify: (_) => expect(microphone.starts, 0),
    );

    blocTest<VoiceCubit, VoiceState>(
      'fails and hangs up when the microphone is unavailable',
      build: () {
        microphone = FakeMicrophone(failStart: true);
        return build();
      },
      act: (cubit) => cubit.start(),
      expect: () => const [_connecting, _microphoneUnavailable],
      verify: (_) => expect(client.session.closed, isTrue),
    );

    for (final status in [
      VoiceStatus.permissionNeeded,
      VoiceStatus.connecting,
      VoiceStatus.listening,
      VoiceStatus.finishing,
    ]) {
      blocTest<VoiceCubit, VoiceState>(
        'start does nothing while ${status.name}',
        build: build,
        seed: () => VoiceState(status: status),
        act: (cubit) => cubit.start(),
        expect: () => const <VoiceState>[],
      );
    }

    for (final status in [VoiceStatus.done, VoiceStatus.failure]) {
      blocTest<VoiceCubit, VoiceState>(
        'start listens again after ${status.name}',
        build: build,
        seed: () => VoiceState(status: status),
        act: (cubit) => cubit.start(),
        expect: () => const [_connecting, _listening],
      );
    }

    blocTest<VoiceCubit, VoiceState>(
      'finish does nothing unless listening',
      build: build,
      act: (cubit) => cubit.finish(),
      expect: () => const <VoiceState>[],
    );

    blocTest<VoiceCubit, VoiceState>(
      'cancelling while the permission is checked drops the command',
      build: () {
        microphone = FakeMicrophone(permissionGate: Completer<void>());
        return build();
      },
      act: (cubit) async {
        final started = cubit.start();
        cubit.cancel();
        microphone.permissionGate!.complete();
        await started;
      },
      expect: () => const [_connecting, VoiceState()],
      verify: (_) => expect(client.sessions, isEmpty),
    );

    blocTest<VoiceCubit, VoiceState>(
      'cancelling while connecting drops the command and hangs up',
      build: () {
        client = FakeTranscriptionClient(gate: Completer<void>());
        return build();
      },
      act: (cubit) async {
        final started = cubit.start();
        await pumpEventQueue();
        cubit.cancel();
        client.gate!.complete();
        await started;
      },
      expect: () => const [_connecting, VoiceState()],
      verify: (_) {
        expect(client.session.closed, isTrue);
        expect(microphone.starts, 0);
      },
    );

    blocTest<VoiceCubit, VoiceState>(
      'cancelling while the microphone starts drops the command',
      build: () {
        microphone = FakeMicrophone(startGate: Completer<void>());
        return build();
      },
      act: (cubit) async {
        final started = cubit.start();
        await pumpEventQueue();
        cubit.cancel();
        microphone.startGate!.complete();
        await started;
      },
      expect: () => const [_connecting, VoiceState()],
      verify: (_) {
        expect(client.session.closed, isTrue);
        expect(microphone.isOn, isFalse);
      },
    );

    blocTest<VoiceCubit, VoiceState>(
      'releases the microphone when the session ends while it starts',
      build: () {
        microphone = FakeMicrophone(startGate: Completer<void>());
        return build();
      },
      act: (cubit) async {
        final started = cubit.start();
        await pumpEventQueue();
        client.session.end();
        await pumpEventQueue();
        microphone.startGate!.complete();
        await started;
      },
      expect: () => const [_connecting, VoiceState()],
      verify: (_) {
        expect(microphone.starts, 1);
        expect(microphone.isOn, isFalse);
      },
    );

    test('cancel while listening drops the command and hangs up', () async {
      final cubit = build();
      await cubit.start();
      client.session.hear('Delay the');
      await pumpEventQueue();

      cubit.cancel();

      expect(cubit.state, const VoiceState());
      expect(microphone.isOn, isFalse);
      expect(client.session.closed, isTrue);
    });

    test('cancel after close does nothing', () async {
      final cubit = build();
      await cubit.close();

      cubit.cancel();

      expect(cubit.state, const VoiceState());
    });

    test('a start after a cancel is not cancelled by it', () async {
      final gate = Completer<void>();
      client = FakeTranscriptionClient(gate: gate);
      final cubit = build();
      final first = cubit.start();
      await pumpEventQueue();
      cubit.cancel();
      final second = cubit.start();
      gate.complete();
      await Future.wait([first, second]);

      expect(client.sessions, hasLength(2));
      expect(client.sessions.first.closed, isTrue);
    });

    test('keeps only the last levels, oldest first', () async {
      final cubit = build();
      await cubit.start();

      for (var i = 0; i < VoiceCubit.levelCount + 4; i++) {
        microphone.speak(i.isEven ? [0, 0] : [0, 64]);
        await pumpEventQueue();
      }

      expect(cubit.state.levels, hasLength(VoiceCubit.levelCount));
      expect(cubit.state.levels.last, greaterThan(0));
      expect(cubit.state.levels[cubit.state.levels.length - 2], 0);
    });

    test('ignores audio once it is finishing', () async {
      final cubit = build();
      await cubit.start();
      client.session.hear('Delay');
      await pumpEventQueue();
      // The last chunk arrives after the cubit has started finishing.
      microphone.speak([0, 64]);
      await cubit.finish();
      await pumpEventQueue();

      expect(cubit.state.levels, isEmpty);
    });

    group('ends by itself', () {
      VoiceCubit quick() => VoiceCubit(
        microphone: microphone,
        client: client,
        pause: const Duration(milliseconds: 40),
        silenceTimeout: const Duration(milliseconds: 80),
      );

      Future<void> wait(int milliseconds) =>
          Future<void>.delayed(Duration(milliseconds: milliseconds));

      test('cancels when nothing is said in time', () async {
        final cubit = quick();
        await cubit.start();

        await wait(150);

        expect(cubit.state, const VoiceState());
        expect(microphone.isOn, isFalse);
        expect(client.session.closed, isTrue);
      });

      test('finishes a pause after the last words', () async {
        final cubit = quick();
        await cubit.start();
        client.session.hear('Delay the oven');
        await pumpEventQueue();

        await wait(100);

        expect(cubit.state.status, VoiceStatus.finishing);
        expect(client.session.stopped, isTrue);
      });

      test('keeps listening while the words keep coming', () async {
        final cubit = quick();
        await cubit.start();
        for (final words in ['Delay', 'Delay the', 'Delay the oven']) {
          client.session.hear(words);
          await wait(25);
        }

        expect(cubit.state.status, VoiceStatus.listening);
        expect(cubit.state.text, 'Delay the oven');
      });

      test('does not restart the wait when the words do not change', () async {
        final cubit = quick();
        await cubit.start();
        client.session.hear('Delay');
        await wait(25);
        client.session.hear('Delay');
        await wait(30);

        expect(cubit.state.status, VoiceStatus.finishing);
      });
    });

    group('audioLevel', () {
      test('is silent for no audio', () {
        expect(audioLevel(Uint8List(0)), 0);
        expect(audioLevel(Uint8List(1)), 0);
        expect(audioLevel(Uint8List(8)), 0);
      });

      test('rises with the volume and tops out at 1', () {
        Uint8List samples(int value) {
          final data = ByteData(8);
          for (var i = 0; i < 4; i++) {
            data.setInt16(i * 2, value, Endian.little);
          }
          return data.buffer.asUint8List();
        }

        expect(audioLevel(samples(2000)), lessThan(audioLevel(samples(8000))));
        expect(audioLevel(samples(-32768)), 1);
      });
    });

    test('close releases the microphone and hangs up', () async {
      final cubit = build();
      await cubit.start();

      await cubit.close();

      expect(microphone.isOn, isFalse);
      expect(client.session.closed, isTrue);
    });

    test('finish after close does nothing', () async {
      final cubit = build();
      await cubit.start();
      await cubit.close();

      await cubit.finish();

      expect(cubit.state, _listening);
    });

    test('close while checking the permission starts nothing', () async {
      final gate = Completer<void>();
      microphone = FakeMicrophone(permissionGate: gate);
      final cubit = build();
      final started = cubit.start();

      await cubit.close();
      gate.complete();
      await started;

      expect(client.sessions, isEmpty);
    });

    test('close while asking the browser emits nothing', () async {
      final gate = Completer<void>();
      microphone = FakeMicrophone(granted: false, requestGate: gate);
      final cubit = build();
      final confirmed = cubit.permissionConfirmed();

      await cubit.close();
      gate.complete();
      await confirmed;

      expect(cubit.state, const VoiceState());
    });

    test('close while connecting hangs up once connected', () async {
      final gate = Completer<void>();
      client = FakeTranscriptionClient(gate: gate);
      final cubit = build();
      final started = cubit.start();
      await pumpEventQueue();

      await cubit.close();
      gate.complete();
      await started;

      expect(client.session.closed, isTrue);
      expect(microphone.starts, 0);
    });

    test('close while the microphone starts releases it', () async {
      final gate = Completer<void>();
      microphone = FakeMicrophone(startGate: gate);
      final cubit = build();
      final started = cubit.start();
      await pumpEventQueue();

      await cubit.close();
      gate.complete();
      await started;

      expect(client.session.closed, isTrue);
      expect(microphone.isOn, isFalse);
    });
  });
}
