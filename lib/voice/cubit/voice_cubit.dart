import 'dart:async';
import 'dart:math' as math;
import 'dart:typed_data';

import 'package:a2ui_vgv_smart_home/voice/microphone.dart';
import 'package:a2ui_vgv_smart_home/voice/transcription_client.dart';
import 'package:bloc/bloc.dart';
import 'package:equatable/equatable.dart';

/// {@template voice_status}
/// The stages of a spoken command, from idle to done or failed.
/// {@endtemplate}
enum VoiceStatus {
  /// Nothing is being said.
  idle,

  /// The microphone isn't granted yet. The view explains the browser's prompt
  /// before anything asks for it, and stays here until the user answers it.
  permissionNeeded,

  /// Opening the transcription socket and the microphone.
  connecting,

  /// The microphone is open and the words are being transcribed.
  listening,

  /// The user stopped talking and the last transcript is on its way.
  finishing,

  /// [VoiceState.text] holds the whole command.
  done,

  /// The command failed, see [VoiceState.failure].
  failure,
}

/// {@template voice_failure}
/// Why voice input failed.
/// {@endtemplate}
enum VoiceFailure {
  /// The microphone was denied or could not be opened.
  microphoneUnavailable,

  /// The backend could not turn the audio into text.
  transcriptionFailed,
}

/// {@template voice_state}
/// What voice input shows: its status, the text heard so far, the failure if
/// there is one, and the microphone levels.
/// {@endtemplate}
class VoiceState extends Equatable {
  /// {@macro voice_state}
  const VoiceState({
    this.status = VoiceStatus.idle,
    this.text = '',
    this.failure,
    this.levels = const [],
  });

  /// Where the spoken command stands.
  final VoiceStatus status;

  /// What was heard so far, or the whole command once [VoiceStatus.done].
  final String text;

  /// Why the last command failed. Set only with [VoiceStatus.failure].
  final VoiceFailure? failure;

  /// How loud the last [VoiceCubit.levelCount] chunks of audio were, from 0 to
  /// 1, oldest first. Fills up while listening, then rolls.
  final List<double> levels;

  @override
  List<Object?> get props => [status, text, failure, levels];
}

/// {@template voice_cubit}
/// Turns a tap on the microphone button into a spoken command.
///
/// [start] opens a [TranscriptionSession], streams the [Microphone] into it,
/// and collects what comes back. The command ends by itself: two seconds after
/// the last words, or ten seconds after the start if nothing was said, which
/// drops it. [finish] ends it early and sends what was heard, and [cancel]
/// drops it. The session ends once the backend has sent the last transcript.
/// {@endtemplate}
class VoiceCubit extends Cubit<VoiceState> {
  /// {@macro voice_cubit}
  VoiceCubit({
    required this._microphone,
    required this._client,
    this._pause = const Duration(seconds: 2),
    this._silenceTimeout = const Duration(seconds: 10),
  }) : super(const VoiceState());

  /// How many levels [VoiceState.levels] keeps.
  static const levelCount = 30;

  /// How long after the last words the command is considered finished.
  final Duration _pause;

  /// How long to wait for the first words before giving up.
  final Duration _silenceTimeout;

  final Microphone _microphone;
  final TranscriptionClient _client;

  TranscriptionSession? _session;
  StreamSubscription<Transcript>? _transcripts;
  StreamSubscription<Uint8List>? _audio;
  Timer? _quiet;
  final _finals = <String>[];
  String _interim = '';

  /// Bumped by every [cancel], so a [start] still awaiting can tell it was.
  int _run = 0;

  /// The microphone button was tapped.
  Future<void> start() async {
    if (state.status
        case VoiceStatus.permissionNeeded ||
            VoiceStatus.connecting ||
            VoiceStatus.listening ||
            VoiceStatus.finishing) {
      return;
    }
    final run = _run;
    // Connecting already, so a second tap while the permission is checked
    // does nothing.
    emit(const VoiceState(status: VoiceStatus.connecting));
    final granted = await _microphone.isGranted();
    if (isClosed) return;
    if (!granted) {
      emit(const VoiceState(status: VoiceStatus.permissionNeeded));
      return;
    }
    if (!_stillWanted(run)) return;

    _finals.clear();
    _interim = '';
    final TranscriptionSession session;
    try {
      session = await _client.connect();
    } on Object {
      _fail(VoiceFailure.transcriptionFailed);
      return;
    }
    _session = session;
    _transcripts = session.transcripts.listen(
      _onTranscript,
      onError: (Object _) => _fail(VoiceFailure.transcriptionFailed),
      onDone: _onDone,
    );
    if (!_stillWanted(run)) return;

    final Stream<Uint8List> audio;
    try {
      audio = await _microphone.start();
    } on Object {
      _fail(VoiceFailure.microphoneUnavailable);
      return;
    }
    // The session ended, it was cancelled, or the cubit closed meanwhile.
    if (_session != session || !_stillWanted(run)) {
      unawaited(_microphone.stop());
      return;
    }
    _audio = audio.listen(
      (chunk) {
        session.sendAudio(chunk);
        _onAudio(chunk);
      },
      onDone: session.stop,
    );
    emit(const VoiceState(status: VoiceStatus.listening));
    _waitForWords();
  }

