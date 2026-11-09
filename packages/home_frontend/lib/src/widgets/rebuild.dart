import 'package:flutter/scheduler.dart';
import 'package:flutter/widgets.dart';

/// Rebuilds [state] now, or after the frame when a frame is being built.
///
/// A signal or an event can fire while the tree is building, where `setState`
/// is an error.
void rebuild(State<StatefulWidget> state) {
  if (!state.mounted) return;
  final scheduler = SchedulerBinding.instance;
  if (scheduler.schedulerPhase == SchedulerPhase.persistentCallbacks) {
    scheduler.addPostFrameCallback((_) {
      // ignore: invalid_use_of_protected_member, rebuilding is the point.
      if (state.mounted) state.setState(() {});
    });
  } else {
    // ignore: invalid_use_of_protected_member, rebuilding is the point.
    state.setState(() {});
  }
}
