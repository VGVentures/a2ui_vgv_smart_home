import 'package:flutter/widgets.dart';

/// {@template optimistic_scope}
/// Tells controls that flip optimistically when to take the flip back.
///
/// A switch, stepper or checkbox shows the value the user asked for the moment
/// they tap, before the backend answers. If the turn then fails, the app bumps
/// [revision] and every such control below this scope drops its local value and
/// shows what the surface says again. Without a scope the revision stays 0 and
/// controls never reset on their own.
/// {@endtemplate}
class OptimisticScope extends InheritedWidget {
  /// {@macro optimistic_scope}
  const OptimisticScope({
    required this.revision,
    required super.child,
    super.key,
  });

  /// A counter that grows each time an optimistic flip must be reverted.
  final int revision;

  /// The nearest scope's revision, registering [context] to rebuild when it
  /// changes. 0 when there is no scope.
  static int of(BuildContext context) {
    return context
            .dependOnInheritedWidgetOfExactType<OptimisticScope>()
            ?.revision ??
        0;
  }

  @override
  bool updateShouldNotify(OptimisticScope oldWidget) =>
      revision != oldWidget.revision;
}
