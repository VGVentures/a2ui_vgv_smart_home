import 'package:home_backend/transcribe/transcription_session.dart';
import 'package:test/test.dart';

void main() {
  group('Transcript', () {
    test('compares by text and finality', () {
      expect(
        const Transcript('a', isFinal: true),
        const Transcript('a', isFinal: true),
      );
      expect(
        const Transcript('a', isFinal: true).hashCode,
        const Transcript('a', isFinal: true).hashCode,
      );
      expect(
        const Transcript('a', isFinal: true),
        isNot(const Transcript('a', isFinal: false)),
      );
    });

    test('describes itself', () {
      expect(
        const Transcript('Dinner', isFinal: false).toString(),
        'Transcript(Dinner, isFinal: false)',
      );
    });
  });

  test('TranscriptionException describes itself', () {
    expect(
      TranscriptionException('boom').toString(),
      'TranscriptionException: boom',
    );
  });
}
