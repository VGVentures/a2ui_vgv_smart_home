import 'package:a2ui_vgv_smart_home/l10n/l10n.dart';
import 'package:app_ui/app_ui.dart';
import 'package:flutter/material.dart';
import 'package:home_frontend/home_frontend.dart';

/// {@template dashboard_surface}
/// The part of the screen the model draws: always the latest surface.
///
/// The surface is given exactly this box and never scrolls. The catalog's
/// `Row` and `Column` split it in a fixed grid, so what does not fit is
/// dropped there instead of running off the screen.
///
/// It is never a chat.
/// {@endtemplate}
///
/// {@template dashboard_in_place_update}
/// A new answer updates the surface in place, so nothing swaps. Until the first
/// one arrives a skeleton stands in. A turn in flight leaves the surface before
/// it on screen. A turn that fails does too, and only a failure with nothing to
/// show yet is reported.
/// {@endtemplate}
class DashboardSurface extends StatelessWidget {
  /// {@macro dashboard_surface}
  const DashboardSurface({required this.controller, super.key});

  /// The zone whose latest surface is drawn.
  final GenUIZoneController controller;

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: controller,
      builder: (context, _) => OptimisticScope(
        revision: controller.failedTurns,
        child: AnimatedSwitcher(
          duration: const Duration(milliseconds: 300),
          child: _content(context),
        ),
      ),
    );
  }

  Widget _content(BuildContext context) {
    const skeleton = SkeletonSurface(key: ValueKey('skeleton'));
    final state = controller.state;
    if (state is! GenUIZoneItemsUpdated) return skeleton;
    final surface = state.items.whereType<SurfaceItem>().lastOrNull;
    if (surface != null) {
      return SizedBox.expand(
        key: ValueKey(surface.surfaceId),
        child: Surface(
          surfaceContext: state.controller.contextFor(surface.surfaceId),
        ),
      );
    }
    return state.items.whereType<ErrorItem>().isEmpty
        ? skeleton
        : const _Failure();
  }
}

/// Reported when the first dashboard fails with nothing to show yet.
class _Failure extends StatelessWidget {
  const _Failure();

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Text(context.l10n.dashboardFailed, style: AppTypography.body),
    );
  }
}
