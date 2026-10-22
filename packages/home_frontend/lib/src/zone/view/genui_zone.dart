import 'package:flutter/material.dart';
import 'package:home_frontend/src/zone/controller/genui_zone_controller.dart';
import 'package:home_frontend/src/zone/view/genui_zone_view.dart';

/// Wraps the widget rendered for each agent-produced item.
///
/// [surface] is the raw `Surface` widget. [isLatest] is `true` when this
/// surface belongs to the latest agent turn (no later user message exists).
/// Hosts may wrap [surface] in `LockableSurface(locked: !isLatest, ...)`,
/// swap to a frozen presentation, animate the transition, or render as-is.
typedef GenUISurfaceBuilder =
    Widget Function(
      BuildContext context,
      Widget surface,
      // Positional bool keeps the signature flat and familiar alongside
      // Flutter's WidgetBuilder.
      // ignore: avoid_positional_boolean_parameters
      bool isLatest,
    );

/// Builds a widget for a user message rendered in the zone.
///
/// Hosts receive the raw [message] text and return whatever bubble shape they
/// want. The default builder renders a right-aligned themed bubble.
typedef GenUIUserMessageBuilder =
    Widget Function(BuildContext context, String message);

/// Builds a widget for a failed turn recorded in the zone.
///
/// Hosts receive the [error] itself, not a rendering of it, so a notice can
/// branch on the type — `AuthError` to ask for a new key, `HttpException` to
/// offer a retry — rather than matching on message text. The default builder
/// renders an error-themed bubble over `error.toString()`.
typedef GenUIErrorBuilder = Widget Function(BuildContext context, Object error);

/// Builds the affordance shown while a turn is in flight.
///
/// Rendered after the last item rather than in place of the list, so the
/// conversation stays on screen while the agent works. The default builder
/// renders a centered progress indicator.
typedef GenUILoadingBuilder = Widget Function(BuildContext context);

/// {@template genui_zone}
/// A GenUI zone is a widget that hands over its interface to an LLM.
///
/// Several GenUI zones can coexist as siblings in the same widget tree,
/// but they're all leaf nodes.
/// {@endtemplate}
class GenUIZone extends StatelessWidget {
  /// {@macro genui_zone}
  ///
  /// A GenUI zone laid out for a chat between the LLM and the user.
  ///
  /// The host owns [controller] — construct it, call `start()`, and dispose
  /// it when the page goes away.
  ///
  /// [surfaceBuilder] wraps the `Surface` widget rendered for each
  /// agent-produced item. Defaults to `LockableSurface(locked: !isLatest, …)`,
  /// which freezes stale surfaces once a later user message arrives.
  ///
  /// [userMessageBuilder] builds the widget rendered for each user message.
  /// Defaults to a right-aligned themed bubble.
  ///
  /// [errorBuilder] builds the widget rendered for each failed turn. Defaults
  /// to an error-themed bubble.
  ///
  /// [loadingBuilder] builds the affordance shown after the last item while a
  /// turn is in flight. Defaults to a centered progress indicator.
  const GenUIZone.chat({
    required this.controller,
    this.surfaceBuilder,
    this.userMessageBuilder,
    this.errorBuilder,
    this.loadingBuilder,
    super.key,
  });

  /// The controller that drives the zone's conversation.
  final GenUIZoneController controller;

  /// Wraps each agent-produced surface. Null falls back to wrapping in
  /// `LockableSurface(locked: !isLatest, …)`.
  final GenUISurfaceBuilder? surfaceBuilder;

  /// Builds each user message bubble. Null falls back to a default themed
  /// bubble.
  final GenUIUserMessageBuilder? userMessageBuilder;

  /// Builds each failed-turn notice. Null falls back to an error-themed
  /// bubble.
  final GenUIErrorBuilder? errorBuilder;

  /// Builds the in-flight affordance. Null falls back to a centered progress
  /// indicator.
  final GenUILoadingBuilder? loadingBuilder;

  @override
  Widget build(BuildContext context) => GenUIZoneView(
    controller: controller,
    surfaceBuilder: surfaceBuilder,
    userMessageBuilder: userMessageBuilder,
    errorBuilder: errorBuilder,
    loadingBuilder: loadingBuilder,
  );
}
