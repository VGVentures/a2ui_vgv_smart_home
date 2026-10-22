import 'package:home_backend/live/live_hub.dart';
import 'package:test/test.dart';

void main() {
  group('LiveHub', () {
    test('sends a published frame to every listener', () {
      final hub = LiveHub();
      final first = <Map<String, Object?>>[];
      final second = <Map<String, Object?>>[];
      hub
        ..listen(first.add)
        ..listen(second.add)
        ..publish({'type': 'clock'});

      expect(first, [
        {'type': 'clock'},
      ]);
      expect(second, first);
      expect(hub.listenerCount, 2);
    });

    test('stops sending to a listener that stopped', () {
      final hub = LiveHub();
      final frames = <Map<String, Object?>>[];
      final stop = hub.listen(frames.add);

      stop();
      hub.publish({'type': 'clock'});

      expect(frames, isEmpty);
      expect(hub.listenerCount, 0);
    });

    test('drops a listener that throws and still reaches the others', () {
      final hub = LiveHub();
      final frames = <Map<String, Object?>>[];
      hub
        ..listen((_) => throw StateError('closed'))
        ..listen(frames.add)
        ..publish({'type': 'clock'});

      expect(frames, hasLength(1));
      expect(hub.listenerCount, 1);
    });
  });
}
