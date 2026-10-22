import 'package:flutter/widgets.dart';

/// {@template now_scope}
/// Where widgets that count down read "now" from.
///
/// The app provides its scenario clock here, so a demo can set 4:30 PM and move
/// forward. Without a scope, widgets fall back to the device clock.
/// {@endtemplate}
class NowScope extends InheritedWidget {
  /// {@macro now_scope}
  const NowScope({required this.now, required super.child, super.key});

  /// The current time.
  final DateTime Function() now;

  /// The nearest scope's clock, or null when there is none.
  static DateTime Function()? maybeOf(BuildContext context) {
    return context.dependOnInheritedWidgetOfExactType<NowScope>()?.now;
  }

  @override
  bool updateShouldNotify(NowScope oldWidget) => now != oldWidget.now;
}
