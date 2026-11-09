import 'dart:async';

import 'package:app_ui/app_ui.dart';
import 'package:flutter/widgets.dart';
import 'package:home_catalog/home_catalog.dart' show HomeActions;
import 'package:home_frontend/src/a2ui/a2ui.dart';

/// The string at [key], or null when it is missing or not a string.
String? string(Map<String, Object?> map, String key) {
  final value = map[key];
  return value is String ? value : null;
}

/// The maps in the list at [key].
Iterable<Map<String, Object?>> maps(Map<String, Object?> map, String key) {
  final value = map[key];
  if (value is! List) return const [];
  return value.whereType<Map<String, Object?>>();
}

/// The longest `progressLabel` the snackbar is meant to show.
const maxProgressLabel = 40;

/// The A2UI action named [name], labelled [progressLabel] (trimmed to
/// [maxProgressLabel] characters), carrying [context].
///
/// Code writes every action a control raises, so the backend never depends on
/// how the model spelled an event name or a context key.
Map<String, Object?> homeAction(
  String name,
  String progressLabel,
  Map<String, Object?> context,
) {
  final trimmed = progressLabel.trim();
  final label = trimmed.length <= maxProgressLabel
      ? trimmed
      : trimmed.substring(0, maxProgressLabel).trim();
  return {
    'event': {
      'name': name,
      'context': {'progressLabel': label, ...context},
    },
  };
}

/// Props with every binding replaced by the value it holds, however deep.
///
/// The renderer hands a builder its props with each data-bound value wrapped in
/// a `ResolvedBinding`, and an action as a callback. A builder that only reads
/// them takes this plain copy and works the same for a literal and a bound
/// prop. Action closures pass through untouched.
Map<String, Object?> plainProps(Map<String, Object?> props) =>
    plain(props)! as Map<String, Object?>;

/// [value] with every `ResolvedBinding` in it replaced by what it holds.
Object? plain(Object? value) => switch (ComponentProps.unwrap(value)) {
  final Map<Object?, Object?> map => <String, Object?>{
    for (final entry in map.entries) '${entry.key}': plain(entry.value),
  },
  final List<Object?> list => [for (final item in list) plain(item)],
  final other => other,
};

/// A press handler that dispatches [action] from [node], or null when there is
/// none.
VoidCallback? onPressed(
  BuildContext context,
  ComponentNode<ComponentImplementation> node,
  Map<String, Object?>? action,
) {
  if (action == null) return null;
  final surface = A2uiSurface.of(context);
  return () => unawaited(dispatch(surface, node, action));
}

/// Raises an A2UI event [action] from [node] on [surface].
///
/// The surface reports it as an `A2uiRendererAction`, which the agent turns
/// into a request. The event's context holds literals only, so nothing is
/// resolved against the data model first.
Future<void> dispatch(
  SurfaceModel<ComponentImplementation> surface,
  ComponentNode<ComponentImplementation> node,
  Map<String, Object?> action,
) => surface.dispatchAction(action, node.componentId);

/// {@template optimistic_writes}
/// Remembers what optimistic writes replaced, so a failed turn can undo them.
///
/// [write] stores the value a binding held before the first write since the
/// last settle; [revert] puts those values back. A host calls [sync] when its
/// dependencies change, which reverts as soon as the nearest [OptimisticScope]
/// bumps its revision.
/// {@endtemplate}
class OptimisticWrites {
  final Map<String, ({Object? value, WritableBinding<Object?> binding})>
  _previous = {};
  int? _revision;

  /// Writes [value] through [binding], keeping the old value for [revert].
  /// Does nothing for a literal, which has no binding.
  void write(WritableBinding<Object?>? binding, Object? value) {
    if (binding == null) return;
    _previous.putIfAbsent(
      binding.path,
      () => (value: binding.value, binding: binding),
    );
    binding.set(value);
  }

  /// Restores every value [write] replaced.
  void revert() {
    for (final entry in _previous.values) {
      entry.binding.set(entry.value);
    }
    _previous.clear();
  }

  /// Reverts when the nearest scope's revision changed since the last call.
  ///
  /// Called while building, where writing to the data model would rebuild the
  /// widgets that are building, so the revert runs after the frame.
  void sync(BuildContext context) {
    final revision = OptimisticScope.of(context);
    if (_revision != null && _revision != revision) {
      WidgetsBinding.instance.addPostFrameCallback((_) => revert());
    }
    _revision = revision;
  }
}

/// {@template optimistic_writes_host}
/// Owns an [OptimisticWrites] for its subtree and reverts it on a failed turn.
/// {@endtemplate}
class OptimisticWritesHost extends StatefulWidget {
  /// {@macro optimistic_writes_host}
  const OptimisticWritesHost({required this.builder, super.key});

  /// Builds the subtree that writes through the given [OptimisticWrites].
  final Widget Function(BuildContext context, OptimisticWrites writes) builder;

  @override
  State<OptimisticWritesHost> createState() => _OptimisticWritesHostState();
}

/// Holds the [OptimisticWrites] of its builder and syncs them as its
/// dependencies change.
class _OptimisticWritesHostState extends State<OptimisticWritesHost> {
  final _writes = OptimisticWrites();

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _writes.sync(context);
  }

  @override
  Widget build(BuildContext context) => widget.builder(context, _writes);
}

/// The A2UI action for a chip or alert button's typed [spec] (see
/// `HomeActions.spec`), labelled [label], or null when the spec names nothing.
///
/// The model chose only a target; the event's name and context are written
/// here, so what reaches the backend never depends on how the model spelled
/// them. [label] is the visible text, and is the snackbar's `progressLabel`.
Map<String, Object?>? actionFromSpec(Object? spec, String label) {
  if (spec is! Map) return null;
  Map<String, Object?> event(String name, Map<String, Object?> context) => {
    'event': {
      'name': name,
      'context': {'progressLabel': label, ...context},
    },
  };

  final command = spec['command'];
  if (command is Map &&
      command['deviceId'] is String &&
      command['command'] is String) {
    return event(HomeActions.runDeviceAction, {
      'deviceId': command['deviceId'],
      'command': command['command'],
    });
  }
  final scene = spec['scene'];
  if (scene is String && scene.isNotEmpty) {
    return event(HomeActions.runScene, {'sceneId': scene});
  }
  if (spec['undo'] == true) return event(HomeActions.undoChange, const {});
  final ask = spec['ask'];
  if (ask is String && ask.trim().isNotEmpty) {
    return event(HomeActions.ask, {'text': ask.trim()});
  }
  return null;
}
