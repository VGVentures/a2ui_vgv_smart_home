import 'dart:async';
import 'dart:ui';

import 'package:a2ui_vgv_smart_home/l10n/l10n.dart';
import 'package:a2ui_vgv_smart_home/timeline/cubit/timeline_cubit.dart';
import 'package:a2ui_vgv_smart_home/timeline/day_phase.dart';
import 'package:app_ui/app_ui.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

/// {@template timeline_bar}
/// The control that moves the demo's time, below the tablet.
///
/// A frosted pill at the bottom of the screen with a button for each
/// [DayPhase]: morning, day, sunset and evening. The one the time is in is
/// filled, and choosing another takes the time there, easing instead of
/// jumping, see [TimelineCubit]. Needs a [TimelineCubit] above it.
/// {@endtemplate}
class TimelineBar extends StatelessWidget {
  /// {@macro timeline_bar}
  const TimelineBar({super.key});

  static const double _radius = 44;

  @override
  Widget build(BuildContext context) {
    final state = context.watch<TimelineCubit>().state;
    final l10n = context.l10n;
    final cubit = context.read<TimelineCubit>();
    final failed = state.status == TimelineStatus.failure;
    final canMove = state.status == TimelineStatus.ready && !state.moving;
    final selected = failed ? null : DayPhase.at(state.now);
    final labels = {
      DayPhase.morning: l10n.timelineMorning,
      DayPhase.day: l10n.timelineDay,
      DayPhase.sunset: l10n.timelineSunset,
      DayPhase.evening: l10n.timelineEvening,
    };
    // A clock that cannot be reached is asked again by any button.
    VoidCallback? press(DayPhase phase) {
      if (failed) return () => unawaited(cubit.reset());
      if (!canMove) return null;
      return () => unawaited(cubit.seekTo(phase.on(state.start)));
    }

    // The bar sits above the navigator, so it brings its own Material.
    return Material(
      type: MaterialType.transparency,
      child: Semantics(
        container: true,
        explicitChildNodes: true,
        label: l10n.timelineLabel,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(
            AppSpacing.s4,
            AppSpacing.s1,
            AppSpacing.s4,
            AppSpacing.s2,
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            spacing: AppSpacing.s1,
            children: [
              if (failed)
                Text(
                  l10n.timelineFailed,
                  style: AppTypography.labelStrong.copyWith(
                    color: AppColors.danger,
                  ),
                ),
              DecoratedBox(
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(_radius),
                  boxShadow: const [
                    BoxShadow(
                      color: Color(0x2E030F30),
                      blurRadius: 48,
                      offset: Offset(0, 16),
                    ),
                  ],
                ),
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(_radius),
                  child: BackdropFilter(
                    filter: ImageFilter.blur(sigmaX: 14, sigmaY: 14),
                    child: DecoratedBox(
                      decoration: BoxDecoration(
                        color: AppColors.surfaceRaised.withValues(alpha: 0.74),
                        borderRadius: BorderRadius.circular(_radius),
                        border: Border.all(
                          color: AppColors.surfaceRaised.withValues(alpha: 0.8),
                        ),
                      ),
                      child: Padding(
                        padding: const EdgeInsets.all(10),
                        // Shrinks to fit a window too narrow for the buttons.
                        child: FittedBox(
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            spacing: 4,
                            children: [
                              for (final phase in DayPhase.values)
                                _PhaseButton(
                                  phase: phase,
                                  label: labels[phase]!,
                                  selected: phase == selected,
                                  onPressed: press(phase),
                                ),
                            ],
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// One day phase button of the timeline bar.
class _PhaseButton extends StatelessWidget {
  const _PhaseButton({
    required this.phase,
    required this.label,
    required this.selected,
    required this.onPressed,
  });

  final DayPhase phase;
  final String label;
  final bool selected;
  final VoidCallback? onPressed;

  @override
  Widget build(BuildContext context) {
    return TextButton.icon(
      onPressed: onPressed,
      icon: Icon(phase.icon, size: 22),
      label: Text(label),
      style: TextButton.styleFrom(
        foregroundColor: selected ? AppColors.onAccent : AppColors.ink,
        backgroundColor: selected ? AppColors.ink : Colors.transparent,
        disabledForegroundColor: selected
            ? AppColors.onAccent
            : AppColors.fillStrong,
        disabledBackgroundColor: selected ? AppColors.ink : null,
        minimumSize: const Size(0, 56),
        padding: const EdgeInsets.symmetric(horizontal: 22),
        iconSize: 22,
        shape: const StadiumBorder(),
        textStyle: AppTypography.ui(
          size: 18,
          lineHeight: 24,
          weight: FontWeight.w500,
          letterSpacing: -0.18,
        ),
      ),
    );
  }
}
