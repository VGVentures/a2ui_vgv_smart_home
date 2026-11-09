import 'dart:async';

/// {@template turn_queue}
/// Orders the turns of one dashboard, standing in for the ordered agent stream
/// A2UI 1.0 expects from its transport.
///
/// Two kinds of turn compete for the same surface:
///
/// - an *interaction* is something the person did (a press, typed or spoken
///   text). Interactions run one at a time, in the order they were asked.
/// - a *refresh* is the app noticing that data changed behind the person's
///   back. It is answered from fresh data, so it only matters when nothing the
///   person did is running or waiting.
///
/// The rules are what keeps the screen from changing twice:
///
/// - A refresh asked while an interaction runs or waits is dropped. That turn
///   reads fresh data itself, and the change that triggered the refresh is
///   most often the interaction's own doing.
/// - A refresh that is already asking is not stacked. One more is folded in
///   behind it, however many triggers arrive, unless an interaction was asked
///   meanwhile: that turn answers them.
/// - A refresh whose interaction started after it did is stale: its `work` is
///   told through `isCurrent` and must not apply its reply.
///
/// Replace this class with the official A2UI transport when it lands. Nothing
/// outside `HttpGenUIAgent` depends on it.
/// {@endtemplate}
class TurnQueue {
  Future<void> _tail = Future.value();
  var _interactions = 0;
  var _epoch = 0;
  var _refreshing = false;
  var _again = false;

  /// Runs [work] after every earlier interaction has finished.
  ///
  /// A failure reaches the caller and does not stop the turns behind it.
  Future<T> interaction<T>(Future<T> Function() work) {
    _epoch++;
    _interactions++;
    final result = _tail.then((_) => work());
    _tail = result.then<void>((_) {}, onError: (Object _) {}).whenComplete(() {
      _interactions--;
    });
    return result;
  }

  /// Runs [work] unless an interaction is running or waiting.
  ///
  /// [work] gets `isCurrent`, which turns false the moment an interaction is
  /// asked. It checks it right before applying what it fetched. While it runs,
  /// more calls collapse into one rerun after it.
  Future<void> refresh(
    Future<void> Function(bool Function() isCurrent) work,
  ) async {
    if (_interactions > 0) return;
    if (_refreshing) {
      _again = true;
      return;
    }
    _refreshing = true;
    try {
      bool again;
      do {
        _again = false;
        final epoch = _epoch;
        await work(() => epoch == _epoch);
        // An interaction since then read fresh data too, so the triggers that
        // were folded in are answered already.
        again = _again && epoch == _epoch;
      } while (again);
    } finally {
      _refreshing = false;
    }
  }
}
