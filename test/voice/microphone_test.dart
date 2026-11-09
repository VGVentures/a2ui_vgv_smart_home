import 'dart:typed_data';

import 'package:a2ui_vgv_smart_home/voice/microphone.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:record/record.dart';

class _MockAudioRecorder extends Mock implements AudioRecorder {}

void main() {
  group('RecordMicrophone', () {
    late AudioRecorder recorder;
    late Microphone microphone;

    setUpAll(() => registerFallbackValue(const RecordConfig()));

    setUp(() {
      recorder = _MockAudioRecorder();
      microphone = RecordMicrophone(recorder);
    });

    test('checks the permission without prompting', () async {
      when(
        () => recorder.hasPermission(request: false),
      ).thenAnswer((_) async => true);

      expect(await microphone.isGranted(), isTrue);
    });

    test('asks the browser when requesting the permission', () async {
      when(() => recorder.hasPermission()).thenAnswer((_) async => false);

      expect(await microphone.requestPermission(), isFalse);
    });

    test('remembers a grant from the request', () async {
      when(() => recorder.hasPermission()).thenAnswer((_) async => true);
      await microphone.requestPermission();

      expect(await microphone.isGranted(), isTrue);
      verifyNever(() => recorder.hasPermission(request: false));
    });

    test('streams 16 kHz mono 16-bit PCM', () async {
      final audio = Stream<Uint8List>.value(Uint8List(2));
      when(() => recorder.startStream(any())).thenAnswer((_) async => audio);

      expect(await microphone.start(), audio);
      final config =
          verify(() => recorder.startStream(captureAny())).captured.single
              as RecordConfig;
      expect(config.encoder, AudioEncoder.pcm16bits);
      expect(config.sampleRate, 16000);
      expect(config.numChannels, 1);
    });

    test('stops the recorder', () async {
      when(recorder.stop).thenAnswer((_) async => null);

      await microphone.stop();

      verify(recorder.stop).called(1);
    });
  });
}
