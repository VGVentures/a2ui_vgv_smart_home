import 'dart:async';
import 'dart:typed_data';

import 'package:a2ui_vgv_smart_home/voice/microphone.dart';
import 'package:a2ui_vgv_smart_home/voice/transcription_client.dart';

class FakeMicrophone implements Microphone {
  FakeMicrophone({
    this.granted = true,
    this.grantOnRequest = true,
    this.failStart = false,
    this.permissionGate,
    this.requestGate,
    this.startGate,
  });

  bool granted;

  /// What the user answers the browser's prompt.
  final bool grantOnRequest;
  final bool failStart;

  /// Holds [isGranted] open until completed.
  final Completer<void>? permissionGate;

  /// Holds [requestPermission] open until completed.
  final Completer<void>? requestGate;

  /// Holds [start] open until completed.
  final Completer<void>? startGate;

  int requests = 0;
  int starts = 0;
  int stops = 0;
  StreamController<Uint8List>? _audio;

  bool get isOn => _audio != null;

  void speak(List<int> chunk) => _audio!.add(Uint8List.fromList(chunk));

  @override
  Future<bool> isGranted() async {
    await permissionGate?.future;
    return granted;
  }

  @override
  Future<bool> requestPermission() async {
    requests++;
    await requestGate?.future;
    return granted = grantOnRequest;
  }

  @override
  Future<Stream<Uint8List>> start() async {
    starts++;
    await startGate?.future;
    if (failStart) throw Exception('NotAllowedError');
    granted = true;
    return (_audio = StreamController<Uint8List>()).stream;
  }

  @override
  Future<void> stop() async {
    stops++;
    final audio = _audio;
    _audio = null;
    // Not awaited: an unlistened controller never completes its close.
    unawaited(audio?.close());
  }
}

class FakeTranscriptionSession implements TranscriptionSession {
  final _transcripts = StreamController<Transcript>();
  final audio = <List<int>>[];
  bool stopped = false;
  bool closed = false;

  @override
  Stream<Transcript> get transcripts => _transcripts.stream;

  @override
  void sendAudio(List<int> pcm) => audio.add(pcm);

  @override
  void stop() => stopped = true;

  @override
  void close() => closed = true;

  void hear(String text, {bool isFinal = false}) =>
      _transcripts.add(Transcript(text, isFinal: isFinal));

  void fail() => _transcripts.addError(const TranscriptionFailed('boom'));

  void end() => unawaited(_transcripts.close());
}

class FakeTranscriptionClient implements TranscriptionClient {
  FakeTranscriptionClient({this.failConnect = false, this.gate});

  final bool failConnect;

  /// Holds [connect] open until completed.
  final Completer<void>? gate;
  final sessions = <FakeTranscriptionSession>[];

  FakeTranscriptionSession get session => sessions.last;

  @override
  Future<TranscriptionSession> connect() async {
    await gate?.future;
    if (failConnect) throw const TranscriptionFailed('No Gemini API key.');
    final session = FakeTranscriptionSession();
    sessions.add(session);
    return session;
  }
}
