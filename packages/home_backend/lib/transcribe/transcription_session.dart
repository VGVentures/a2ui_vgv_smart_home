import 'package:meta/meta.dart';

/// {@template transcript}
/// Text a speech-to-text provider heard.
/// {@endtemplate}
@immutable
class Transcript {
  /// {@macro transcript}
  const Transcript(this.text, {required this.isFinal});

  /// What the provider heard so far.
  final String text;

  /// Whether the provider has finished this utterance. An interim transcript
  /// can still change. A final one will not.
  final bool isFinal;

  @override
  bool operator ==(Object other) =>
      other is Transcript && other.text == text && other.isFinal == isFinal;

  @override
  int get hashCode => Object.hash(text, isFinal);

  @override
  String toString() => 'Transcript($text, isFinal: $isFinal)';
}

/// {@template transcription_exception}
/// Thrown when a speech-to-text provider fails.
/// {@endtemplate}
class TranscriptionException implements Exception {
  /// {@macro transcription_exception}
  ///
  /// Creates a [TranscriptionException] with a human-readable [message].
  TranscriptionException(this.message);

  /// What went wrong. Logged, never sent to clients.
  final String message;

  @override
  String toString() => 'TranscriptionException: $message';
}

/// {@template transcription_session}
/// One live session with a speech-to-text provider.
/// {@endtemplate}
///
/// The session starts connecting as soon as it is created. Audio is raw 16 kHz
/// mono 16-bit little-endian PCM.
abstract interface class TranscriptionSession {
  /// Completes once the provider accepts audio. Completes with a
  /// [TranscriptionException] when the provider can't be reached or rejects
  /// the session.
  Future<void> get ready;

  /// Transcripts as the provider produces them. Emits a
  /// [TranscriptionException] if the provider fails after [ready], and closes
  /// when the provider ends the session.
  Stream<Transcript> get transcripts;

  /// Sends a chunk of audio. Only valid after [ready] completes.
  void sendAudio(List<int> pcm);

  /// Tells the provider no more audio is coming. Completes once the provider
  /// has sent its last transcript for that audio.
  Future<void> finish();

  /// Closes the session and releases the connection.
  Future<void> close();
}
