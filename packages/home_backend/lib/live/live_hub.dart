/// {@template live_hub}
/// Where the server pushes what changes to everyone listening on `/live`.
/// {@endtemplate}
///
/// A frame is a JSON object with a `type`. The hub knows nothing about their
/// shapes: whoever changes something publishes it, and each connection sends
/// what it gets. See `LiveSession` for the protocol.
class LiveHub {
  final _listeners = <void Function(Map<String, Object?>)>{};

  /// How many connections are listening.
  int get listenerCount => _listeners.length;

  /// Starts sending every published frame to [listener]. Returns the function
  /// that stops it.
  void Function() listen(void Function(Map<String, Object?>) listener) {
    _listeners.add(listener);
    return () => _listeners.remove(listener);
  }

  /// Sends [frame] to every listener. A listener that throws (a socket that
  /// closed under it) never keeps the others from getting it.
  void publish(Map<String, Object?> frame) {
    for (final listener in [..._listeners]) {
      try {
        listener(frame);
      } on Object {
        _listeners.remove(listener);
      }
    }
  }
}
