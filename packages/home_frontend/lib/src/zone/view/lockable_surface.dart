import 'package:flutter/material.dart';

/// {@template lockable_surface}
/// Wraps a `Surface` so the zone can freeze it once it is no longer the
/// latest agent turn. Locked surfaces stay visible with their selected
/// values intact, but they no longer respond to input.
/// {@endtemplate}
class LockableSurface extends StatelessWidget {
  /// {@macro lockable_surface}
  const LockableSurface({
    required this.locked,
    required this.child,
    this.lockedOpacity = 0.6,
    super.key,
  });

  /// Whether the surface is locked. When true, pointer events are dropped,
  /// the surface is muted via opacity, and screen readers announce a
  /// disabled state.
  final bool locked;

  /// The `Surface` widget to render.
  final Widget child;

  /// Opacity applied to [child] when [locked] is true. Defaults to `0.6`.
  final double lockedOpacity;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      enabled: !locked,
      child: IgnorePointer(
        ignoring: locked,
        child: Opacity(opacity: locked ? lockedOpacity : 1.0, child: child),
      ),
    );
  }
}
