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

/// A press handler that dispatches [action], or null when there is none.
VoidCallback? onPressed(
  CatalogItemContext context,
  Map<String, Object?>? action,
) {
  if (action == null) return null;
  return () => unawaited(dispatch(context, action));
}

/// Runs an A2UI action: a server event goes back as a [UserActionEvent], a
/// client function call is resolved against the data model.
Future<void> dispatch(
  CatalogItemContext context,
  Map<String, Object?> action,
) async {
  final event = action['event'];
  if (event is Map<String, Object?>) {
    final name = event['name'];
    if (name is! String) return;
    final contextDefinition = event['context'];
    final resolved = await resolveContext(
      context.dataContext,
      contextDefinition is Map<String, Object?> ? contextDefinition : null,
    );
    context.dispatchEvent(
      UserActionEvent(
        name: name,
        sourceComponentId: context.id,
        context: resolved,
      ),
    );
    return;
  }
  final call = action['functionCall'];
  if (call is Map<String, Object?>) {
    try {
      await context.dataContext.resolve(call).first;
    } on Object catch (error, stack) {
      context.reportError(error, stack);
    }
  }
}

/// The data-model path a bound prop points at, or null for a literal.
String? boundPath(Object? value) {
  if (value is Map && value.length == 1 && value['path'] is String) {
    return value['path']! as String;
  }
  return null;
}

/// Writes [value] to the data-model path [reference] points at.
///
/// Does nothing when [reference] is a literal. This is the optimistic half of
/// a switch, stepper or checkbox: the server confirms by writing the real
/// value back to the same path.
void writeBound(CatalogItemContext context, Object? reference, Object? value) {
  final path = boundPath(reference);
  if (path == null) return;
  context.dataContext.update(DataPath(path), value);
}

/// {@template optimistic_writes}
/// Remembers what optimistic writes replaced, so a failed turn can undo them.
///
/// [write] stores the value a path held before the first write since the last
/// settle; [revert] puts those values back. A host calls [sync] when its
/// dependencies change, which reverts as soon as the nearest [OptimisticScope]
/// bumps its revision.
/// {@endtemplate}
class OptimisticWrites {
  final Map<String, Object?> _previous = {};
  int? _revision;

  /// Writes [value] where [reference] points, keeping the old value for
  /// [revert]. Does nothing for a literal.
  void write(CatalogItemContext context, Object? reference, Object? value) {
    final path = boundPath(reference);
    if (path == null) return;
    _previous.putIfAbsent(
      path,
      () => context.dataContext.getValue<Object?>(DataPath(path)),
    );
    context.dataContext.update(DataPath(path), value);
  }

  /// Restores every value [write] replaced.
  void revert(DataContext dataContext) {
    for (final entry in _previous.entries) {
      dataContext.update(DataPath(entry.key), entry.value);
    }
    _previous.clear();
  }

  /// Reverts when the nearest scope's revision changed since the last call.
  ///
  /// Called while building, where writing to the data model would rebuild the
  /// widgets that are building, so the revert runs after the frame.
  void sync(BuildContext context, DataContext dataContext) {
    final revision = OptimisticScope.of(context);
    if (_revision != null && _revision != revision) {
      WidgetsBinding.instance.addPostFrameCallback((_) => revert(dataContext));
    }
    _revision = revision;
  }
}

/// {@template optimistic_writes_host}
/// Owns an [OptimisticWrites] for its subtree and reverts it on a failed turn.
/// {@endtemplate}
class OptimisticWritesHost extends StatefulWidget {
  /// {@macro optimistic_writes_host}
  const OptimisticWritesHost({
    required this.dataContext,
    required this.builder,
    super.key,
  });

  /// Where the reverted values are written back.
  final DataContext dataContext;

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
    _writes.sync(context, widget.dataContext);
  }

  @override
  Widget build(BuildContext context) => widget.builder(context, _writes);
}

/// {@template bound_props}
/// Resolves the data-bound props of a component and rebuilds when they change.
///
/// Walks [data] and replaces every `{"path": ...}` reference with the value at
/// that path. Anything under an `action` key is left alone: an action's
/// references are resolved at dispatch time. Literals pass through untouched,
/// so one builder serves both literal and bound props.
/// {@endtemplate}
class BoundProps extends StatefulWidget {
  /// {@macro bound_props}
  const BoundProps({
    required this.dataContext,
    required this.data,
    required this.builder,
    super.key,
  });

  /// Where references are resolved.
  final DataContext dataContext;

  /// The component's raw props.
  final Map<String, Object?> data;

  /// Builds the component from the props with references resolved.
  final Widget Function(BuildContext context, Map<String, Object?> props)
  builder;

  @override
  State<BoundProps> createState() => _BoundPropsState();
}

/// Subscribes to each bound prop and rebuilds when one changes.
class _BoundPropsState extends State<BoundProps> {
  final Map<String, ValueNotifier<Object?>> _notifiers = {};

  @override
  void initState() {
    super.initState();
    _subscribe();
  }

  @override
  void didUpdateWidget(BoundProps oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.data != widget.data ||
        oldWidget.dataContext != widget.dataContext) {
      _unsubscribe();
      _subscribe();
    }
  }

  @override
  void dispose() {
    _unsubscribe();
    super.dispose();
  }

  void _subscribe() {
    _collect(widget.data);
  }

  void _collect(Object? value) {
    final path = boundPath(value);
    if (path != null) {
      _notifiers.putIfAbsent(path, () {
        return widget.dataContext.subscribe<Object?>(DataPath(path))
          ..addListener(_changed);
      });
    } else if (value is Map) {
      for (final entry in value.entries) {
        if (entry.key != 'action') _collect(entry.value);
      }
    } else if (value is List) {
      value.forEach(_collect);
    }
  }

  void _unsubscribe() {
    for (final notifier in _notifiers.values) {
      notifier
        ..removeListener(_changed)
        ..dispose();
    }
    _notifiers.clear();
  }

  void _changed() {
    if (mounted) setState(() {});
  }

  Object? _resolve(Object? value) {
    final path = boundPath(value);
    if (path != null) return _notifiers[path]?.value;
    if (value is Map) {
      return <String, Object?>{
        for (final entry in value.entries)
          '${entry.key}': entry.key == 'action'
              ? entry.value
              : _resolve(entry.value),
      };
    }
    if (value is List) return value.map(_resolve).toList();
    return value;
  }

  @override
  Widget build(BuildContext context) {
    return widget.builder(
      context,
      _resolve(widget.data)! as Map<String, Object?>,
    );
  }
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
