import 'package:a2ui_vgv_smart_home/action_toast/cubit/action_toast_cubit.dart';
import 'package:app_ui/app_ui.dart';
import 'package:flutter/material.dart';

/// {@template action_glow}
/// The light that follows a request across the panel, behind the toast.
///
/// While the request is on its way it is a small, faint yellow glow rising from
/// the toast. On success it turns green and grows to wash over the panel, and
/// when the toast leaves it fades away in the color it had. A failure does the
/// same in coral. It never takes a tap.
/// {@endtemplate}
class ActionGlow extends StatefulWidget {
  /// {@macro action_glow}
  const ActionGlow({required this.status, super.key});

  /// Where the request the glow follows stands.
  final ActionToastStatus status;

  @override
  State<ActionGlow> createState() => _ActionGlowState();
}

/// Keeps the glow's color while it fades out.
class _ActionGlowState extends State<ActionGlow> {
  /// What the glow looks like while it is showing. Kept when the toast goes
  /// idle so the glow fades out in the color it had instead of changing.
  late _Glow _glow = _glowOf(widget.status) ?? _loading;

  static const _loading = _Glow(AppColors.warning, alpha: 0.22, radius: 0.55);
  static const _success = _Glow(
    AppColors.successLight,
    alpha: 0.4,
    radius: 1.5,
  );
  static const _error = _Glow(AppColors.danger, alpha: 0.35, radius: 1.3);

  static _Glow? _glowOf(ActionToastStatus status) => switch (status) {
    ActionToastStatus.loading => _loading,
    ActionToastStatus.success => _success,
    ActionToastStatus.error => _error,
    ActionToastStatus.idle => null,
  };

  @override
  void didUpdateWidget(ActionGlow oldWidget) {
    super.didUpdateWidget(oldWidget);
    _glow = _glowOf(widget.status) ?? _glow;
  }

  @override
  Widget build(BuildContext context) {
    final visible = widget.status != ActionToastStatus.idle;
    final reduceMotion = MediaQuery.disableAnimationsOf(context);
    final alpha = visible ? _glow.alpha : 0.0;
    return IgnorePointer(
      child: AnimatedContainer(
        duration: reduceMotion
            ? Duration.zero
            : Duration(milliseconds: visible ? 600 : 500),
        curve: Curves.easeInOut,
        decoration: BoxDecoration(
          gradient: RadialGradient(
            center: Alignment.bottomCenter,
            radius: _glow.radius,
            colors: [
              _glow.color.withValues(alpha: alpha),
              _glow.color.withValues(alpha: 0),
            ],
          ),
        ),
      ),
    );
  }
}

/// How the glow looks: its color, opacity and radius.
class _Glow {
  const _Glow(this.color, {required this.alpha, required this.radius});

  final Color color;
  final double alpha;

  /// Relative to the shorter side of the panel.
  final double radius;
}
