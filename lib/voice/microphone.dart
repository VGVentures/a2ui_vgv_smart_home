import 'dart:typed_data';

import 'package:record/record.dart';

/// {@template microphone}
/// Captures what the panel's microphone hears.
///
/// A seam so tests can run without a browser.
/// {@endtemplate}
abstract interface class Microphone {
  /// Whether the user already let the page use the microphone. Never shows
  /// the browser's permission prompt.
  Future<bool> isGranted();

  /// Shows the browser's permission prompt if the user hasn't answered it
  /// yet. Returns whether the page may use the microphone.
  Future<bool> requestPermission();

  /// Starts capturing raw 16 kHz mono 16-bit little-endian PCM, the format
  /// `/transcribe` expects. Throws if the microphone can't be used.
  ///
  /// The stream closes once [stop] has delivered the last chunk.
  Future<Stream<Uint8List>> start();

  /// Stops capturing and releases the microphone.
  Future<void> stop();
}

/// {@template record_microphone}
/// A [Microphone] on `package:record`, which resamples the browser's audio to
/// the rate [start] asks for.
/// {@endtemplate}
class RecordMicrophone implements Microphone {
  /// {@macro record_microphone}
  RecordMicrophone(this._recorder);

  final AudioRecorder _recorder;

  /// A grant from [requestPermission] counts even if the browser's permission
  /// query doesn't report it, so the user is never asked twice in one visit.
  bool _granted = false;

  @override
  Future<bool> isGranted() async =>
      _granted || await _recorder.hasPermission(request: false);

  @override
  Future<bool> requestPermission() async =>
      _granted = await _recorder.hasPermission();

  @override
  Future<Stream<Uint8List>> start() => _recorder.startStream(
    const RecordConfig(
      encoder: AudioEncoder.pcm16bits,
      sampleRate: 16000,
      numChannels: 1,
    ),
  );

  @override
  Future<void> stop() => _recorder.stop();
}
