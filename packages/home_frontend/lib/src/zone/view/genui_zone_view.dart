import 'package:flutter/material.dart';
import 'package:home_frontend/src/a2ui/a2ui.dart';
import 'package:home_frontend/src/widgets/widgets.dart';
import 'package:home_frontend/src/zone/controller/genui_zone_controller.dart';
import 'package:home_frontend/src/zone/controller/genui_zone_item.dart';
import 'package:home_frontend/src/zone/controller/genui_zone_state.dart';
import 'package:home_frontend/src/zone/view/genui_zone.dart';
import 'package:home_frontend/src/zone/view/lockable_surface.dart';

/// {@template gen_u_i__zone_view}
/// Renders the current state of a [GenUIZoneController].
/// {@endtemplate}
class GenUIZoneView extends StatelessWidget {
  /// {@macro gen_u_i__zone_view}
  const GenUIZoneView({
    required this.controller,
    this.surfaceBuilder,
    this.userMessageBuilder,
    this.errorBuilder,
    this.loadingBuilder,
    super.key,
  });

  /// The controller whose state drives this view.
  final GenUIZoneController controller;

  /// Wraps each agent-produced surface. Null wraps the surface in
  /// `LockableSurface(locked: !isLatest, …)`.
  final GenUISurfaceBuilder? surfaceBuilder;

  /// Builds each user message bubble. Null uses [DefaultUserMessageBubble].
  final GenUIUserMessageBuilder? userMessageBuilder;

  /// Builds each failed-turn notice. Null uses [DefaultErrorBubble].
  final GenUIErrorBuilder? errorBuilder;

  /// Builds the in-flight affordance. Null uses [DefaultLoadingIndicator].
  final GenUILoadingBuilder? loadingBuilder;

  @override
  Widget build(BuildContext context) {
    final surface = surfaceBuilder ?? _defaultSurfaceBuilder;
    final userMessage = userMessageBuilder ?? _defaultUserMessageBuilder;
    final error = errorBuilder ?? _defaultErrorBuilder;
    final loading = loadingBuilder ?? _defaultLoadingBuilder;
    return ListenableBuilder(
      listenable: controller,
      // `isSending` changes notify listeners too, so the in-flight affordance
      // is read here rather than outside the builder.
      builder: (context, _) => switch (controller.state) {
        GenUIZoneInitial() => const SizedBox.shrink(),
        GenUIZoneItemsUpdated(
          controller: final surfaceController,
          :final items,
        ) =>
          _ItemsList(
            controller: surfaceController,
            items: items,
            surface: surface,
            userMessage: userMessage,
            error: error,
            loading: loading,
            isSending: controller.isSending,
          ),
        // Only a start failure reaches this state; a turn that fails once the
        // conversation is under way arrives as an ErrorItem in the list.
        GenUIZoneError(error: final message) => Center(child: Text(message)),
      },
    );
  }
}

/// The list of zone items, each built with the host's builders.
class _ItemsList extends StatelessWidget {
  const _ItemsList({
    required this.controller,
    required this.items,
    required this.surface,
    required this.userMessage,
    required this.error,
    required this.loading,
    required this.isSending,
  });

  final SurfaceController controller;
  final List<GenUIZoneItem> items;
  final GenUISurfaceBuilder surface;
  final GenUIUserMessageBuilder userMessage;
  final GenUIErrorBuilder error;
  final GenUILoadingBuilder loading;
  final bool isSending;

  @override
  Widget build(BuildContext context) {
    final lastUserIndex = _lastUserMessageIndex(items);
    return ListView.builder(
      // The in-flight affordance trails the conversation as an extra row, so
      // the items stay on screen while the agent works.
      itemCount: items.length + (isSending ? 1 : 0),
      itemBuilder: (context, index) {
        if (index == items.length) return loading(context);
        return switch (items[index]) {
          SurfaceItem(:final surfaceId) => surface(
            context,
            Surface(surfaceContext: controller.contextFor(surfaceId)),
            index >= lastUserIndex,
          ),
          UserMessageItem(:final text) => userMessage(context, text),
          ErrorItem(error: final failure) => error(context, failure),
        };
      },
    );
  }

  /// Index of the message that started the newest turn, or -1 if there is
  /// none.
  ///
  /// A failed message is skipped: the turn it started produced nothing, so
  /// letting it count would lock the surfaces before it for a reply that never
  /// arrived.
  static int _lastUserMessageIndex(List<GenUIZoneItem> items) {
    for (var i = items.length - 1; i >= 0; i--) {
      final item = items[i];
      if (item is UserMessageItem && !item.failed) return i;
    }
    return -1;
  }
}

Widget _defaultSurfaceBuilder(
  BuildContext context,
  Widget surface,
  bool isLatest,
) => LockableSurface(locked: !isLatest, child: surface);

Widget _defaultUserMessageBuilder(BuildContext context, String message) =>
    DefaultUserMessageBubble(message: message);

Widget _defaultErrorBuilder(BuildContext context, Object error) =>
    DefaultErrorBubble(message: error.toString());

Widget _defaultLoadingBuilder(BuildContext context) =>
    const DefaultLoadingIndicator();