  /// The user is done talking. Sends what was heard, if anything.
  Future<void> finish() async {
    _quiet?.cancel();
    if (isClosed || state.status != VoiceStatus.listening) return;
    emit(
      VoiceState(
        status: VoiceStatus.finishing,
        text: state.text,
        levels: state.levels,
      ),
    );
    // The audio stream closes after its last chunk, which sends `stop`.
    await _microphone.stop();
  }

  /// The user backed out. Nothing is sent.
  void cancel() {
    _run++;
    if (isClosed) return;
    _teardown();
    emit(const VoiceState());
  }

  /// The user read why the browser is about to ask and wants to go on. Asks,
  /// then waits for the next tap.
  Future<void> permissionConfirmed() async {
    final granted = await _microphone.requestPermission();
    if (isClosed) return;
    emit(
      granted
          ? const VoiceState()
          : const VoiceState(
              status: VoiceStatus.failure,
              failure: VoiceFailure.microphoneUnavailable,
            ),
    );
  }

  /// The user backed out before the browser asked.
  void permissionDismissed() => emit(const VoiceState());

  /// Whether [start] should go on after an await. Drops the command when it
  /// was cancelled or the cubit closed in the meantime.
  bool _stillWanted(int run) {
    if (run == _run && !isClosed) return true;
    _teardown();
    if (!isClosed) emit(const VoiceState());
    return false;
  }

  void _onTranscript(Transcript transcript) {
    if (transcript.isFinal) {
      _finals.add(transcript.text);
      _interim = '';
    } else {
      _interim = transcript.text;
    }
    final text = _join([..._finals, _interim]);
    final heard = text != state.text;
    emit(
      VoiceState(status: state.status, text: text, levels: state.levels),
    );
    if (heard && state.status == VoiceStatus.listening) _waitForWords();
  }

  void _onAudio(Uint8List chunk) {
    if (state.status != VoiceStatus.listening) return;
    final levels = state.levels;
    emit(
      VoiceState(
        status: VoiceStatus.listening,
        text: state.text,
        levels: [
          ...levels.skip(math.max(0, levels.length - levelCount + 1)),
          audioLevel(chunk),
        ],
      ),
    );
  }

  /// Ends the command if nothing new is heard in time: [finish] if there are
  /// words, [cancel] if there are none.
  void _waitForWords() {
    _quiet?.cancel();
    _quiet = Timer(state.text.isEmpty ? _silenceTimeout : _pause, () {
      if (state.text.isEmpty) {
        cancel();
      } else {
        unawaited(finish());
      }
    });
  }

  void _onDone() {
    final command = _join(_finals);
    _teardown();
    emit(
      command.isEmpty
          ? const VoiceState()
          : VoiceState(status: VoiceStatus.done, text: command),
    );
  }

  void _fail(VoiceFailure failure) {
    _teardown();
    if (isClosed) return;
    emit(VoiceState(status: VoiceStatus.failure, failure: failure));
  }

  void _teardown() {
    _quiet?.cancel();
    unawaited(_transcripts?.cancel());
    if (_audio != null) unawaited(_microphone.stop());
    unawaited(_audio?.cancel());
    _session?.close();
    _transcripts = null;
    _audio = null;
    _session = null;
  }

  static String _join(Iterable<String> parts) => parts
      .map((part) => part.trim())
      .where((part) => part.isNotEmpty)
      .join(' ');

  @override
  Future<void> close() {
    _teardown();
    return super.close();
  }
}

/// How loud 16-bit little-endian PCM [chunk] is, from 0 to 1.
///
/// The root mean square, lifted with a square root because speech sits low on
/// the scale, so quiet voices still move the bars.
double audioLevel(Uint8List chunk) {
  final samples = chunk.lengthInBytes ~/ 2;
  if (samples == 0) return 0;
  final data = ByteData.sublistView(chunk);
  var sum = 0.0;
  for (var i = 0; i < samples; i++) {
    final sample = data.getInt16(i * 2, Endian.little) / 32768;
    sum += sample * sample;
  }
  return math.min(1, math.sqrt(math.sqrt(sum / samples)) * 1.6);
}
